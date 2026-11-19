module Praxo.Agent (AgentError(..), ToolCall(..), Action(..), Interrupt(..), InterruptDecision(..), InterruptHandler, InterruptApproval, interruptApprove, interruptEdit, interruptReject, interruptRespond, Message(..), Response(..), AgentOptions(..), RunResult(..), runAgent) where

import Data.Maybe (isNothing)

import Praxo.Json (Json(..), encodeJson)

interruptApprove :: String
interruptApprove = "approve"

interruptEdit :: String
interruptEdit = "edit"

interruptReject :: String
interruptReject = "reject"

interruptRespond :: String
interruptRespond = "respond"

data AgentError = AgentError { errorCode :: String, errorMessage :: String } deriving (Eq, Show)
data ToolCall = ToolCall { toolCallId :: String, toolCallName :: String, toolCallArguments :: Json } deriving (Eq, Show)
data Action = Action { actionKind :: String, actionSessionId :: String, actionToolName :: String, actionArguments :: Json } deriving (Eq, Show)
data Interrupt = Interrupt { interruptRunId :: String, interruptSessionId :: String, interruptCall :: ToolCall } deriving (Eq, Show)
data InterruptDecision = InterruptDecision { interruptAction :: String, interruptArguments :: Maybe Json, interruptResponse :: String, interruptReason :: String } deriving (Eq, Show)
type InterruptHandler = Interrupt -> IO InterruptDecision
type InterruptApproval = Interrupt -> IO Bool
data Message = Message { messageRole :: String, messageContent :: String, messageToolCalls :: [ToolCall], messageToolCallId :: String } deriving (Eq, Show)
data Response = Response { responseContent :: String, responseToolCalls :: [ToolCall], inputTokens :: Integer, outputTokens :: Integer } deriving (Eq, Show)
data AgentOptions = AgentOptions { generate :: [Message] -> IO (Either AgentError Response), invoke :: ToolCall -> IO (Either AgentError Json), emit :: String -> IO (Either AgentError ()), maxSteps :: Int, maxTokens :: Integer, policy :: Maybe (Action -> Bool), allowedTools :: [String], requirePolicy :: Bool, requireToolScope :: Bool, runId :: String, sessionId :: String, interruptOn :: [String], onInterruptDecision :: Maybe InterruptHandler, onInterrupt :: Maybe InterruptApproval, beforeTool :: Maybe (ToolCall -> IO (Either AgentError ToolCall)), onDelta :: Maybe (String -> IO ()), generateStream :: Maybe ([Message] -> (String -> IO ()) -> IO (Either AgentError Response)) }
data RunResult = RunResult { runOutput :: String, runSteps :: Int, runInputTokens :: Integer, runOutputTokens :: Integer, runMessages :: [Message] } deriving (Eq, Show)

data InterruptOutcome = InterruptOutcome
    { outcomeSkip :: Bool
    , outcomeResponse :: String
    , outcomeCall :: ToolCall
    , outcomeEdited :: Bool
    }

ensureAllowed :: Either AgentError () -> IO (Either AgentError a) -> IO (Either AgentError a)
ensureAllowed (Left err) _ = pure (Left err)
ensureAllowed (Right ()) action = action

runAgent :: AgentOptions -> [Message] -> String -> IO (Either AgentError RunResult)
runAgent options history prompt =
    case validateOptions options of
        Just err -> pure (Left err)
        Nothing -> do
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
    validateOptions opts
        | requirePolicy opts && isNothing (policy opts) =
            Just (AgentError "AGENT_INVALID_OPTIONS" "agent: require policy: policy is required")
        | requireToolScope opts && null (allowedTools opts) =
            Just (AgentError "AGENT_INVALID_OPTIONS" "agent: require tool scope: allowedTools must not be empty")
        | otherwise = Nothing
    authorize kind call = case policy options of
        Nothing -> Right ()
        Just hook ->
            if hook (Action kind (sessionId options) (toolCallName call) (toolCallArguments call))
                then Right ()
                else Left (AgentError "AGENT_POLICY_DENIED" ("agent: " ++ kind ++ " denied"))
    checkTool call
        | not (null (allowedTools options)) && toolCallName call `notElem` allowedTools options =
            Left (AgentError "AGENT_TOOL_NOT_ALLOWED" ("agent: tool " ++ toolCallName call ++ " is not allowed"))
        | otherwise = authorize "tool.invoke" call
    loop step usedIn usedOut messages
        | step > limit = pure (Left (AgentError "AGENT_MAX_STEPS" "agent: maximum steps exceeded"))
        | otherwise = ensureAllowed (authorize "model.generate" (ToolCall "" "" JNull)) $ do
            generated <- case (generateStream options, onDelta options) of
                (Just stream, Just delta) -> stream messages delta
                _ -> generate options messages
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
    tools messages (call:rest) = case checkTool call of
        Left err -> pure (Left err)
        Right () -> do
            prepared <- applyBeforeTool call
            case prepared of
                Left err -> pure (Left err)
                Right active -> do
                    interrupted <- applyInterrupt active
                    case interrupted of
                        Left err -> pure (Left err)
                        Right outcome
                            | outcomeSkip outcome -> finishSkipped messages outcome rest
                            | otherwise -> do
                                let final = outcomeCall outcome
                                    recheck = if outcomeEdited outcome || final /= call
                                        then checkTool final
                                        else Right ()
                                ensureAllowed recheck $ do
                                    event <- emit options "tool.call"
                                    case event of
                                        Left err -> pure (Left err)
                                        Right () -> do
                                            result <- invoke options final
                                            case result of
                                                Left err -> pure (Left err)
                                                Right value -> case encodeJson value of
                                                    Left detail -> pure (Left (AgentError "TOOL_RESULT" detail))
                                                    Right content -> tools (messages ++ [Message "tool" content [] (toolCallId final)]) rest
    finishSkipped messages outcome rest =
        case encodeJson (JString (outcomeResponse outcome)) of
            Left detail -> pure (Left (AgentError "TOOL_RESULT" detail))
            Right content -> tools (messages ++ [Message "tool" content [] (toolCallId (outcomeCall outcome))]) rest
    applyBeforeTool call = case beforeTool options of
        Nothing -> pure (Right call)
        Just handler -> handler call
    applyInterrupt call
        | toolCallName call `notElem` interruptOn options =
            pure (Right (InterruptOutcome False "" call False))
        | isNothing (onInterruptDecision options) && isNothing (onInterrupt options) =
            pure (Left (AgentError "AGENT_INTERRUPT_UNHANDLED"
                ("agent: approval handler not configured: " ++ toolCallName call)))
        | otherwise = do
            event <- emit options "tool.interrupt"
            case event of
                Left err -> pure (Left err)
                Right () -> do
                    let pending = Interrupt (runId options) (sessionId options) call
                    case onInterruptDecision options of
                        Just handler -> fmap (applyDecision call) (handler pending)
                        Nothing -> case onInterrupt options of
                            Just approval -> do
                                approved <- approval pending
                                pure $ if approved
                                    then Right (InterruptOutcome False "" call False)
                                    else Left (AgentError "AGENT_APPROVAL_DENIED"
                                        ("agent: tool call denied by approval: " ++ toolCallName call))
                            Nothing -> pure (Left (AgentError "AGENT_INTERRUPT_UNHANDLED"
                                ("agent: approval handler not configured: " ++ toolCallName call)))
    applyDecision call decision
        | interruptAction decision == interruptApprove =
            Right (InterruptOutcome False "" call False)
        | interruptAction decision == interruptEdit =
            case interruptArguments decision of
                Nothing -> Left (AgentError "AGENT_INTERRUPT_DECISION_INVALID" "agent: edit requires arguments")
                Just arguments -> Right (InterruptOutcome False ""
                    (call { toolCallArguments = arguments }) True)
        | interruptAction decision == interruptReject =
            Left (AgentError "AGENT_APPROVAL_DENIED"
                ("agent: tool call denied by approval: " ++ toolCallName call ++ ": "
                    ++ interruptReason decision))
        | interruptAction decision == interruptRespond =
            Right (InterruptOutcome True (interruptResponse decision) call False)
        | otherwise =
            Left (AgentError "AGENT_INTERRUPT_DECISION_INVALID"
                ("agent: invalid interrupt decision: " ++ show (interruptAction decision)))
