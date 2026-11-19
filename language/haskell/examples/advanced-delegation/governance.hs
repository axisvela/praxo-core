module Main where

import Data.IORef
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Delegation
import Praxo.Json

data GovState = GovState
    { govEffects :: IORef [String]
    , govBudget :: IORef Int
    , govChildren :: IORef Int
    }

data RunConfig = RunConfig
    { configAllowed :: [String]
    , configPolicy :: Action -> Bool
    , configDepth :: Int
    , configMaxDepth :: Int
    , configMaxChildren :: Int
    , configUseBudget :: Bool
    , configUseChildren :: Bool
    , configCancelled :: Bool
    , configEditToBlocked :: Bool
    }

defaultConfig :: [String] -> (Action -> Bool) -> RunConfig
defaultConfig allowed policy = RunConfig
    { configAllowed = allowed
    , configPolicy = policy
    , configDepth = 0
    , configMaxDepth = -1
    , configMaxChildren = -1
    , configUseBudget = False
    , configUseChildren = False
    , configCancelled = False
    , configEditToBlocked = False
    }

scriptedGenerate :: IORef [Response] -> [Message] -> IO (Either AgentError Response)
scriptedGenerate steps _messages = do
    remaining <- readIORef steps
    case remaining of
        step : rest -> writeIORef steps rest >> pure (Right step)
        [] -> pure (Right (Response "done" [] 0 0))

targetOf :: Action -> String
targetOf action = asString (field "target" (actionArguments action))

permissiveRecord :: Action -> Bool
permissiveRecord action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" = actionToolName action == "record"
    | otherwise = False

parentBlocked :: Action -> Bool
parentBlocked action
    | actionKind action == "model.generate" = True
    | actionKind action /= "tool.invoke" = False
    | actionToolName action /= "record" = False
    | otherwise = targetOf action /= "blocked"

composedPolicy :: Action -> Bool
composedPolicy action = parentBlocked action && permissiveRecord action

recordCall :: String -> String -> ToolCall
recordCall ident target =
    ToolCall ident "record" (JObject [("target", JString target)])

toolResponse :: ToolCall -> Response
toolResponse call = Response "" [call] 0 0

makeModelFor :: String -> String -> IO (IORef [Response])
makeModelFor tool target =
    newIORef
        [ toolResponse (ToolCall "call-1" tool (JObject [("target", JString target)]))
        , Response "done" [] 0 0
        ]

deniedTask :: String -> String -> SubagentTask
deniedTask status code = SubagentTask
    { subagentTaskKey = "subagent"
    , subagentParentSession = "governance-parent"
    , subagentAgent = "governance-child"
    , subagentTaskMode = "isolated"
    , subagentStatus = status
    , subagentTaskOutput = ""
    , subagentTaskError = code
    }

runChild :: GovState
    -> (ToolCall -> IO (Either AgentError Json))
    -> ([Message] -> IO (Either AgentError Response))
    -> RunConfig
    -> IO SubagentTask
runChild state invokeFn generateFn config = do
    cancelled <- pure (configCancelled config)
    depthBlocked <- pure (configMaxDepth config >= 0 && configDepth config > configMaxDepth config)
    budget <- readIORef (govBudget state)
    children <- readIORef (govChildren state)
    let childBlocked = configMaxChildren config >= 0 && children >= configMaxChildren config
        budgetBlocked = configUseBudget config && budget <= 0
    if cancelled
        then pure (deniedTask "cancelled" "CANCELLED")
        else if depthBlocked
            then pure (deniedTask "denied" "DEPTH_LIMIT")
            else if childBlocked
                then pure (deniedTask "denied" "CHILD_LIMIT")
                else if budgetBlocked
                    then pure (deniedTask "denied" "BUDGET_EXHAUSTED")
                    else do
                        if configUseChildren config then modifyIORef' (govChildren state) (+ 1) else pure ()
                        let options = (baseOptions generateFn invokeFn)
                                { maxSteps = 3
                                , policy = Just (configPolicy config)
                                , allowedTools = configAllowed config
                                , requirePolicy = True
                                , requireToolScope = True
                                , interruptOn = if configEditToBlocked config then ["record"] else []
                                , onInterruptDecision = if configEditToBlocked config
                                    then Just $ \_interrupt -> pure (InterruptDecision interruptEdit
                                        (Just (JObject [("target", JString "blocked")])) "" "")
                                    else Nothing
                                }
                            runner _request = do
                                result <- runAgent options [] "run child"
                                pure $ case result of
                                    Left err -> Left err
                                    Right value -> Right (SubagentResult "child" "child" (runOutput value))
                        task <- subagentRun runner (SubagentRequest
                            "governance-parent" "governance-child" "run child" "isolated")
                        case task of
                            Left err -> pure (deniedTask "failed" (errorCode err))
                            Right value -> do
                                if configUseBudget config && subagentStatus value == "completed"
                                    then modifyIORef' (govBudget state) (subtract 1)
                                    else pure ()
                                pure value

baseOptions :: ([Message] -> IO (Either AgentError Response))
    -> (ToolCall -> IO (Either AgentError Json))
    -> AgentOptions
baseOptions generateFn invokeFn = AgentOptions
    { generate = generateFn
    , invoke = invokeFn
    , emit = \_ -> pure (Right ())
    , maxSteps = 8
    , maxTokens = 0
    , policy = Nothing
    , allowedTools = []
    , requirePolicy = False
    , requireToolScope = False
    , runId = "run-governance"
    , sessionId = "governance-session"
    , interruptOn = []
    , onInterruptDecision = Nothing
    , onInterrupt = Nothing
    , beforeTool = Nothing
    , onDelta = Nothing
    , generateStream = Nothing
    }

assertTrue :: Bool -> String -> IO ()
assertTrue condition message =
    if condition then pure () else do
        hPutStrLn stderr ("assertion failed: " ++ message)
        exitFailure

main :: IO ()
main = do
    let makeState = GovState <$> newIORef [] <*> newIORef 0 <*> newIORef 0
        makeInvoke state call
            | toolCallName call `elem` ["record", "write"] = do
                let target = asString (field "target" (toolCallArguments call))
                modifyIORef' (govEffects state) (++ [target])
                pure (Right (JString "ok"))
            | otherwise = pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))

    scopeState <- makeState
    scopeSteps <- makeModelFor "write" "escape"
    scope <- runChild scopeState (makeInvoke scopeState) (scriptedGenerate scopeSteps)
        (defaultConfig ["record"] permissiveRecord)
    scopeEffects <- readIORef (govEffects scopeState)
    assertTrue (subagentStatus scope == "failed") "scope narrowing status"
    assertTrue (length (filter (== "escape") scopeEffects) == 0) "scope narrowing effect"

    policyState <- makeState
    policySteps <- makeModelFor "record" "blocked"
    composed <- runChild policyState (makeInvoke policyState) (scriptedGenerate policySteps)
        (defaultConfig ["record"] composedPolicy)
    policyEffects <- readIORef (govEffects policyState)
    assertTrue (subagentStatus composed == "failed") "policy composition status"
    assertTrue (length (filter (== "blocked") policyEffects) == 0) "policy composition effect"

    budgetState <- makeState
    modifyIORef' (govBudget budgetState) (+ 1)
    let budgetConfig = (defaultConfig ["record"] permissiveRecord) { configUseBudget = True }
    budgetSteps <- newIORef [toolResponse (recordCall "call-1" "sibling")]
    let siblingGenerate = scriptedGenerate budgetSteps
    first <- runChild budgetState (makeInvoke budgetState) siblingGenerate budgetConfig
    second <- runChild budgetState (makeInvoke budgetState) siblingGenerate budgetConfig
    budgetEffects <- readIORef (govEffects budgetState)
    assertTrue (subagentStatus first == "completed") "first sibling"
    assertTrue (subagentStatus second == "denied" && subagentTaskError second == "BUDGET_EXHAUSTED") "second sibling budget"
    assertTrue (length (filter (== "sibling") budgetEffects) == 1) "sibling effect count"

    limitState <- makeState
    let limitConfig = (defaultConfig ["record"] permissiveRecord)
            { configMaxChildren = 1, configUseChildren = True }
    limitSteps <- newIORef [toolResponse (recordCall "call-1" "limit")]
    let limitGenerate = scriptedGenerate limitSteps
    firstLimit <- runChild limitState (makeInvoke limitState) limitGenerate limitConfig
    secondLimit <- runChild limitState (makeInvoke limitState) limitGenerate limitConfig
    deepSteps <- newIORef [toolResponse (recordCall "call-1" "limit")]
    deep <- runChild limitState (makeInvoke limitState) (scriptedGenerate deepSteps)
        (limitConfig { configDepth = 2, configMaxDepth = 1 })
    limitEffects <- readIORef (govEffects limitState)
    assertTrue (subagentStatus firstLimit == "completed") "first limit"
    assertTrue (subagentTaskError secondLimit == "CHILD_LIMIT") "child limit"
    assertTrue (subagentTaskError deep == "DEPTH_LIMIT") "depth limit"
    assertTrue (length (filter (== "limit") limitEffects) == 1) "limit effect count"

    cancelState <- makeState
    cancelSteps <- newIORef [toolResponse (recordCall "call-1" "cancel")]
    cancelled <- runChild cancelState (makeInvoke cancelState) (scriptedGenerate cancelSteps)
        (defaultConfig ["record"] permissiveRecord) { configCancelled = True }
    cancelEffects <- readIORef (govEffects cancelState)
    assertTrue (subagentStatus cancelled == "cancelled") "cancelled status"
    assertTrue (length (filter (== "cancel") cancelEffects) == 0) "cancelled effect"

    editState <- makeState
    editSteps <- newIORef [toolResponse (recordCall "call-1" "edit-me")]
    edited <- runChild editState (makeInvoke editState) (scriptedGenerate editSteps)
        (defaultConfig ["record"] parentBlocked) { configEditToBlocked = True }
    editEffects <- readIORef (govEffects editState)
    assertTrue (subagentStatus edited == "failed") "edited status"
    assertTrue (length (filter (`elem` ["edit-me", "blocked"]) editEffects) == 0) "edited effect"

    putStrLn "Haskell advanced delegation governance: 6/6 passed"
