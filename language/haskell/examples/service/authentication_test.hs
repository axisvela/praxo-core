module Main where

import Data.IORef
import Authentication
import Praxo.Json (Json(..), encodeJson)

data Scripted = Scripted
    { scriptStatus :: Int
    , scriptBody :: String
    , scriptUnavailable :: Bool
    , scriptCalls :: IORef [([(String, String)], Maybe String)]
    }

newScripted :: Int -> String -> Bool -> IO Scripted
newScripted status body unavailable = do
    calls <- newIORef []
    pure (Scripted status body unavailable calls)

scriptedTransport :: Scripted -> Transport
scriptedTransport script _url form authorization = do
    modifyIORef' (scriptCalls script) ((form, authorization) :)
    if scriptUnavailable script
        then pure (Left (AuthError "identity provider unavailable"))
        else pure (Right (scriptStatus script, scriptBody script))

lastCall :: Scripted -> IO (Maybe ([(String, String)], Maybe String))
lastCall script = do
    calls <- readIORef (scriptCalls script)
    pure $ case calls of
        [] -> Nothing
        (call:_) -> Just call

bodyOf :: [(String, Json)] -> String
bodyOf fields = either error id (encodeJson (JObject fields))

expect :: Bool -> String -> IO ()
expect condition message =
    if condition then pure () else fail message

activeBody :: Int -> [(String, Json)]
activeBody now =
    [ ("active", JBool True)
    , ("sub", JString "user-1")
    , ("tenant", JString "local")
    , ("exp", JNumber (fromIntegral (now + 60)))
    ]

main :: IO ()
main = do
    let now = 1700000000

    active <- newScripted 200 (bodyOf (activeBody now)) False
    let authenticator = introspectionAuthenticator (scriptedTransport active) "https://id.example.com/introspect" "" "" ""
    principal <- authenticate authenticator (Just "Bearer opaque-token") now
    expect (principal == Just (Principal "user-1" "local" (now + 60))) "active token was rejected"
    call <- lastCall active
    expect (fmap fst call == Just [("token", "opaque-token"), ("client_id", ""), ("client_secret", "")]) "introspection form mismatch"
    expect (fmap snd call == Just Nothing) "empty client id must omit authorization"

    missing <- newScripted 200 (bodyOf (activeBody now)) False
    let missingAuth = introspectionAuthenticator (scriptedTransport missing) "https://id.example.com/introspect" "" "" ""
    missingResult <- authenticate missingAuth Nothing now
    expect (missingResult == Nothing) "missing authorization was accepted"
    missingCalls <- readIORef (scriptCalls missing)
    expect (null missingCalls) "missing authorization reached the transport"

    wrongScheme <- authenticate authenticator (Just "Basic opaque-token") now
    expect (wrongScheme == Nothing) "wrong scheme was accepted"

    lowercaseScheme <- authenticate authenticator (Just "bearer opaque-token") now
    expect (lowercaseScheme == Nothing) "lowercase scheme was accepted"

    emptyToken <- authenticate authenticator (Just "Bearer    ") now
    expect (emptyToken == Nothing) "empty token was accepted"

    inactive <- newScripted 200 (bodyOf [("active", JBool False)]) False
    let inactiveAuth = introspectionAuthenticator (scriptedTransport inactive) "https://id.example.com/introspect" "" "" ""
    inactiveResult <- authenticate inactiveAuth (Just "Bearer opaque-token") now
    expect (inactiveResult == Nothing) "inactive token was accepted"

    missingSubject <- newScripted 200 (bodyOf [("active", JBool True), ("tenant", JString "local"), ("exp", JNumber (fromIntegral (now + 60)))]) False
    let missingSubjectAuth = introspectionAuthenticator (scriptedTransport missingSubject) "https://id.example.com/introspect" "" "" ""
    missingSubjectResult <- authenticate missingSubjectAuth (Just "Bearer opaque-token") now
    expect (missingSubjectResult == Nothing) "missing subject was accepted"

    emptySubject <- newScripted 200 (bodyOf [("active", JBool True), ("sub", JString ""), ("tenant", JString "local"), ("exp", JNumber (fromIntegral (now + 60)))]) False
    let emptySubjectAuth = introspectionAuthenticator (scriptedTransport emptySubject) "https://id.example.com/introspect" "" "" ""
    emptySubjectResult <- authenticate emptySubjectAuth (Just "Bearer opaque-token") now
    expect (emptySubjectResult == Nothing) "empty subject was accepted"

    missingTenant <- newScripted 200 (bodyOf [("active", JBool True), ("sub", JString "user-1"), ("exp", JNumber (fromIntegral (now + 60)))]) False
    let missingTenantAuth = introspectionAuthenticator (scriptedTransport missingTenant) "https://id.example.com/introspect" "" "" ""
    missingTenantResult <- authenticate missingTenantAuth (Just "Bearer opaque-token") now
    expect (missingTenantResult == Nothing) "missing tenant was accepted"

    emptyTenant <- newScripted 200 (bodyOf [("active", JBool True), ("sub", JString "user-1"), ("tenant", JString ""), ("exp", JNumber (fromIntegral (now + 60)))]) False
    let emptyTenantAuth = introspectionAuthenticator (scriptedTransport emptyTenant) "https://id.example.com/introspect" "" "" ""
    emptyTenantResult <- authenticate emptyTenantAuth (Just "Bearer opaque-token") now
    expect (emptyTenantResult == Nothing) "empty tenant was accepted"

    expired <- newScripted 200 (bodyOf [("active", JBool True), ("sub", JString "user-1"), ("tenant", JString "local"), ("exp", JNumber (fromIntegral now))]) False
    let expiredAuth = introspectionAuthenticator (scriptedTransport expired) "https://id.example.com/introspect" "" "" ""
    expiredResult <- authenticate expiredAuth (Just "Bearer opaque-token") now
    expect (expiredResult == Nothing) "expired token was accepted"

    malformed <- newScripted 200 "{not-json" False
    let malformedAuth = introspectionAuthenticator (scriptedTransport malformed) "https://id.example.com/introspect" "" "" ""
    malformedResult <- authenticate malformedAuth (Just "Bearer opaque-token") now
    expect (malformedResult == Nothing) "malformed JSON was accepted"

    non200 <- newScripted 503 "{}" False
    let non200Auth = introspectionAuthenticator (scriptedTransport non200) "https://id.example.com/introspect" "" "" ""
    non200Result <- authenticate non200Auth (Just "Bearer opaque-token") now
    expect (non200Result == Nothing) "non-200 response was accepted"

    unavailable <- newScripted 200 "{}" True
    let unavailableAuth = introspectionAuthenticator (scriptedTransport unavailable) "https://id.example.com/introspect" "" "" ""
    unavailableResult <- authenticate unavailableAuth (Just "Bearer opaque-token") now
    expect (unavailableResult == Nothing) "transport error was accepted"

    custom <- newScripted 200 (bodyOf [("active", JBool True), ("sub", JString "user-1"), ("org", JString "acme"), ("exp", JNumber (fromIntegral (now + 60)))]) False
    let customAuth = introspectionAuthenticator (scriptedTransport custom) "https://id.example.com/introspect" "" "" "org"
    customResult <- authenticate customAuth (Just "Bearer opaque-token") now
    expect (customResult == Just (Principal "user-1" "acme" (now + 60))) "custom tenant claim failed"

    defaultOnly <- newScripted 200 (bodyOf (activeBody now)) False
    let defaultOnlyAuth = introspectionAuthenticator (scriptedTransport defaultOnly) "https://id.example.com/introspect" "" "" "org"
    defaultOnlyResult <- authenticate defaultOnlyAuth (Just "Bearer opaque-token") now
    expect (defaultOnlyResult == Nothing) "custom tenant claim fallback was accepted"

    confidential <- newScripted 200 (bodyOf (activeBody now)) False
    let confidentialAuth = introspectionAuthenticator (scriptedTransport confidential) "https://id.example.com/introspect" "client" "secret" ""
    _ <- authenticate confidentialAuth (Just "Bearer opaque-token") now
    confidentialCall <- lastCall confidential
    expect (fmap snd confidentialCall == Just (Just "Basic Y2xpZW50OnNlY3JldA==")) "confidential client did not send basic auth"

    revocationTransport <- newScripted 200 "{}" False
    let revocation = revocationClient (scriptedTransport revocationTransport) "https://id.example.com/revoke" "client" "secret"
    revoked <- revoke revocation "opaque-token"
    expect (revoked == Right ()) "revocation failed"
    revocationCall <- lastCall revocationTransport
    expect (fmap (lookup "token" . fst) revocationCall == Just (Just "opaque-token")) "revocation did not post the token"
    expect (fmap (lookup "token_type_hint" . fst) revocationCall == Just (Just "access_token")) "revocation did not send the access token hint"

    failedRevocationTransport <- newScripted 503 "{}" False
    let failedRevocation = revocationClient (scriptedTransport failedRevocationTransport) "https://id.example.com/revoke" "" ""
    failed <- revoke failedRevocation "opaque-token"
    expect (failed == Left (AuthError "token revocation failed")) "revocation failure was accepted"

    unavailableRevocationTransport <- newScripted 200 "{}" True
    let unavailableRevocation = revocationClient (scriptedTransport unavailableRevocationTransport) "https://id.example.com/revoke" "" ""
    unavailableRevoked <- revoke unavailableRevocation "opaque-token"
    expect (unavailableRevoked == Left (AuthError "token revocation failed")) "revocation transport error was accepted"

    emptyRevocationTransport <- newScripted 200 "{}" False
    let emptyRevocation = revocationClient (scriptedTransport emptyRevocationTransport) "https://id.example.com/revoke" "" ""
    emptyRevoked <- revoke emptyRevocation ""
    expect (emptyRevoked == Left (AuthError "revocation token is required")) "empty revocation token was accepted"
    emptyCalls <- readIORef (scriptCalls emptyRevocationTransport)
    expect (null emptyCalls) "empty revocation token reached the transport"

    putStrLn "Haskell service auth tests passed"
