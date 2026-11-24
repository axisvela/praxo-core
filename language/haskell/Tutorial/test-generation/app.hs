module Main where

import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

readTool :: IORef Int -> Bool -> ToolCall -> IO (Either AgentError Json)
readTool readsRef simulateFailure call
    | toolCallName call /= "read_fixture" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | asString (field "fixture" (toolCallArguments call)) /= "fixture-100" =
        pure (Left (AgentError "AGENT_POLICY_DENIED" "only fixture-100 is in scope"))
    | otherwise = do
        modifyIORef' readsRef (+ 1)
        if simulateFailure
            then pure (Left (AgentError "FIXTURE_INDEX_UNAVAILABLE" "synthetic fixture unavailable"))
            else pure $ Right $ JObject
                [ ("fixture", JString "fixture-100")
                , ("functions", JNumber 2)
                , ("last_failure", JString "parse")
                , ("language", JString "dart")
                , ("source", JString "fixture_source")
                ]

draftTool :: IORef Int -> ToolCall -> IO (Either AgentError Json)
draftTool draftsRef call
    | toolCallName call /= "draft_tests" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | otherwise = do
        modifyIORef' draftsRef (+ 1)
        pure $ Right $ JObject
            [ ("suite_id", JString "tests-100")
            , ("fixture", field "fixture" (toolCallArguments call))
            , ("generated_tests", JNumber 3)
            , ("coverage_targets", JArray [JString "parse", JString "format"])
            , ("status", JString "draft_only")
            , ("review_required", JBool True)
            , ("executions", JNumber 0)
            , ("load_targets", JNumber 0)
            ]

allowKinds :: Action -> Bool
allowKinds action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" =
        case actionToolName action of
            "read_fixture" ->
                asString (field "fixture" (actionArguments action)) == "fixture-100"
            "draft_tests" ->
                asString (field "fixture" (actionArguments action)) == "fixture-100"
                    && asString (field "action" (actionArguments action)) == "generate_tests"
            _ -> False
    | otherwise = False

toolMessages :: [Message] -> [Message]
toolMessages = filter ((== "tool") . messageRole)

generateModel :: String -> [Message] -> IO (Either AgentError Response)
generateModel fixture messages =
    pure $ case toolMessages messages of
        [] ->
            Right (Response
                ""
                [ToolCall "fixture-1" "read_fixture"
                    (JObject [("fixture", JString fixture)])]
                0
                0)
        [_first] ->
            Right (Response
                ""
                [ToolCall "tests-1" "draft_tests"
                    (JObject [("fixture", JString fixture), ("action", JString "generate_tests")])]
                0
                0)
        (firstResult : rest) ->
            let lastResult = case reverse rest of
                    (value : _) -> value
                    [] -> firstResult
            in case (parseJson (messageContent firstResult), parseJson (messageContent lastResult)) of
                (Right source, Right suite) ->
                    let report = JObject
                            [ ("stage", JString "tests_generated")
                            , ("source", source)
                            , ("suite", suite)
                            , ("executions", JNumber 0)
                            , ("load_targets", JNumber 0)
                            ]
                    in case encodeJson report of
                        Right text -> Right (Response text [] 0 0)
                        Left code -> Left (AgentError code "report encoding failed")
                _ -> Left (AgentError "MODEL_ERROR" "tool evidence was not JSON")

data Outcome = Outcome
    { outcomeResult :: Either AgentError RunResult
    , outcomeReads :: Int
    , outcomeDrafts :: Int
    }

runGeneration :: String -> Bool -> IO Outcome
runGeneration fixture simulateFailure = do
    readsRef <- newIORef (0 :: Int)
    draftsRef <- newIORef (0 :: Int)
    let options = AgentOptions
            { generate = generateModel fixture
            , invoke = \call ->
                if toolCallName call == "read_fixture"
                    then readTool readsRef simulateFailure call
                    else draftTool draftsRef call
            , emit = \_ -> pure (Right ())
            , maxSteps = 5
            , maxTokens = 0
            , policy = Just allowKinds
            , allowedTools = ["read_fixture", "draft_tests"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-test-generation"
            , sessionId = "session-test-generation"
            , interruptOn = []
            , onInterruptDecision = Nothing
            , onInterrupt = Nothing
            , beforeTool = Nothing
            , onDelta = Nothing
            , generateStream = Nothing
            }
    result <- runAgent options [] "Generate bounded tests for the fixed fixture."
    reads <- readIORef readsRef
    drafts <- readIORef draftsRef
    pure (Outcome result reads drafts)

checkReport :: String -> Bool
checkReport output =
    case parseJson output of
        Right report ->
            asString (field "stage" report) == "tests_generated"
                && asString (field "status" (field "suite" report)) == "draft_only"
                && field "generated_tests" (field "suite" report) == JNumber 3
                && field "executions" report == JNumber 0
                && field "load_targets" report == JNumber 0
        Left _ -> False

main :: IO ()
main = do
    args <- getArgs
    if "--test" `elem` args
        then test
        else do
            let fixture = valueAfter "--fixture" args "fixture-100"
                simulateFailure = "--simulate-failure" `elem` args
            outcome <- runGeneration fixture simulateFailure
            case outcomeResult outcome of
                Right value -> putStrLn (runOutput value)
                Left errorValue -> do
                    hPutStrLn stderr
                        ("test generation failed: reads=" ++ show (outcomeReads outcome)
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
    success <- runGeneration "fixture-100" False
    case outcomeResult success of
        Right value
            | outcomeReads success == 1 && outcomeDrafts success == 1 && checkReport (runOutput value) ->
                putStrLn "success: fixture-100 functions=2 tests=3 status=draft_only executions=0 reads=1"
            | otherwise -> do
                hPutStrLn stderr ("success verification failed: " ++ runOutput value)
                exitFailure
        Left errorValue -> do
            hPutStrLn stderr ("success path failed: " ++ errorMessage errorValue)
            exitFailure

    denied <- runGeneration "fixture-200" False
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

    failed <- runGeneration "fixture-100" True
    case outcomeResult failed of
        Left errorValue
            | errorCode errorValue == "FIXTURE_INDEX_UNAVAILABLE"
                && outcomeReads failed == 1
                && outcomeDrafts failed == 0 ->
                putStrLn "failure: FIXTURE_INDEX_UNAVAILABLE reads=1"
            | otherwise -> do
                hPutStrLn stderr ("failure verification failed: " ++ errorCode errorValue)
                exitFailure
        Right _ -> do
            hPutStrLn stderr "failure verification failed: simulated failure succeeded"
            exitFailure
