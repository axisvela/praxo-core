module Main where

import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

papers :: [(String, String, String)]
papers =
    [ ("paper-1", "Sparse retrieval improves recall on fixed benchmarks", "Claim A is supported by the synthetic fixture")
    , ("paper-2", "Dense retrieval improves latency on edge devices", "Claim B is unverified outside the fixture")
    ]

searchTool :: IORef Int -> Bool -> ToolCall -> IO (Either AgentError Json)
searchTool readsRef simulateFailure call
    | toolCallName call /= "search_literature" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | asString (field "scope" (toolCallArguments call)) /= "public" =
        pure (Left (AgentError "AGENT_POLICY_DENIED" "only public literature is readable"))
    | otherwise = do
        modifyIORef' readsRef (+ 1)
        if simulateFailure
            then pure (Left (AgentError "LITERATURE_INDEX_UNAVAILABLE" "synthetic index unavailable"))
            else pure (Right (JObject [("scope", JString "public"), ("matches", JArray (map paperJson papers))]))
  where
    paperJson (ident, title, claim) =
        JObject
            [ ("id", JString ident)
            , ("title", JString title)
            , ("claim", JString claim)
            , ("score", JNumber 1)
            ]

draftTool :: IORef Int -> ToolCall -> IO (Either AgentError Json)
draftTool draftsRef call
    | toolCallName call /= "draft_hypotheses" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | otherwise = do
        modifyIORef' draftsRef (+ 1)
        pure $ Right $ JObject
            [ ("hypothesis_id", JString "hypothesis-100")
            , ("paper", field "paper" (toolCallArguments call))
            , ("status", JString "draft_only")
            , ("review_required", JBool True)
            , ("unverified", JBool True)
            , ("publications", JNumber 0)
            ]

allowKinds :: Action -> Bool
allowKinds action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" =
        case actionToolName action of
            "search_literature" ->
                asString (field "scope" (actionArguments action)) == "public"
            "draft_hypotheses" ->
                asString (field "paper" (actionArguments action)) == "paper-1"
                    && asString (field "action" (actionArguments action)) == "propose"
            _ -> False
    | otherwise = False

toolMessages :: [Message] -> [Message]
toolMessages = filter ((== "tool") . messageRole)

matchesOf :: Message -> [Json]
matchesOf message =
    case parseJson (messageContent message) of
        Right value -> asArray (field "matches" value)
        Left _ -> []

topPaper :: [Message] -> String
topPaper messages =
    case concatMap matchesOf messages of
        (match : _) -> asString (field "id" match)
        [] -> ""

generateModel :: String -> [Message] -> IO (Either AgentError Response)
generateModel scope messages =
    pure $ case toolMessages messages of
        [] ->
            Right (Response
                ""
                [ToolCall "search-1" "search_literature"
                    (JObject [("query", JString "retrieval"), ("scope", JString scope)])]
                0
                0)
        [first] -> do
            let paper = topPaper [first]
            Right (Response
                ""
                [ToolCall "hypothesis-1" "draft_hypotheses"
                    (JObject [("paper", JString paper), ("action", JString "propose")])]
                0
                0)
        (firstResult : rest) ->
            let lastResult = case reverse rest of
                    (value : _) -> value
                    [] -> firstResult
            in case (parseJson (messageContent firstResult), parseJson (messageContent lastResult)) of
                (Right evidence, Right hypothesis) ->
                    let report = JObject
                            [ ("stage", JString "hypotheses_drafted")
                            , ("literature", evidence)
                            , ("hypothesis", hypothesis)
                            , ("publications", JNumber 0)
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

runReview :: String -> Bool -> IO Outcome
runReview scope simulateFailure = do
    readsRef <- newIORef (0 :: Int)
    draftsRef <- newIORef (0 :: Int)
    let options = AgentOptions
            { generate = generateModel scope
            , invoke = \call ->
                if toolCallName call == "search_literature"
                    then searchTool readsRef simulateFailure call
                    else draftTool draftsRef call
            , emit = \_ -> pure (Right ())
            , maxSteps = 5
            , maxTokens = 0
            , policy = Just allowKinds
            , allowedTools = ["search_literature", "draft_hypotheses"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-literature-review"
            , sessionId = "session-literature-review"
            , interruptOn = []
            , onInterruptDecision = Nothing
            , onInterrupt = Nothing
            , beforeTool = Nothing
            , onDelta = Nothing
            , generateStream = Nothing
            }
    result <- runAgent options [] "Review fixed literature and draft unverified hypotheses."
    reads <- readIORef readsRef
    drafts <- readIORef draftsRef
    pure (Outcome result reads drafts)

checkReport :: String -> Bool
checkReport output =
    case parseJson output of
        Right report ->
            asString (field "stage" report) == "hypotheses_drafted"
                && asString (field "status" (field "hypothesis" report)) == "draft_only"
                && field "unverified" (field "hypothesis" report) == JBool True
                && field "publications" report == JNumber 0
        Left _ -> False

main :: IO ()
main = do
    args <- getArgs
    if "--test" `elem` args
        then test
        else do
            let scope = valueAfter "--scope" args "public"
                simulateFailure = "--simulate-failure" `elem` args
            outcome <- runReview scope simulateFailure
            case outcomeResult outcome of
                Right value -> putStrLn (runOutput value)
                Left errorValue -> do
                    hPutStrLn stderr
                        ("literature review failed: reads=" ++ show (outcomeReads outcome)
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
    success <- runReview "public" False
    case outcomeResult success of
        Right value
            | outcomeReads success == 1 && outcomeDrafts success == 1 && checkReport (runOutput value) ->
                putStrLn "success: paper-1 stage=hypotheses_drafted status=draft_only publications=0 reads=1"
            | otherwise -> do
                hPutStrLn stderr ("success verification failed: " ++ runOutput value)
                exitFailure
        Left errorValue -> do
            hPutStrLn stderr ("success path failed: " ++ errorMessage errorValue)
            exitFailure

    denied <- runReview "private" False
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

    failed <- runReview "public" True
    case outcomeResult failed of
        Left errorValue
            | errorCode errorValue == "LITERATURE_INDEX_UNAVAILABLE"
                && outcomeReads failed == 1
                && outcomeDrafts failed == 0 ->
                putStrLn "failure: LITERATURE_INDEX_UNAVAILABLE reads=1"
            | otherwise -> do
                hPutStrLn stderr ("failure verification failed: " ++ errorCode errorValue)
                exitFailure
        Right _ -> do
            hPutStrLn stderr "failure verification failed: simulated failure succeeded"
            exitFailure
