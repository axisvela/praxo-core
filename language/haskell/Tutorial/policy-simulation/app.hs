module Main where

import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

readTool :: IORef Int -> Bool -> ToolCall -> IO (Either AgentError Json)
readTool readsRef simulateFailure call
    | toolCallName call /= "read_population" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | asString (field "scenario" (toolCallArguments call)) /= "scenario-100" =
        pure (Left (AgentError "AGENT_POLICY_DENIED" "only scenario-100 is in scope"))
    | otherwise = do
        modifyIORef' readsRef (+ 1)
        if simulateFailure
            then pure (Left (AgentError "POPULATION_INDEX_UNAVAILABLE" "synthetic population unavailable"))
            else pure $ Right $ JObject
                [ ("scenario", JString "scenario-100")
                , ("households", JNumber 12)
                , ("agents", JNumber 30)
                , ("policy", JString "subsidy")
                , ("source", JString "population_fixture")
                ]

draftTool :: IORef Int -> ToolCall -> IO (Either AgentError Json)
draftTool draftsRef call
    | toolCallName call /= "draft_report" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | otherwise = do
        modifyIORef' draftsRef (+ 1)
        pure $ Right $ JObject
            [ ("report_id", JString "simulation-100")
            , ("scenario", field "scenario" (toolCallArguments call))
            , ("runs", JNumber 3)
            , ("sensitivity", JArray [JString "subsidy-rate", JString "household-size"])
            , ("status", JString "draft_only")
            , ("review_required", JBool True)
            , ("policy_predictions", JNumber 0)
            , ("scale_claims", JNumber 0)
            ]

allowKinds :: Action -> Bool
allowKinds action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" =
        case actionToolName action of
            "read_population" ->
                asString (field "scenario" (actionArguments action)) == "scenario-100"
            "draft_report" ->
                asString (field "scenario" (actionArguments action)) == "scenario-100"
                    && asString (field "action" (actionArguments action)) == "draft_simulation"
            _ -> False
    | otherwise = False

toolMessages :: [Message] -> [Message]
toolMessages = filter ((== "tool") . messageRole)

generateModel :: String -> [Message] -> IO (Either AgentError Response)
generateModel scenario messages =
    pure $ case toolMessages messages of
        [] ->
            Right (Response
                ""
                [ToolCall "population-1" "read_population"
                    (JObject [("scenario", JString scenario)])]
                0
                0)
        [_first] ->
            Right (Response
                ""
                [ToolCall "report-1" "draft_report"
                    (JObject [("scenario", JString scenario), ("action", JString "draft_simulation")])]
                0
                0)
        (firstResult : rest) ->
            let lastResult = case reverse rest of
                    (value : _) -> value
                    [] -> firstResult
            in case (parseJson (messageContent firstResult), parseJson (messageContent lastResult)) of
                (Right population, Right report) ->
                    let summary = JObject
                            [ ("stage", JString "policy_simulation_drafted")
                            , ("population", population)
                            , ("report", report)
                            , ("policy_predictions", JNumber 0)
                            , ("scale_claims", JNumber 0)
                            ]
                    in case encodeJson summary of
                        Right text -> Right (Response text [] 0 0)
                        Left code -> Left (AgentError code "report encoding failed")
                _ -> Left (AgentError "MODEL_ERROR" "tool evidence was not JSON")

data Outcome = Outcome
    { outcomeResult :: Either AgentError RunResult
    , outcomeReads :: Int
    , outcomeDrafts :: Int
    }

runSimulation :: String -> Bool -> IO Outcome
runSimulation scenario simulateFailure = do
    readsRef <- newIORef (0 :: Int)
    draftsRef <- newIORef (0 :: Int)
    let options = AgentOptions
            { generate = generateModel scenario
            , invoke = \call ->
                if toolCallName call == "read_population"
                    then readTool readsRef simulateFailure call
                    else draftTool draftsRef call
            , emit = \_ -> pure (Right ())
            , maxSteps = 5
            , maxTokens = 0
            , policy = Just allowKinds
            , allowedTools = ["read_population", "draft_report"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-policy-simulation"
            , sessionId = "session-policy-simulation"
            , interruptOn = []
            , onInterruptDecision = Nothing
            , onInterrupt = Nothing
            , beforeTool = Nothing
            , onDelta = Nothing
            , generateStream = Nothing
            }
    result <- runAgent options [] "Simulate the fixed population and draft a review-only report."
    reads <- readIORef readsRef
    drafts <- readIORef draftsRef
    pure (Outcome result reads drafts)

checkReport :: String -> Bool
checkReport output =
    case parseJson output of
        Right report ->
            asString (field "stage" report) == "policy_simulation_drafted"
                && asString (field "status" (field "report" report)) == "draft_only"
                && field "runs" (field "report" report) == JNumber 3
                && field "policy_predictions" report == JNumber 0
                && field "scale_claims" report == JNumber 0
        Left _ -> False

main :: IO ()
main = do
    args <- getArgs
    if "--test" `elem` args
        then test
        else do
            let scenario = valueAfter "--scenario" args "scenario-100"
                simulateFailure = "--simulate-failure" `elem` args
            outcome <- runSimulation scenario simulateFailure
            case outcomeResult outcome of
                Right value -> putStrLn (runOutput value)
                Left errorValue -> do
                    hPutStrLn stderr
                        ("policy simulation failed: reads=" ++ show (outcomeReads outcome)
                            ++ " drafts=" ++ show (outcomeDrafts outcome)
                            ++ "; " ++ errorMessage errorValue)
                    exitFailure
  where
    valueAfter flag values fallback =
        case dropWhile (/= flag) values of
            (_ : value : _) -> value
            _ -> fallback

test :: IO ()
test = do
    success <- runSimulation "scenario-100" False
    case outcomeResult success of
        Right value
            | outcomeReads success == 1 && outcomeDrafts success == 1 && checkReport (runOutput value) ->
                putStrLn "success: scenario-100 households=12 agents=30 status=draft_only predictions=0 reads=1"
            | otherwise -> do
                hPutStrLn stderr ("success verification failed: " ++ runOutput value)
                exitFailure
        Left errorValue -> do
            hPutStrLn stderr ("success path failed: " ++ errorMessage errorValue)
            exitFailure

    denied <- runSimulation "scenario-200" False
    case outcomeResult denied of
        Left errorValue
            | errorCode errorValue == "AGENT_POLICY_DENIED"
                && outcomeReads denied == 0
                && outcomeDrafts denied == 0 ->
                putStrLn "deny: AGENT_POLICY_DENIED reads=0"
            | otherwise -> do
                hPutStrLn stderr ("deny verification failed: " ++ errorCode errorValue)
                exitFailure
        Right _ -> do
            hPutStrLn stderr "deny verification failed: policy allowed the call"
            exitFailure

    failed <- runSimulation "scenario-100" True
    case outcomeResult failed of
        Left errorValue
            | errorCode errorValue == "POPULATION_INDEX_UNAVAILABLE"
                && outcomeReads failed == 1
                && outcomeDrafts failed == 0 ->
                putStrLn "failure: POPULATION_INDEX_UNAVAILABLE reads=1"
            | otherwise -> do
                hPutStrLn stderr ("failure verification failed: " ++ errorCode errorValue)
                exitFailure
        Right _ -> do
            hPutStrLn stderr "failure verification failed: simulated failure succeeded"
            exitFailure
