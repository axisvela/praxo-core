module Praxo.Agent (AgentError(..), ToolCall(..), Message(..), Response(..), AgentOptions(..), RunResult(..), runAgent) where

import Praxo.Json (Json, encodeJson)

data AgentError = AgentError { errorCode :: String, errorMessage :: String } deriving (Eq, Show)
data ToolCall = ToolCall { toolCallId :: String, toolCallName :: String, toolCallArguments :: Json } deriving (Eq, Show)
data Message = Message { messageRole :: String, messageContent :: String, messageToolCalls :: [ToolCall], messageToolCallId :: String } deriving (Eq, Show)
data Response = Response { responseContent :: String, responseToolCalls :: [ToolCall], inputTokens :: Integer, outputTokens :: Integer } deriving (Eq, Show)
data AgentOptions = AgentOptions { generate :: [Message] -> IO (Either AgentError Response), invoke :: ToolCall -> IO (Either AgentError Json), emit :: String -> IO (Either AgentError ()), maxSteps :: Int, maxTokens :: Integer }
data RunResult = RunResult { runOutput :: String, runSteps :: Int, runInputTokens :: Integer, runOutputTokens :: Integer, runMessages :: [Message] } deriving (Eq, Show)

runAgent :: AgentOptions -> [Message] -> String -> IO (Either AgentError RunResult)
runAgent options history prompt = do
    started <- emit options "run.started"
    case started of
        Left err -> pure (Left err)
        Right () -> do
            result <- loop 1 0 0 (history ++ [Message "user" prompt [] ""])
            case result of
                Left err -> do
                    _ <- emit options "run.failed"
                    pure (Left err)
                Right value -> do
                    completed <- emit options "run.completed"
                    case completed of
                        Left err -> do
                            _ <- emit options "run.failed"
                            pure (Left err)
                        Right () -> pure (Right value)
  where
    limit = if maxSteps options > 0 then maxSteps options else 8
    loop step usedIn usedOut messages
        | step > limit = pure (Left (AgentError "AGENT_MAX_STEPS" "agent: maximum steps exceeded"))
        | otherwise = do
            generated <- generate options messages
            case generated of
                Left err -> pure (Left err)
                Right response | inputTokens response < 0 || outputTokens response < 0 ->
                    pure (Left (AgentError "AGENT_INVALID_USAGE" "agent: token usage must be non-negative"))
                Right response -> do
                    let totalIn = usedIn + inputTokens response
                        totalOut = usedOut + outputTokens response
                        next = messages ++ [Message "assistant" (responseContent response) (responseToolCalls response) ""]
                    if maxTokens options > 0 && totalIn + totalOut > maxTokens options
                        then pure (Left (AgentError "AGENT_MAX_TOKENS" "agent: maximum tokens exceeded"))
                        else if null (responseToolCalls response)
                            then pure (Right (RunResult (responseContent response) step totalIn totalOut next))
                            else do
                                result <- tools next (responseToolCalls response)
                                case result of
                                    Left err -> pure (Left err)
                                    Right updated -> loop (step + 1) totalIn totalOut updated
    tools messages [] = pure (Right messages)
    tools messages (call:rest) = do
        event <- emit options "tool.call"
        case event of
            Left err -> pure (Left err)
            Right () -> do
                result <- invoke options call
                case result of
                    Left err -> pure (Left err)
                    Right value -> case encodeJson value of
                        Left detail -> pure (Left (AgentError "TOOL_RESULT" detail))
                        Right content -> tools (messages ++ [Message "tool" content [] (toolCallId call)]) rest
