module Main where

import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.List (find)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

data Rule = Rule
    { ruleEffect :: String
    , ruleRole :: String
    , ruleAction :: String
    } deriving (Eq, Show)

parseRule :: String -> Either String Rule
parseRule line =
    case words line of
        ["allow", "role", role, "action", action] -> Right (Rule "allow" role action)
        ["deny", "role", role, "action", action] -> Right (Rule "deny" role action)
        _ -> Left ("invalid rule: " ++ line)

parseRules :: String -> Either String [Rule]
parseRules text = traverse parseRule (filter (not . null) (lines text))

conflict :: [Rule] -> Maybe (String, String)
conflict rules =
    find (\(r, a) -> allowed r a && denied r a) [(r, a) | Rule "allow" r a <- rules]
  where
    allowed role action = any (\x -> ruleEffect x == "allow" && ruleRole x == role && ruleAction x == action) rules
    denied role action = any (\x -> ruleEffect x == "deny" && ruleRole x == role && ruleAction x == action) rules

cleanRules :: String
cleanRules =
    unlines
        [ "allow role analyst action read"
        , "deny role guest action write"
        ]

conflictRules :: String
conflictRules =
    unlines
        [ "allow role admin action write"
        , "deny role admin action write"
        , "allow role analyst action read"
        ]

readTool :: IORef Int -> String -> Bool -> ToolCall -> IO (Either AgentError Json)
readTool readsRef source simulateFailure call
    | toolCallName call /= "read_rules" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | otherwise = do
        modifyIORef' readsRef (+ 1)
        if simulateFailure
            then pure (Left (AgentError "RULE_SOURCE_UNAVAILABLE" "rule source unavailable"))
            else case parseRules source of
                Left message -> pure (Left (AgentError "RULE_PARSE_ERROR" message))
                Right rules -> pure $ Right $ JObject
                    [ ("rules", JArray (map ruleJson rules))
                    , ("conflict", maybe JNull (\(r, a) -> JObject [("role", JString r), ("action", JString a)]) (conflict rules))
                    , ("source", JString "rule_fixture")
                    ]
  where
    ruleJson rule = JObject
        [ ("effect", JString (ruleEffect rule))
        , ("role", JString (ruleRole rule))
        , ("action", JString (ruleAction rule))
        ]

draftTool :: IORef Int -> ToolCall -> IO (Either AgentError Json)
draftTool draftsRef call
    | toolCallName call /= "draft_revision" =
        pure (Left (AgentError "TOOL_NOT_FOUND" "unknown tool"))
    | otherwise = do
        modifyIORef' draftsRef (+ 1)
        pure $ Right $ JObject
            [ ("revision_id", JString "rules-100")
            , ("action", field "action" (toolCallArguments call))
            , ("status", JString "draft_only")
            , ("review_required", JBool True)
            , ("publications", JNumber 0)
            ]

allowAction :: Action -> Bool
allowAction action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" =
        let scope = asString (field "scope" (actionArguments action))
        in scope == "team-100" &&
            case actionToolName action of
                "read_rules" -> True
                "draft_revision" ->
                    let choice = asString (field "action" (actionArguments action))
                    in choice == "review_conflict" || choice == "review_approval"
                _ -> False
    | otherwise = False

generateModel :: String -> [Message] -> IO (Either AgentError Response)
generateModel scope messages =
    pure $ case filter ((== "tool") . messageRole) messages of
        [] ->
            Right (Response ""
                [ToolCall "rules-1" "read_rules"
                    (JObject [("scope", JString scope)])] 0 0)
        [result] ->
            case parseJson (messageContent result) of
                Right evidence ->
                    let hasConflict = field "conflict" evidence /= JNull
                        choice = if hasConflict then "review_conflict" else "review_approval"
                    in Right (Response ""
                        [ToolCall "revision-1" "draft_revision"
                            (JObject
                                [ ("scope", JString scope)
                                , ("action", JString choice) ])] 0 0)
                Left code -> Left (AgentError code "rule evidence was not JSON")
        (firstResult : rest) ->
            case (parseJson (messageContent firstResult), parseJson (messageContent (last rest))) of
                (Right evidence, Right revision) ->
                    Right (Response (finalize evidence revision) [] 0 0)
                _ -> Left (AgentError "MODEL_ERROR" "rule evidence was not JSON")

finalize :: Json -> Json -> String
finalize evidence revision =
    case encodeJson (JObject
        [ ("stage", JString "rule_review_drafted")
        , ("analysis", evidence)
        , ("revision", revision)
        , ("publications", JNumber 0)
        ]) of
        Right text -> text
        Left _ -> "{}"

data Outcome = Outcome (Either AgentError RunResult) Int Int

runRules :: String -> String -> Bool -> IO Outcome
runRules source scope simulateFailure = do
    readsRef <- newIORef (0 :: Int)
    draftsRef <- newIORef (0 :: Int)
    let options = AgentOptions
            { generate = generateModel scope
            , invoke = \call ->
                if toolCallName call == "read_rules"
                    then readTool readsRef source simulateFailure call
                    else draftTool draftsRef call
            , emit = \_ -> pure (Right ())
            , maxSteps = 5
            , maxTokens = 0
            , policy = Just allowAction
            , allowedTools = ["read_rules", "draft_revision"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-rule-dsl"
            , sessionId = "session-rule-dsl"
            , interruptOn = []
            , onInterruptDecision = Nothing
            , onInterrupt = Nothing
            , beforeTool = Nothing
            , onDelta = Nothing
            , generateStream = Nothing
            }
    result <- runAgent options [] "Analyze the rule DSL and draft a review-only revision."
    reads <- readIORef readsRef
    drafts <- readIORef draftsRef
    pure (Outcome result reads drafts)

checkReport :: String -> Bool
checkReport output =
    case parseJson output of
        Right report ->
            asString (field "stage" report) == "rule_review_drafted"
                && field "publications" report == JNumber 0
                && asString (field "status" (field "revision" report)) == "draft_only"
        Left _ -> False

main :: IO ()
main = do
    args <- getArgs
    if "--test" `elem` args then test else do
        let simulateFailure = "--simulate-failure" `elem` args
            source = if "--invalid" `elem` args then "allow role admin write" else conflictRules
            scope = if "--deny" `elem` args then "team-200" else "team-100"
        Outcome result reads drafts <- runRules source scope simulateFailure
        case result of
            Right value -> putStrLn (runOutput value)
            Left errorValue -> do
                hPutStrLn stderr ("rule dsl failed: reads=" ++ show reads ++ " drafts=" ++ show drafts ++ "; " ++ errorMessage errorValue)
                exitFailure

test :: IO ()
test = do
    Outcome conflictResult reads drafts <- runRules conflictRules "team-100" False
    case conflictResult of
        Right value | reads == 1 && drafts == 1 && checkReport (runOutput value) -> do
            let report = parseReport (runOutput value)
            case report of
                Just r | field "conflict" (field "analysis" r) /= JNull -> putStrLn "success: conflict role=admin action=write status=draft_only reads=1"
                _ -> failCase "conflict evidence missing"
        _ -> failCase "conflict path failed"

    Outcome cleanResult cleanReads cleanDrafts <- runRules cleanRules "team-100" False
    case cleanResult of
        Right value | cleanReads == 1 && cleanDrafts == 1 ->
            case parseReport (runOutput value) of
                Just r | field "conflict" (field "analysis" r) == JNull -> putStrLn "success: no conflict status=draft_only reads=1"
                _ -> failCase "clean evidence not conflict-free"
        _ -> failCase "clean path failed"

    Outcome deniedResult deniedReads deniedDrafts <- runRules conflictRules "team-200" False
    case deniedResult of
        Left errorValue | errorCode errorValue == "AGENT_POLICY_DENIED"
            && deniedReads == 0 && deniedDrafts == 0 ->
            putStrLn "deny: AGENT_POLICY_DENIED reads=0"
        _ -> failCase "deny failed"

    Outcome failureResult failureReads failureDrafts <- runRules conflictRules "team-100" True
    case failureResult of
        Left errorValue | errorCode errorValue == "RULE_SOURCE_UNAVAILABLE" && failureReads == 1 && failureDrafts == 0 ->
            putStrLn "failure: RULE_SOURCE_UNAVAILABLE reads=1"
        _ -> failCase "dependency failure failed"

    Outcome invalidResult invalidReads invalidDrafts <- runRules "allow role admin write" "team-100" False
    case invalidResult of
        Left errorValue | errorCode errorValue == "RULE_PARSE_ERROR" && invalidReads == 1 && invalidDrafts == 0 ->
            putStrLn "failure: RULE_PARSE_ERROR reads=1"
        _ -> failCase "parse failure failed"

    putStrLn "Haskell rule-dsl tutorial: all checks passed"
  where
    parseReport output = case parseJson output of
        Right report -> Just report
        Left _ -> Nothing
    failCase message = do
        hPutStrLn stderr message
        exitFailure

