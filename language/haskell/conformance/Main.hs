module Main (main) where

import Control.Monad (forM, unless)
import Data.IORef
import Data.List (sort)
import qualified Praxo.Agent as A
import Praxo.Json
import Praxo.JsonSchema
import Praxo.Middleware
import Praxo.Plugin
import Praxo.Runtime
import Praxo.ToolCall
import Praxo.Wire
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (IOMode(ReadMode), hGetContents, hSetEncoding, utf8, withFile)

main :: IO ()
main = do
    arguments <- getArgs
    spec <- case arguments of
        [path] -> pure path
        _ -> fail "usage: praxo-haskell-conformance <spec-directory>"
    failures <- fmap concat $ forM (words "toolcall jsonschema plugin memory event stream checkpoint policy context middleware agent-loop") $ \group -> do
        withFile (spec ++ "/vectors/" ++ group ++ ".json") ReadMode $ \handle -> do
            hSetEncoding handle utf8
            text <- hGetContents handle
            fixture <- either fail pure (parseJson text)
            unless (field "specVersion" fixture == JString specVersion && field "group" fixture == JString group)
                (fail "unsupported fixture contract or group")
            let vectors = asArray (field "vectors" fixture)
            unless (not (null vectors)) (fail "empty vector group")
            forM vectors $ \vector -> do
                let name = asString (field "id" vector)
                result <- if group == "agent-loop" then checkAgent (field "input" vector) (field "expect" vector)
                          else pure (checkVector group (field "input" vector) (field "expect" vector))
                case result of
                    Right () -> putStrLn ("PASS " ++ name) >> pure []
                    Left message -> pure [name ++ ": " ++ message]
    let errors = concat failures
    unless (null errors) (mapM_ putStrLn errors >> exitFailure)
    putStrLn "All declared vector groups passed"

checkAgent :: Json -> Json -> IO (Either String ())
checkAgent input expected = do
    script <- newIORef (asArray (field "script" input))
    events <- newIORef []
    invocations <- newIORef (0 :: Int)
    let number value = case value of JNumber n -> truncate n; _ -> 0
        model _ = do
            remaining <- readIORef script
            case remaining of
                [] -> pure (Left (A.AgentError "SCRIPT" "script exhausted"))
                (step:rest) -> do
                    writeIORef script rest
                    let call item = A.ToolCall (asString (field "id" item)) (asString (field "name" item)) (field "arguments" item)
                    pure (Right (A.Response (asString (field "content" step)) (map call (asArray (field "toolCalls" step))) (number (field "inputTokens" step)) (number (field "outputTokens" step))))
        tool call = do
            modifyIORef' invocations (+1)
            if A.toolCallName call `elem` map (asString . field "name") (asArray (field "tools" input))
                then pure (Right (A.toolCallArguments call))
                else pure (Left (A.AgentError "TOOL_NOT_FOUND" "tool not found"))
        sink event = modifyIORef' events (++ [JString event]) >> pure (Right ())
        options = A.AgentOptions model tool sink (fromInteger (number (field "maxSteps" input))) (number (field "maxTokens" input))
    result <- A.runAgent options [] (asString (field "prompt" input))
    actualEvents <- readIORef events
    count <- readIORef invocations
    pure $ do
        case result of
            Left err -> do
                check (field "error" expected == JBool True) (show err)
                check (JString (A.errorCode err) == field "errorCode" expected) "error code mismatch"
            Right value -> do
                check (field "error" expected /= JBool True) "unexpected success"
                check (JString (A.runOutput value) == field "output" expected) "output mismatch"
                check (JNumber (fromIntegral (A.runSteps value)) == field "steps" expected) "steps mismatch"
        check (JArray actualEvents == field "events" expected) "events mismatch"
        check (JNumber (fromIntegral count) == field "toolInvocations" expected) "tool count mismatch"

checkVector :: String -> Json -> Json -> Either String ()
checkVector "toolcall" input expected
    | field "operation" input == JString "strip" =
        check (stripToolCallMarkup content == asString (field "text" expected)) "stripped text mismatch"
    | field "operation" input == JString "parse" = case parseToolCall content of
        Nothing -> check (field "nil" expected == JBool True) "expected a tool call"
        Just call -> do
            check (field "nil" expected /= JBool True) "unexpected tool call"
            check (callName call == asString (field "name" expected)) "name mismatch"
            check (equalJson (callInput call) (field "input" expected)) "input mismatch"
    | otherwise = Left "unknown toolcall operation"
  where content = asString (field "content" input)
checkVector "jsonschema" input expected = do
    errors <- validateSchema (field "schema" input) (field "data" input)
    check (null errors == (field "valid" expected == JBool True)) "validation result mismatch"
    check (sort (map errorPath errors) == sort (map asString (asArray (field "errorPaths" expected)))) "validation paths mismatch"
checkVector "plugin" input expected = do
    raw <- case field "raw" input of
        JString text -> Right text
        _ -> encodeJson (field "manifest" input)
    case parseManifest raw of
        Left _ -> check (field "valid" expected == JBool False) "manifest unexpectedly rejected"
        Right manifest -> do
            check (field "valid" expected == JBool True) "manifest unexpectedly accepted"
            mapM_ (\key -> unless (field key expected == JNull) (check (field key manifest == field key expected) (key ++ " mismatch"))) ["id", "kind"]
checkVector "memory" input expected =
    let record item = MemoryRecord
            (stringField "id" item)
            (stringField "frame" item)
            (stringField "content" item)
            (stringField "createdAt" item)
        store = foldl (\current put -> fst (memoryPut current (stringField "session" put) (record (field "record" put)))) newMemoryStore (asArray (field "puts" input))
        records = memorySearch store (stringField "session" input) (stringField "query" input) (numberField "limit" input)
        ids = if null records then JNull else JArray (map (JString . recordId) records)
        contents = if null records then JNull else JArray (map (JString . recordContent) records)
    in do
        check (equalJson ids (field "ids" expected)) "ids mismatch"
        check (equalJson contents (field "contents" expected)) "contents mismatch"
checkVector "event" input expected =
    let events = [Event (asString kind) "s1" Nothing JNull | kind <- asArray (field "events" input)]
    in if stringField "sink" input == "multi" then
        let count = max 1 (numberField "sinkCount" input)
            final = foldl emitSink (multiSink (replicate count newSink)) events
            perSink = JArray [JArray (map JString kinds) | kinds <- sinkKindLists final]
        in check (equalJson perSink (field "perSink" expected)) "perSink mismatch"
    else
        let predicate = map asString (asArray (field "predicateTypes" input))
            final = foldl emitSink (filterSink newSink predicate) events
            kinds = sinkKinds final
            delivered = if null kinds then JNull else JArray (map JString kinds)
        in check (equalJson delivered (field "delivered" expected)) "delivered mismatch"
checkVector "stream" _ expected =
    check (JArray (map JString streamKinds) == field "kinds" expected) "stream kinds mismatch"
checkVector "checkpoint" input expected =
    let allow = foldl (\current kind -> either (const current) id (registerCheckpoint current (asString kind))) newCheckpoint (asArray (field "registered" input))
        operation = if field "operation" input == JNull then "roundtrip" else stringField "operation" input
        kind = stringField "type" input
        value = field "value" input
        expectedCode = asString (field "errorCode" expected)
        codeOf result = case result of Left code -> code; Right _ -> ""
    in case operation of
        "roundtrip" -> case checkpointMarshal allow kind value of
            Left code -> check (code == expectedCode) ("checkpoint error " ++ code)
            Right data' -> case checkpointUnmarshal allow data' of
                Left code -> check (code == expectedCode) ("checkpoint error " ++ code)
                Right decoded -> check (equalJson decoded (field "value" expected)) "checkpoint value mismatch"
        "marshal" -> check (codeOf (checkpointMarshal allow kind value) == expectedCode) "marshal error mismatch"
        "unmarshal" -> case encodeJson (JObject [("type", JString kind), ("data", value)]) of
            Left detail -> Left detail
            Right envelope -> check (codeOf (checkpointUnmarshal allow envelope) == expectedCode) "unmarshal error mismatch"
        _ -> Left "unknown checkpoint operation"
checkVector "policy" input expected =
    let grants = [PathGrant (stringField "root" item) (if field "access" item == JNull then "read" else stringField "access" item) | item <- asArray (field "grants" input)]
        target = stringField "target" input
        need = if field "need" input == JNull then "read" else stringField "need" input
        result = pathChecker grants >>= \checker -> pathCheck checker target need
    in if field "error" expected == JBool True
        then case result of
            Left _ -> Right ()
            Right _ -> Left "expected policy error"
        else case result of
            Left code -> Left ("policy error " ++ code)
            Right decision -> check (decisionAllowed decision == (field "allowed" expected == JBool True)) "allowed mismatch"
checkVector "context" input expected =
    let messages = [ContextMessage (stringField "role" item) (stringField "content" item) [] [] Nothing | item <- asArray (field "messages" input)]
        operation = stringField "operation" input
    in if operation == "estimate"
        then check (estimateTokens messages == numberField "tokens" expected) "token estimate mismatch"
        else
            let budgetNode = field "budget" input
                budget = ContextBudget (numberField "maxTokens" budgetNode) (numberField "keepRecent" budgetNode)
                (output, ok) = compactContext budget messages
            in do
                check (ok == (field "ok" expected == JBool True)) "context ok mismatch"
                if ok
                    then do
                        check (estimateTokens output == numberField "tokens" expected) "compacted token mismatch"
                        check (equalJson (JArray (map messageWire output)) (field "messages" expected)) "compacted messages mismatch"
                    else Right ()
checkVector "middleware" input expected =
    case stringField "operation" input of
        "pii" -> check (piiRedact (stringField "text" input) == stringField "text" expected) "pii mismatch"
        "pii-value" -> check (equalJson (redactValue (field "value" input)) (field "value" expected)) "pii value mismatch"
        "structured" ->
            let repairText = field "repairOutput" input
                repair = if repairText == JNull then Nothing else Just (\_ -> Right (asString repairText))
                config = structuredOutput (field "schema" input) (numberField "maxRepairs" input) repair
            in case applyStructured config (stringField "output" input) of
                Right output -> do
                    check (field "ok" expected == JBool True) "expected structured error"
                    check (output == stringField "output" expected) "structured output mismatch"
                Left code -> do
                    check (field "ok" expected /= JBool True) "expected structured success"
                    check (code == stringField "errorCode" expected) "structured error code mismatch"
        "call-limit" ->
            let limit = callLimit (numberField "modelLimit" input) (numberField "toolLimit" input)
                step (current, outcomes) call =
                    case asString call of
                        "model" -> case callLimitModel current of
                            Left code -> (current, outcomes ++ [code])
                            Right next -> (next, outcomes ++ ["ok"])
                        _ -> case callLimitTool current of
                            Left code -> (current, outcomes ++ [code])
                            Right next -> (next, outcomes ++ ["ok"])
                (_, outcomes) = foldl step (limit, []) (asArray (field "calls" input))
            in check (JArray (map JString outcomes) == field "outcomes" expected) "call limit mismatch"
        "tool-selection" ->
            let selection = toolSelection (map asString (asArray (field "selected" input)))
                tools = map asString (asArray (field "tools" input))
                advertised = selectTools selection tools
                reject = either id (const "ok") (checkToolSelected selection (stringField "requested" input))
            in do
                check (JArray (map JString advertised) == field "advertised" expected) "advertised tools mismatch"
                check (reject == stringField "reject" expected) "tool selection reject mismatch"
        "fallback" ->
            let content = stringField "fallbackContent" input
            in check (fallbackEither (Left "MODEL_ERROR" :: Either String String) (Right content) == Right content) "fallback mismatch"
        _ -> Left "unknown middleware operation"
checkVector _ _ _ = Left "unsupported vector group"

check :: Bool -> String -> Either String ()
check True _ = Right ()
check False message = Left message

stringField :: String -> Json -> String
stringField name = asString . field name

numberField :: String -> Json -> Int
numberField name value = case field name value of JNumber number -> truncate number; _ -> 0
