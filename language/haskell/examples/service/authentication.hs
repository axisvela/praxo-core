module Authentication
    ( Principal(..)
    , AuthError(..)
    , Transport
    , IntrospectionAuthenticator(..)
    , RevocationClient(..)
    , introspectionAuthenticator
    , revocationClient
    , authenticate
    , revoke
    ) where

import Data.Char (isSpace, ord)
import Data.List (isPrefixOf)
import Data.Ratio (denominator, numerator)
import Praxo.Json (Json(..), field, parseJson)

data Principal = Principal
    { principalSubject :: String
    , principalTenant :: String
    , principalExpires :: Int
    } deriving (Eq, Show)

newtype AuthError = AuthError String deriving (Eq, Show)

type Transport = String -> [(String, String)] -> Maybe String -> IO (Either AuthError (Int, String))

data IntrospectionAuthenticator = IntrospectionAuthenticator
    { authenticatorTransport :: Transport
    , authenticatorEndpoint :: String
    , authenticatorClientId :: String
    , authenticatorClientSecret :: String
    , authenticatorTenantClaim :: String
    }

data RevocationClient = RevocationClient
    { revocationTransport :: Transport
    , revocationEndpoint :: String
    , revocationClientId :: String
    , revocationClientSecret :: String
    }

introspectionAuthenticator :: Transport -> String -> String -> String -> String -> IntrospectionAuthenticator
introspectionAuthenticator transport endpoint clientId clientSecret tenantClaim =
    IntrospectionAuthenticator transport endpoint clientId clientSecret claim
  where
    claim = if null tenantClaim then "tenant" else tenantClaim

revocationClient :: Transport -> String -> String -> String -> RevocationClient
revocationClient transport endpoint clientId clientSecret =
    RevocationClient transport endpoint clientId clientSecret

authenticate :: IntrospectionAuthenticator -> Maybe String -> Int -> IO (Maybe Principal)
authenticate authenticator authorization now =
    case authorization of
        Nothing -> pure Nothing
        Just value
            | not ("Bearer " `isPrefixOf` value) -> pure Nothing
            | null token -> pure Nothing
            | otherwise -> do
                response <- authenticatorTransport authenticator
                    (authenticatorEndpoint authenticator)
                    [ ("token", token)
                    , ("client_id", authenticatorClientId authenticator)
                    , ("client_secret", authenticatorClientSecret authenticator)
                    ]
                    (basicAuth (authenticatorClientId authenticator) (authenticatorClientSecret authenticator))
                pure (either (const Nothing) (parseResponse authenticator now) response)
          where
            token = trim (drop (length "Bearer ") value)

revoke :: RevocationClient -> String -> IO (Either AuthError ())
revoke client token
    | null token = pure (Left (AuthError "revocation token is required"))
    | otherwise = do
        response <- revocationTransport client
            (revocationEndpoint client)
            [ ("token", token)
            , ("token_type_hint", "access_token")
            , ("client_id", revocationClientId client)
            , ("client_secret", revocationClientSecret client)
            ]
            (basicAuth (revocationClientId client) (revocationClientSecret client))
        pure $ case response of
            Right (200, _) -> Right ()
            _ -> Left (AuthError "token revocation failed")

parseResponse :: IntrospectionAuthenticator -> Int -> (Int, String) -> Maybe Principal
parseResponse authenticator now (status, body)
    | status /= 200 = Nothing
    | otherwise = case parseJson body of
        Right payload@(JObject _) -> do
            case field "active" payload of
                JBool True -> pure ()
                _ -> Nothing
            subject <- nonEmptyString (field "sub" payload)
            tenant <- nonEmptyString (field (authenticatorTenantClaim authenticator) payload)
            expires <- integerValue (field "exp" payload)
            if expires > now then Just (Principal subject tenant expires) else Nothing
        _ -> Nothing

nonEmptyString :: Json -> Maybe String
nonEmptyString (JString value)
    | not (null value) = Just value
nonEmptyString _ = Nothing

integerValue :: Json -> Maybe Int
integerValue (JNumber value)
    | denominator value == 1
        && numerator value >= toInteger (minBound :: Int)
        && numerator value <= toInteger (maxBound :: Int) =
            Just (fromInteger (numerator value))
integerValue _ = Nothing

basicAuth :: String -> String -> Maybe String
basicAuth clientId secret
    | null clientId = Nothing
    | otherwise = Just ("Basic " ++ base64Encode (clientId ++ ":" ++ secret))

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

base64Encode :: String -> String
base64Encode text = go (utf8Bytes text)
  where
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    go (a:b:c:rest) =
        [ alphabet !! (n `div` 262144)
        , alphabet !! ((n `div` 4096) `mod` 64)
        , alphabet !! ((n `div` 64) `mod` 64)
        , alphabet !! (n `mod` 64)
        ] ++ go rest
      where
        n = a * 65536 + b * 256 + c
    go [a, b] =
        [ alphabet !! (n `div` 262144)
        , alphabet !! ((n `div` 4096) `mod` 64)
        , alphabet !! ((n `div` 64) `mod` 64)
        , '='
        ]
      where
        n = a * 65536 + b * 256
    go [a] =
        [ alphabet !! (n `div` 262144)
        , alphabet !! ((n `div` 4096) `mod` 64)
        , '='
        , '='
        ]
      where
        n = a * 65536
    go [] = []

utf8Bytes :: String -> [Int]
utf8Bytes = concatMap encode
  where
    encode character
        | n <= 0x7F = [n]
        | n <= 0x7FF = [0xC0 + n `div` 64, 0x80 + n `mod` 64]
        | n <= 0xFFFF = [0xE0 + n `div` 4096, 0x80 + (n `div` 64) `mod` 64, 0x80 + n `mod` 64]
        | otherwise =
            [ 0xF0 + n `div` 262144
            , 0x80 + (n `div` 4096) `mod` 64
            , 0x80 + (n `div` 64) `mod` 64
            , 0x80 + n `mod` 64
            ]
      where
        n = ord character
