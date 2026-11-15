module Main where

import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

data Fixture = Fixture { fixtureTarget :: String }

generateFixture :: Fixture -> [Message] -> IO (Either AgentError Response)
generateFixture fixture messages =
    pure $ case reverse messages of
        [] -> Left (AgentError "MODEL_ERROR" "no messages")
        lastMessage : _
            | messageRole lastMessage == "tool" ->
                Right (Response "recorded" [] 0 0)
            | otherwise ->
                Right (Response
                    ""
                    [ToolCall "record-1" "record"
                        (JObject [("target", JString (fixtureTarget fixture))])]
                    0
                    0)

recordTool :: IORef Int -> ToolCall -> IO (Either AgentError Json)
recordTool effects call
    | toolCallName call /= "record" =
        pure (Left (AgentError "TOOL_NOT_FOUND" ("tool " ++ toolCallName call ++ " is not available")))
    | asString (field "target" (toolCallArguments call)) /= "public" =
        pure (Left (AgentError "AGENT_POLICY_DENIED" "only the public target is permitted"))
    | otherwise = do
        modifyIORef' effects (+ 1)
        pure (Right (JString "recorded"))

allowKinds :: String -> Bool
allowKinds kind = kind == "model.generate" || kind == "tool.invoke"

runCase :: String -> IO (Either AgentError RunResult, Int)
runCase target = do
    effects <- newIORef 0
    let options = AgentOptions
            { generate = generateFixture (Fixture target)
            , invoke = recordTool effects
            , emit = \_ -> pure (Right ())
            , maxSteps = 3
            , maxTokens = 0
            , policy = Just allowKinds
            , allowedTools = ["record"]
            , requirePolicy = True
            , requireToolScope = True
            }
    result <- runAgent options [] "Record the requested target."
    count <- readIORef effects
    pure (result, count)

main :: IO ()
main = do
    (allowed, allowedEffects) <- runCase "public"
    case allowed of
        Right value
            | runOutput value == "recorded" && allowedEffects == 1 ->
                putStrLn "allow: recorded; effects=1"
            | otherwise -> do
                hPutStrLn stderr ("allow verification failed: output=" ++ runOutput value
                    ++ " effects=" ++ show allowedEffects)
                exitFailure
        Left errorValue -> do
            hPutStrLn stderr ("allow verification failed: " ++ errorMessage errorValue)
            exitFailure

    (denied, deniedEffects) <- runCase "private"
    case denied of
        Left errorValue
            | errorCode errorValue == "AGENT_POLICY_DENIED" && deniedEffects == 0 ->
                putStrLn "deny: policy rejected; effects=0"
            | otherwise -> do
                hPutStrLn stderr ("deny verification failed: code=" ++ errorCode errorValue
                    ++ " effects=" ++ show deniedEffects)
                exitFailure
        Right value -> do
            hPutStrLn stderr ("deny verification failed: output=" ++ runOutput value
                ++ " effects=" ++ show deniedEffects)
            exitFailure
