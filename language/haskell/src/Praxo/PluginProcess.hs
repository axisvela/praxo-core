{-# LANGUAGE ScopedTypeVariables #-}
module Praxo.PluginProcess
    ( PluginProcessConfig(..)
    , PluginProcessError(..)
    , PluginProcessHost
    , startPluginProcess
    , invokePluginProcess
    , stopPluginProcess
    ) where

import Control.Exception (SomeException, try)
import Data.Char (chr, digitToInt, intToDigit, isSpace)
import Data.IORef
import Data.List (dropWhileEnd)
import System.Environment (getEnvironment)
import System.IO
import System.Process
import System.Timeout (timeout)

import Praxo.Agent (AgentError(..))
import Praxo.Json (Json(..), asString, encodeJson, field, parseJson)

data PluginProcessConfig = PluginProcessConfig
    { pluginId :: String
    , pluginPath :: String
    , pluginArgs :: [String]
    , pluginDir :: Maybe FilePath
    , pluginEnv :: Maybe [(String, String)]
    , pluginToken :: String
    , pluginTokenEnvVar :: String
    , pluginStartTimeout :: Int
    , pluginInvokeTimeout :: Int
    , pluginGracePeriod :: Int
    } deriving (Eq, Show)

data PluginProcessError = PluginProcessError
    { processCode :: String
    , processMessage :: String
    } deriving (Eq, Show)

data PluginProcessHost = PluginProcessHost
    { hostId :: String
    , hostToken :: String
    , hostInput :: Handle
    , hostOutput :: Handle
    , hostProcess :: ProcessHandle
    , hostSeq :: IORef Int
    , hostActive :: IORef Bool
    }

startPluginProcess :: PluginProcessConfig -> IO (Either PluginProcessError PluginProcessHost)
startPluginProcess config
    | null (pluginId config) = pure (Left (err "INVALID_REQUEST" "plugin: PluginID is required"))
    | null (pluginPath config) = pure (Left (err "INVALID_REQUEST" "plugin: path is required"))
    | otherwise = do
        env0 <- maybe getEnvironment pure (pluginEnv config)
        let tokenEnv = if null (pluginTokenEnvVar config) then "PRAXOVELA_PLUGIN_TOKEN" else pluginTokenEnvVar config
            token = if null (pluginToken config) then "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" else pluginToken config
            env = (tokenEnv, token) : filter ((/= tokenEnv) . fst) env0
        result <- try $ createProcess (proc (pluginPath config) (pluginArgs config))
            { cwd = pluginDir config
            , env = Just env
            , std_in = CreatePipe
            , std_out = CreatePipe
            , std_err = CreatePipe
            }
        case result of
            Left (_ :: SomeException) -> pure (Left (err "INTERNAL" "plugin: spawn failed"))
            Right (Just input, Just output, _stderr, process) -> do
                seqRef <- newIORef 0
                activeRef <- newIORef False
                let host = PluginProcessHost (pluginId config) token input output process seqRef activeRef
                health <- callHost config host "host.control" "health" "" (pluginStartTimeout config)
                case health of
                    Left errorValue -> do
                        terminateProcess process
                        pure (Left errorValue)
                    Right _ -> do
                        writeIORef activeRef True
                        pure (Right host)
            Right _ -> pure (Left (err "INTERNAL" "plugin: pipe setup failed"))

invokePluginProcess :: PluginProcessConfig -> PluginProcessHost -> String -> String -> String -> IO (Either PluginProcessError String)
invokePluginProcess config host service method payload = do
    active <- readIORef (hostActive host)
    if not active
        then pure (Left (err "NOT_ACTIVE" "plugin: host is not active"))
        else callHost config host service method payload (pluginInvokeTimeout config)

stopPluginProcess :: PluginProcessConfig -> PluginProcessHost -> IO ()
stopPluginProcess config host = do
    _ <- callHost config host "host.control" "shutdown" "" (pluginGracePeriod config)
    writeIORef (hostActive host) False
    _ <- try (terminateProcess (hostProcess host)) :: IO (Either SomeException ())
    pure ()

callHost :: PluginProcessConfig -> PluginProcessHost -> String -> String -> String -> Int -> IO (Either PluginProcessError String)
callHost config host service method payload timeoutMs = do
    seqValue <- atomicModifyIORef' (hostSeq host) (\value -> (value + 1, value + 1))
    let requestId = "req-" ++ show seqValue
        frame = JObject
            [ ("id", JString requestId)
            , ("version", JNumber 1)
            , ("plugin_id", JString (hostId host))
            , ("service", JString service)
            , ("method", JString method)
            , ("token", JString (hostToken host))
            , ("payload", JString (base64Encode payload))
            ]
    case encodeJson frame of
        Left detail -> pure (Left (err "INVALID_REQUEST" detail))
        Right encoded -> do
            writeResult <- try $ do
                hPutStrLn (hostInput host) encoded
                hFlush (hostInput host)
            case writeResult of
                Left (_ :: SomeException) -> pure (Left (err "INTERNAL" "plugin: request write failed"))
                Right () -> readResponse (hostOutput host) requestId timeoutMs

readResponse :: Handle -> String -> Int -> IO (Either PluginProcessError String)
readResponse output requestId timeoutMs = do
    line <- timeout timeoutMs (hGetLine output)
    case line of
        Nothing -> pure (Left (err "TIMEOUT" "plugin: invocation timed out"))
        Just raw -> case parseJson raw of
            Left detail -> pure (Left (err "INTERNAL" ("plugin: invalid response: " ++ detail)))
            Right value
                | asString (field "id" value) /= requestId -> readResponse output requestId timeoutMs
                | field "ok" value /= JBool True ->
                    pure (Left (PluginProcessError
                        (normalizeCode (asString (field "code" value)))
                        (asString (field "message" value))))
                | otherwise -> pure $ case base64Decode (asString (field "payload" value)) of
                    Nothing -> Left (err "INTERNAL" "plugin: invalid payload")
                    Just decoded -> Right decoded

normalizeCode :: String -> String
normalizeCode code
    | code `elem` known = code
    | otherwise = "INTERNAL"
  where
    known = ["CAPABILITY_DENIED", "NOT_ACTIVE", "NOT_FOUND", "INVALID_REQUEST", "TIMEOUT", "INTERNAL", "CANCELED"]

err :: String -> String -> PluginProcessError
err code message = PluginProcessError code message

base64Encode :: String -> String
base64Encode = concatMap encodeChunk . chunksOf3
  where
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    encodeChunk [a] =
        [ alphabet !! (fromEnum a `div` 4)
        , alphabet !! ((fromEnum a `mod` 4) * 16)
        , '=', '=']
    encodeChunk [a, b] =
        [ alphabet !! (fromEnum a `div` 4)
        , alphabet !! (((fromEnum a `mod` 4) * 16) + (fromEnum b `div` 16))
        , alphabet !! ((fromEnum b `mod` 16) * 4)
        , '=']
    encodeChunk (a:b:c:_) =
        [ alphabet !! (fromEnum a `div` 4)
        , alphabet !! (((fromEnum a `mod` 4) * 16) + (fromEnum b `div` 16))
        , alphabet !! (((fromEnum b `mod` 16) * 4) + (fromEnum c `div` 64))
        , alphabet !! (fromEnum c `mod` 64)]
    encodeChunk [] = []
    chunksOf3 [] = []
    chunksOf3 value = take 3 value : chunksOf3 (drop 3 value)

base64Decode :: String -> Maybe String
base64Decode text
    | any (not . valid) filtered = Nothing
    | otherwise = Just (go filtered)
  where
    filtered = takeWhile (/= '=') (filter (not . isSpace) text)
    valid c = c `elem` alphabet
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    value c = case lookup c (zip alphabet [0 ..]) of
        Just index -> index
        Nothing -> 0
    go = goBits 0 0 []
    goBits _ _ acc [] = reverse acc
    goBits buffer bits acc (c:rest) =
        let next = buffer * 64 + value c
            bits2 = bits + 6
        in if bits2 >= 8
            then let output = (next `div` (2 ^ (bits2 - 8))) `mod` 256
                 in goBits next (bits2 - 8) (chr output : acc) rest
            else goBits next bits2 acc rest
