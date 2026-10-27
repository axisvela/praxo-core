module Main (main) where

import Control.Monad (forM_, unless)
import Data.Either (isLeft)
import Data.Ratio ((%))
import Data.IORef
import qualified Praxo.Agent as A
import Praxo.Json
import Praxo.JsonSchema
import Praxo.Pattern
import Praxo.Plugin
import Praxo.ToolCall
import Praxo.Wire

main :: IO ()
main = do
    agentTests
    assert "contract version" (specVersion == "0.2.0" && sdkVersion == "0.1.0")
    forM_ ["", "01", "1.", "+1", "NaN", "1e", "[1,]", "{\"a\":1,}", "{}{}", "\"\\q\"", "\"\\ud800\"", "\"\\udc00\"", "\"\\ud800\\u0041\"", "\"line\nbreak\"", "true garbage"] $ \raw ->
        assert ("invalid JSON " ++ show raw) (isLeft (parseJson raw))
    assert "unicode escape" (parseJson "\"\\u00e9\\ud83d\\ude00\"" == Right (JString "\x00e9\x1f600"))
    assert "raw Unicode" (parseJson "\"\x00e9\"" == Right (JString "\x00e9"))
    assert "exact numeric equality" (equalJson (json "1.00e2") (JNumber 100))
    assert "object ordering" (equalJson (json "{\"b\":2,\"a\":1}") (json "{\"a\":1,\"b\":2}"))
    assert "duplicate keys use last value" (equalJson (json "{\"a\":1,\"a\":2}") (json "{\"a\":2}"))
    assert "JSON round trip" ((encodeJson (JString "quote\" slash\\ null\0 \x1f600") >>= parseJson) == Right (JString "quote\" slash\\ null\0 \x1f600"))
    assert "non-decimal rational" (isLeft (encodeJson (JNumber (1 % 3))))
    assert "surrogate output rejected" (isLeft (encodeJson (JString ['\xD800'])))
    assert "JSON depth bounded" (isLeft (parseJson (replicate 66 '[' ++ "0" ++ replicate 66 ']')))
    assert "numeric exponent bounded" (isLeft (parseJson "1e99999"))
    assert "input size bounded" (isLeft (parseJson (replicate 1048577 ' ')))
    assert "toolcall governance metadata" (case parseToolCall "{\"name\":\"echo\",\"input\":{},\"idempotency_key\":\"k\"}" of
        Just call -> lookup "idempotency_key" (callMetadata call) == Just "k"
        _ -> False)
    assert "toolcall rejects array input" (parseToolCall "{\"name\":\"echo\",\"input\":[]}" == Nothing)
    assert "toolcall plain line must be dotted" (parseToolCall "echo {}" == Nothing)
    assert "toolcall empty name rejected" (parseToolCall "{\"name\":\"\",\"input\":{}}" == Nothing)
    assert "toolcall input bounded" (parseToolCall (replicate 262145 '<') == Nothing)
    assert "unterminated markup is preserved" (stripToolCallMarkup "abc<not a block" == "abc<not a block")
    assert "toolcall last block wins" (fmap callName (parseToolCall "<a.one>{}</a.one><b.two>{}</b.two>") == Just "b.two")
    assert "invalid final toolcall cannot invoke an earlier call" (parseToolCall "<a.one>{}</a.one><b.two>{bad}</b.two>" == Nothing)
    assert "typed governance metadata rejected" (parseToolCall "{\"name\":\"echo\",\"input\":{},\"risk\":42}" == Nothing)
    assert "invalid markup is not stripped" (stripToolCallMarkup "before<tool_call bogus>{}</tool_call>after" == "before<tool_call bogus>{}</tool_call>after")
    assert "markup text preserved" (stripToolCallMarkup "before<a.one>{}</a.one>after" == "beforeafter")
    assert "integer rejects fraction" (not (null (validation "{\"type\":\"integer\"}" "1.5")))
    assert "array item path" (map errorPath (validation "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}" "[1]") == ["$[0]"])
    assert "numeric minimum" (not (null (validation "{\"type\":\"number\",\"minimum\":2}" "1")))
    assert "zero bound compatibility" (null (validation "{\"type\":\"number\",\"minimum\":0}" "-1"))
    assert "enum numeric equality" (null (validation "{\"enum\":[1]}" "1.0"))
    assert "optional missing property" (null (validation "{\"properties\":{\"a\":{\"type\":\"string\"}}}" "{}"))
    assert "pattern range" (matchPattern "^[a-z]+[0-9]?$" "abc2" == Right True)
    assert "pattern substring" (matchPattern "ab" "xxabyy" == Right True)
    assert "pattern start anchor" (matchPattern "^ab" "xxab" == Right False)
    assert "pattern negated class" (matchPattern "^[^0-9]+$" "abc" == Right True)
    assert "pattern escaped digit" (matchPattern "^\\d+$" "123" == Right True)
    assert "pattern rejects unsupported groups" (isLeft (matchPattern "(a|b)" "a"))
    assert "pattern bounded work" (isLeft (matchPattern "a*" (replicate 10000 'a')))
    assert "schema surfaces unsupported pattern" (isLeft (validateSchema (json "{\"pattern\":\"(a)\"}") (JString "a")))
    assert "schema rejects non-object" (isLeft (validateSchema JNull JNull))
    forM_ ["{\"type\":42}", "{\"required\":true}", "{\"properties\":[]}", "{\"items\":false}", "{\"minimum\":\"x\"}", "{\"minLength\":-1}", "{\"properties\":{\"absent\":{\"type\":42}}}"] $ \definition ->
        assert "schema rejects malformed declarations" (isLeft (validateSchema (json definition) JNull))
    let base = json "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}"
    assert "valid process manifest" (validateManifest base == Right ())
    assert "duplicate manifest fields rejected" (isLeft (validateManifest (JObject (("id", JString "com.example.echo") : asObject base))))
    forM_ [("extra", JBool True), ("id", JString "Bad.ID"), ("version", JString "01.0.0"), ("protocol", JString "v1"),
           ("capabilities", JArray [JString "x", JString "x"]), ("capabilities", JArray [JString ""]),
           ("limits", JObject [("memoryMB", JNumber (-1))]), ("limits", JObject [("unknown", JNumber 1)]),
           ("entrypoint", JObject [("type", JString "process")]), ("isolation", JString "wasm"),
           ("health", JObject [("intervalMs", JNumber 10)]), ("sbom", JString "../secret"),
           ("signature", JObject [("algorithm", JString "ed25519")]),
           ("permissions", JObject [("network", JArray [JObject [("host", JString "example.com"), ("port", JNumber 65536)]])])] $ \(key, value) ->
        assert ("invalid manifest " ++ key) (isLeft (validateManifest (set key value base)))
    assert "manifest trailing data" (isLeft (parseManifest "{} {}"))
    putStrLn "Haskell wire regression tests passed"

agentTests :: IO ()
agentTests = do
    events <- newIORef []
    requests <- newIORef []
    calls <- newIORef (0 :: Int)
    let call = A.ToolCall "id" "echo" (JObject [("x", JNumber 1)])
        sink name = modifyIORef' events (++ [name]) >> pure (Right ())
        model messages = do
            modifyIORef' requests (++ [messages])
            n <- readIORef calls
            pure (Right (if n == 0 then A.Response "" [call] 2 1 else A.Response "done" [] 1 1))
        tool _ = modifyIORef' calls (+1) >> pure (Right JNull)
        options = A.AgentOptions model tool sink 2 5
    result <- A.runAgent options [] "hello"
    assert "agent success and usage" (case result of Right r -> A.runSteps r == 2 && A.runInputTokens r == 3 && A.runOutputTokens r == 2; _ -> False)
    history <- readIORef requests
    assert "agent tool history" (case history of [_, [user, assistant, toolMessage]] -> A.messageRole user == "user" && A.messageToolCalls assistant == [call] && A.messageToolCallId toolMessage == "id" && A.messageContent toolMessage == "null"; _ -> False)
    recorded <- readIORef events
    assert "agent event order" (recorded == ["run.started", "tool.call", "run.completed"])
    let failure = A.AgentError "CUSTOM" "failure"
        checkFailure label opts expectedEvents = do
            writeIORef events []
            actual <- A.runAgent opts [] "x"
            recordedEvents <- readIORef events
            assert label (actual == Left failure && recordedEvents == expectedEvents)
    checkFailure "model error" (options { A.generate = \_ -> pure (Left failure) }) ["run.started", "run.failed"]
    checkFailure "tool error" (options { A.generate = \_ -> pure (Right (A.Response "" [call] 0 0)), A.invoke = \_ -> pure (Left failure) }) ["run.started", "tool.call", "run.failed"]
    let badSink name = sink name >> pure (if name == "tool.call" then Left failure else Right ())
    checkFailure "event error" (options { A.generate = \_ -> pure (Right (A.Response "" [call] 0 0)), A.emit = badSink }) ["run.started", "tool.call", "run.failed"]
    writeIORef events []
    started <- A.runAgent (options { A.emit = \name -> sink name >> pure (Left failure) }) [] "x"
    startedEvents <- readIORef events
    assert "started event error" (started == Left failure && startedEvents == ["run.started"])
    let completedSink name = sink name >> pure (if name == "run.completed" || name == "run.failed" then Left failure else Right ())
    checkFailure "completion event error" (options { A.generate = \_ -> pure (Right (A.Response "done" [] 0 0)), A.emit = completedSink }) ["run.started", "run.completed", "run.failed"]
    let failedSink name = sink name >> pure (if name == "run.failed" then Left (A.AgentError "SINK" "sink failure") else Right ())
    checkFailure "failure event preserves original error" (options { A.generate = \_ -> pure (Left failure), A.emit = failedSink }) ["run.started", "run.failed"]
    writeIORef events []
    budget <- A.runAgent (options { A.generate = \_ -> pure (Right (A.Response "x" [] 3 3)) }) [] "x"
    assert "input and output token budget" (case budget of Left err -> A.errorCode err == "AGENT_MAX_TOKENS"; _ -> False)
    let invalidUsage = Left (A.AgentError "AGENT_INVALID_USAGE" "agent: token usage must be non-negative")
    forM_ [("negative input", -1, 2), ("negative output", 2, -1)] $ \(label, input, output) -> do
        writeIORef events []
        writeIORef calls 0
        invalid <- A.runAgent (options { A.maxTokens = 0, A.generate = \_ -> pure (Right (A.Response "" [call] input output)) }) [] "x"
        invalidEvents <- readIORef events
        invalidCalls <- readIORef calls
        assert label (invalid == invalidUsage && invalidEvents == ["run.started", "run.failed"] && invalidCalls == 0)
    writeIORef events []
    writeIORef calls 0
    offset <- A.runAgent (options { A.generate = \_ -> do
        n <- readIORef calls
        pure (Right (if n == 0 then A.Response "" [call] 4 1 else A.Response "" [call] (-5) 2)) }) [] "x"
    offsetEvents <- readIORef events
    offsetCalls <- readIORef calls
    assert "negative usage cannot offset prior steps" (offset == invalidUsage && offsetEvents == ["run.started", "tool.call", "run.failed"] && offsetCalls == 1)
    encoding <- A.runAgent (options { A.generate = \_ -> pure (Right (A.Response "" [call] 0 0)), A.invoke = \_ -> pure (Right (JNumber (1 % 3))) }) [] "x"
    assert "tool result encoding error" (case encoding of Left err -> A.errorCode err == "TOOL_RESULT"; _ -> False)
    writeIORef calls 0
    limited <- A.runAgent (options { A.maxSteps = 0, A.generate = \_ -> pure (Right (A.Response "" [call] 0 0)) }) [] "x"
    count <- readIORef calls
    assert "default step budget" (count == 8 && case limited of Left err -> A.errorCode err == "AGENT_MAX_STEPS"; _ -> False)

assert :: String -> Bool -> IO ()
assert label condition = unless condition (fail label)

json :: String -> Json
json = either error id . parseJson

validation :: String -> String -> [ValidationError]
validation schema value = either error id (validateSchema (json schema) (json value))

set :: String -> Json -> Json -> Json
set key value object = JObject ((key, value) : filter ((/= key) . fst) (asObject object))
