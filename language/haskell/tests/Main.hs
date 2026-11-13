module Main (main) where

import Control.Monad (forM_, unless)
import Data.Either (isLeft)
import Data.List (isInfixOf)
import Data.Ratio ((%))
import Data.IORef
import qualified Praxo.Agent as A
import Praxo.Json
import Praxo.JsonSchema
import Praxo.Middleware
import qualified Praxo.OpenAICompatible as O
import qualified Praxo.Anthropic as An
import qualified Praxo.Gemini as G
import qualified Praxo.Harmovela as H
import qualified Praxo.Mcp as M
import qualified Praxo.Otel as Ot
import qualified Praxo.Retriever as R
import qualified Praxo.Delegation as D
import Praxo.Pattern
import Praxo.Plugin
import Praxo.Runtime
import Praxo.ToolCall
import Praxo.Wire

main :: IO ()
main = do
    agentTests
    runtimeTests
    middlewareTests
    adapterTests
    providerTests
    harmovelaTests
    mcpTests
    seamTests
    assert "contract version" (specVersion == "0.2.0" && sdkVersion == "0.5.0")
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
    putStrLn "Haskell Core regression tests passed"

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

runtimeTests :: IO ()
runtimeTests = do
    let (store1, _) = memoryPut newMemoryStore "s1" (MemoryRecord "m1" "event" "Alpha" "2026-01-01")
        (store2, _) = memoryPut store1 "s1" (MemoryRecord "m2" "event" "beta" "2026-01-02")
        (store3, _) = memoryPut store2 "s1" (MemoryRecord "m3" "decision" "ALPHABET" "2026-01-03")
    assert "memory ordering" (map recordId (memorySearch store3 "s1" "alpha" 10) == ["m3", "m1"])
    assert "memory limit" (map recordId (memorySearch store3 "s1" "alpha" 1) == ["m3"])
    assert "memory isolation" (null (memorySearch store3 "s2" "alpha" 10))
    let events = [Event "a" "s1" Nothing JNull, Event "b" "s1" Nothing JNull]
        filtered = foldl emitSink (filterSink newSink ["b"]) events
        multi = foldl emitSink (multiSink [newSink, newSink]) events
    assert "event filter" (sinkKinds filtered == ["b"])
    assert "event multi" (sinkKindLists multi == [["a", "b"], ["a", "b"]])
    assert "stream kinds" (streamKinds == ["values", "updates", "messages", "tasks", "debug", "checkpoint"])
    let allow = either error id (registerCheckpoint newCheckpoint "spec.payload")
    case checkpointMarshal allow "spec.payload" (json "{\"value\":\"x\"}") of
        Left detail -> fail detail
        Right data' -> case checkpointUnmarshal allow data' of
            Left detail -> fail detail
            Right decoded -> assert "checkpoint roundtrip" (equalJson decoded (json "{\"value\":\"x\"}"))
    assert "checkpoint allowlist" (checkpointMarshal allow "missing" JNull == Left "CHECKPOINT_TYPE_NOT_ALLOWED")
    let checker = either error id (pathChecker [PathGrant "allowed" "read"])
    assert "policy traversal" (not (pathAllowed checker "../allowed/secret" "read"))
    assert "policy inside" (pathAllowed checker "allowed/sub/../secret" "read")
    assert "policy parent segments" (normalizePath "../../a/../b" == "../../b")
    let messages = [ContextMessage "system" "sys" [] [] Nothing, ContextMessage "user" "message 0" [] [] Nothing, ContextMessage "user" "message 1" [] [] Nothing]
    assert "context estimate" (estimateTokens messages == 16)
    assert "context disabled" (let (output, ok) = compactContext (ContextBudget 0 0) messages in ok && length output == 3)

middlewareTests :: IO ()
middlewareTests = do
    assert "pii email" (piiRedact "email a@b.com" == "email [REDACTED:email]")
    assert "pii ssn" (piiRedact "ssn 123-45-6789" == "ssn [REDACTED:ssn]")
    assert "pii card" (piiRedact "card 4111 1111 1111 1111" == "card [REDACTED:credit_card]")
    assert "pii phone" (piiRedact "call 415-555-2671" == "call [REDACTED:phone]")
    assert "pii boundary" (piiRedact "version 1.2.3" == "version 1.2.3")
    let schema = json "{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}"
        repaired = structuredOutput schema 1 (Just (\_ -> Right "{\"name\":\"fixed\"}"))
        failing = structuredOutput schema 0 Nothing
    assert "structured repair" (applyStructured repaired "bad" == Right "{\"name\":\"fixed\"}")
    assert "structured failure" (applyStructured failing "bad" == Left "AGENT_STRUCTURED_OUTPUT")
    assert "tool limit" (case callLimitTool (callLimit 0 1) >>= callLimitTool of Left code -> code == "AGENT_TOOL_CALL_LIMIT"; _ -> False)
    assert "model limit" (case callLimitModel (callLimit 1 0) >>= callLimitModel of Left code -> code == "AGENT_MODEL_CALL_LIMIT"; _ -> False)
    assert "tool selection" (selectTools (toolSelection ["echo"]) ["echo", "other"] == ["echo"])
    assert "tool selection reject" (checkToolSelected (toolSelection []) "echo" == Left "AGENT_TOOL_NOT_SELECTED")
    assert "fallback" (fallbackEither (Left "MODEL_ERROR" :: Either String String) (Right "ok") == Right "ok")

adapterTests :: IO ()
adapterTests = do
    captured <- newIORef Nothing
    let responseBody = "{\"choices\":[{\"message\":{\"content\":\"done\",\"tool_calls\":[{\"id\":\"call-1\",\"type\":\"function\",\"function\":{\"name\":\"echo\",\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]},\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2}}"
        transport request = do
            writeIORef captured (Just request)
            pure (Right (O.HttpResponse 200 responseBody))
        config = O.OpenAIConfig
            { O.openAIBaseURL = "https://api.example.com/v1/"
            , O.openAIModel = "test-model"
            , O.openAIKey = Just "secret"
            , O.openAIToolChoice = Just "auto"
            , O.openAITools = [O.OpenAITool "echo" "Echo" (JObject [("type", JString "object")])]
            , O.openAITransport = O.Transport transport
            }
        messages = [A.Message "user" "hi" [] "", A.Message "tool" "{}" [] "call-1"]
    result <- O.generate config messages
    case result of
        Left err -> fail ("openai adapter: " ++ A.errorMessage err)
        Right response -> do
            assert "openai content" (A.responseContent response == "done")
            assert "openai usage" (A.inputTokens response == 3 && A.outputTokens response == 2)
            case A.responseToolCalls response of
                [call] -> do
                    assert "openai call id" (A.toolCallId call == "call-1")
                    assert "openai call name" (A.toolCallName call == "echo")
                    assert "openai call arguments" (A.toolCallArguments call == JObject [("text", JString "hi")])
                _ -> fail "openai call"
    request <- readIORef captured
    case request of
        Nothing -> fail "openai transport not called"
        Just http -> do
            assert "openai method" (O.httpMethod http == "POST")
            assert "openai url" (O.httpURL http == "https://api.example.com/v1/chat/completions")
            assert "openai auth" (lookup "Authorization" (O.httpHeaders http) == Just "Bearer secret")
            let payload = json (O.httpBody http)
            assert "openai model" (equalJson (field "model" payload) (JString "test-model"))
            assert "openai tool choice" (equalJson (field "tool_choice" payload) (JString "auto"))
            let payloadMessages = asArray (field "messages" payload)
            assert "openai messages" (length payloadMessages == 2 && equalJson (field "tool_call_id" (payloadMessages !! 1)) (JString "call-1"))
            let payloadTools = asArray (field "tools" payload)
            assert "openai tools" (length payloadTools == 1 && equalJson (field "name" (field "function" (head payloadTools))) (JString "echo"))
    let failing = O.Transport (\_ -> pure (Right (O.HttpResponse 503 "down")))
    failed <- O.generate (config { O.openAITransport = failing }) messages
    assert "openai provider error" (case failed of Left err -> A.errorCode err == "PROVIDER_HTTP"; _ -> False)
    let missing = config
            { O.openAIBaseURL = ""
            , O.openAITransport = O.Transport (\_ -> fail "transport called for missing base URL")
            }
    missingResult <- O.generate missing messages
    assert "openai missing base url" (case missingResult of Left err -> A.errorCode err == "PROVIDER_HTTP"; _ -> False)
    let invalid = O.Transport (\_ -> pure (Right (O.HttpResponse 200 "{\"choices\":[{\"message\":{\"tool_calls\":[{\"id\":\"c\",\"function\":{\"name\":\"x\",\"arguments\":\"{bad\"}}]}}]}")))
    invalidResult <- O.generate (config { O.openAITransport = invalid }) [A.Message "user" "hi" [] ""]
    assert "openai invalid arguments" (case invalidResult of Left err -> A.errorCode err == "PROVIDER_RESPONSE"; _ -> False)

providerTests :: IO ()
providerTests = do
    capturedAnthropic <- newIORef Nothing
    let anthropicTransport = O.Transport (\request -> do
            writeIORef capturedAnthropic (Just request)
            pure (Right (O.HttpResponse 200 "{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}],\"stop_reason\":\"end_turn\",\"usage\":{\"input_tokens\":3,\"output_tokens\":4,\"cache_read_input_tokens\":2}}")))
        anthropicConfig = An.AnthropicConfig
            { An.anthropicBaseURL = "https://api.anthropic.com"
            , An.anthropicModel = "claude-test"
            , An.anthropicKey = Just "ak"
            , An.anthropicVersion = "2023-06-01"
            , An.anthropicMaxTokens = 1024
            , An.anthropicToolChoice = Just "auto"
            , An.anthropicTools = [An.AnthropicTool "echo" "Echo" (JObject [("type", JString "object")])]
            , An.anthropicTransport = anthropicTransport
            }
        messages = [A.Message "system" "be brief" [] "", A.Message "user" "hi" [] ""]
    anthropicResult <- An.generateAnthropic anthropicConfig messages
    case anthropicResult of
        Left err -> fail ("anthropic adapter: " ++ A.errorMessage err)
        Right response -> do
            assert "anthropic content" (A.responseContent response == "hello")
            assert "anthropic usage" (A.inputTokens response == 3 && A.outputTokens response == 4)
            case A.responseToolCalls response of
                [call] -> do
                    assert "anthropic call id" (A.toolCallId call == "tool-1")
                    assert "anthropic call name" (A.toolCallName call == "echo")
                    assert "anthropic arguments" (A.toolCallArguments call == JObject [("text", JString "hi")])
                _ -> fail "anthropic call"
    request <- readIORef capturedAnthropic
    case request of
        Nothing -> fail "anthropic transport not called"
        Just http -> do
            assert "anthropic url" (O.httpURL http == "https://api.anthropic.com/v1/messages")
            assert "anthropic key" (lookup "x-api-key" (O.httpHeaders http) == Just "ak")
            let payload = json (O.httpBody http)
            assert "anthropic model" (field "model" payload == JString "claude-test")
            assert "anthropic system" (field "system" payload == JString "be brief")
            assert "anthropic tools" (length (asArray (field "tools" payload)) == 1)

    capturedGemini <- newIORef Nothing
    let geminiTransport = O.Transport (\request -> do
            writeIORef capturedGemini (Just request)
            pure (Right (O.HttpResponse 200 "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":4}}")))
        geminiConfig = G.GeminiConfig
            { G.geminiBaseURL = "https://generativelanguage.googleapis.com"
            , G.geminiModel = "gemini-test"
            , G.geminiKey = Just "gk"
            , G.geminiMaxOutputTokens = 0
            , G.geminiToolChoice = Just "auto"
            , G.geminiTools = [G.GeminiTool "echo" "Echo" (JObject [("type", JString "object")])]
            , G.geminiTransport = geminiTransport
            }
    geminiResult <- G.generateGemini geminiConfig messages
    case geminiResult of
        Left err -> fail ("gemini adapter: " ++ A.errorMessage err)
        Right response -> do
            assert "gemini content" (A.responseContent response == "hello")
            assert "gemini usage" (A.inputTokens response == 3 && A.outputTokens response == 4)
            case A.responseToolCalls response of
                [call] -> assert "gemini call name" (A.toolCallName call == "echo")
                _ -> fail "gemini call"
    geminiRequest <- readIORef capturedGemini
    case geminiRequest of
        Nothing -> fail "gemini transport not called"
        Just http -> do
            assert "gemini url" (":generateContent" `isInfixOf` O.httpURL http)
            assert "gemini key" (lookup "x-goog-api-key" (O.httpHeaders http) == Just "gk")
            let payload = json (O.httpBody http)
            assert "gemini system" (length (asArray (field "parts" (field "system_instruction" payload))) == 1)
            assert "gemini tools" (length (asArray (field "functionDeclarations" (head (asArray (field "tools" payload))))) == 1)

harmovelaTests :: IO ()
harmovelaTests = do
    captured <- newIORef ([] :: [H.HarmovelaRequest])
    let transport = H.HarmovelaTransport (\request -> do
            modifyIORef' captured (++ [request])
            pure (Right (H.HarmovelaResponse 201 "")))
        sink = H.newHarmovelaSink "http://harmovela.test/aep/api/" transport (pure 1794294000000000000)
        event = Event "tool.call" "s1" (Just "run-123") (JObject [("name", JString "echo")])
    result <- H.emitHarmovelaEvent sink event
    assert "harmovela success" (result == Right ())
    requests <- readIORef captured
    case requests of
        [request] -> do
            assert "harmovela method" (H.harmovelaMethod request == "POST")
            assert "harmovela path" (H.harmovelaURL request == "http://harmovela.test/aep/api/events")
            assert "harmovela content type" (lookup "content-type" (H.harmovelaHeaders request) == Just "application/json")
            let envelope = json (H.harmovelaBody request)
            assert "harmovela spec" (field "spec_version" envelope == JString "0.2")
            assert "harmovela id" (field "id" envelope == JString "run-123-1794294000000000000")
            assert "harmovela type" (field "type" envelope == JString "tool.call")
            assert "harmovela source" (field "source" envelope == JString "praxo-core")
            assert "harmovela created at" (field "created_at" envelope == JString "2026-11-10T07:00:00.000000000Z")
            assert "harmovela payload" (equalJson (field "payload" envelope)
                (json "{\"name\":\"echo\",\"session_id\":\"s1\",\"run_id\":\"run-123\"}"))
        _ -> fail "harmovela request count"
    customCaptured <- newIORef ([] :: [H.HarmovelaRequest])
    let customTransport = H.HarmovelaTransport (\request -> do
            modifyIORef' customCaptured (++ [request])
            pure (Right (H.HarmovelaResponse 204 "")))
        custom = (H.newHarmovelaSink "http://harmovela.test" customTransport (pure 1794294000000000000))
            { H.harmovelaSource = "custom", H.harmovelaSpecVersion = "0.3" }
        mergedEvent = Event "tool.call" "s1" Nothing
            (JObject [("name", JString "echo"), ("session_id", JString "event-side"), ("run_id", JString "old")])
    customResult <- H.emitHarmovelaEvent custom mergedEvent
    assert "harmovela custom success" (customResult == Right ())
    customRequests <- readIORef customCaptured
    case customRequests of
        [request] -> do
            let envelope = json (H.harmovelaBody request)
            assert "harmovela custom source" (field "source" envelope == JString "custom")
            assert "harmovela custom spec" (field "spec_version" envelope == JString "0.3")
            assert "harmovela session id prefix" (take 3 (asString (field "id" envelope)) == "s1-")
            assert "harmovela merged payload" (equalJson (field "payload" envelope)
                (json "{\"name\":\"echo\",\"session_id\":\"s1\",\"run_id\":\"old\"}"))
        _ -> fail "harmovela custom request count"
    forM_ [200, 201, 204, 299] $ \status -> do
        let accepted = H.newHarmovelaSink "http://harmovela.test"
                (H.HarmovelaTransport (\_ -> pure (Right (H.HarmovelaResponse status ""))))
                (pure 1)
        acceptedResult <- H.emitHarmovelaEvent accepted event
        assert ("harmovela accepted status " ++ show status) (acceptedResult == Right ())
    let failing = H.newHarmovelaSink "http://harmovela.test"
            (H.HarmovelaTransport (\_ -> pure (Right (H.HarmovelaResponse 503 (concat (replicate 100 "service down "))))))
            (pure 1)
    failed <- H.emitHarmovelaEvent failing event
    case failed of
        Left err -> do
            assert "harmovela error code" (A.errorCode err == "HARMOVELA_HTTP")
            assert "harmovela error status" ("503" `isInfixOf` A.errorMessage err)
            assert "harmovela error body" ("service down" `isInfixOf` A.errorMessage err)
            assert "harmovela error bounded" (length (A.errorMessage err) <= 600)
        Right () -> fail "harmovela expected non-2xx error"
    let missing = H.newHarmovelaSink "" (H.HarmovelaTransport (\_ -> fail "harmovela transport called for missing base URL")) (pure 1)
    missingResult <- H.emitHarmovelaEvent missing event
    assert "harmovela missing base url" (case missingResult of Left err -> A.errorCode err == "HARMOVELA_URL"; _ -> False)

mcpTests :: IO ()
mcpTests = do
    let transport = M.McpTransport (\method params -> case method of
            "initialize" -> pure (Right (json "{\"protocolVersion\":\"2024-11-05\",\"serverInfo\":{\"name\":\"fake\"}}"))
            "tools/list" -> case field "cursor" params of
                JString "c1" -> pure (Right (json "{\"tools\":[{\"name\":\"two\"}]}"))
                _ -> pure (Right (json "{\"tools\":[{\"name\":\"echo\",\"inputSchema\":{\"type\":\"object\"}}],\"nextCursor\":\"c1\"}"))
            "tools/call" -> pure (Right (json "{\"content\":[{\"type\":\"text\",\"text\":\"ok\"}]}"))
            _ -> pure (Right (JObject [])))
    clientResult <- M.mcpClient transport "" ""
    case clientResult of
        Left err -> fail (A.errorMessage err)
        Right client -> do
            assert "mcp default client version" (M.mcpClientVersion client == "0.4.0")
            assert "mcp negotiated protocol" (M.mcpProtocolVersion client == "2024-11-05")
            tools <- M.mcpListTools client
            case tools of
                Left err -> fail (A.errorMessage err)
                Right items -> do
                    assert "mcp pagination count" (length items == 2)
                    assert "mcp tool order" (map (asString . field "name") items == ["echo", "two"])
            value <- M.mcpCallTool client "echo" (JObject [])
            assert "mcp text call" (value == Right (JString "ok"))
            M.mcpClose client
            closed <- readIORef (M.mcpClosed client)
            assert "mcp closed" closed
    let duplicateTransport = M.McpTransport (\method _ -> case method of
            "initialize" -> pure (Right (json "{\"protocolVersion\":\"2024-11-05\"}"))
            "tools/list" -> pure (Right (json "{\"tools\":[{\"name\":\"echo\"},{\"name\":\"echo\"}]}"))
            _ -> pure (Right (JObject [])))
    duplicateResult <- M.mcpClient duplicateTransport "" ""
    case duplicateResult of
        Left err -> fail (A.errorMessage err)
        Right duplicateClient -> do
            duplicateTools <- M.mcpListTools duplicateClient
            assert "mcp duplicate tool error" (case duplicateTools of
                Left err -> A.errorCode err == "MCP_DUPLICATE_TOOL"
                Right _ -> False)
    let cursorTransport = M.McpTransport (\method _ -> case method of
            "initialize" -> pure (Right (json "{\"protocolVersion\":\"2024-11-05\"}"))
            "tools/list" -> pure (Right (json "{\"tools\":[],\"nextCursor\":\"c1\"}"))
            _ -> pure (Right (JObject [])))
    cursorResult <- M.mcpClient cursorTransport "" ""
    case cursorResult of
        Left err -> fail (A.errorMessage err)
        Right cursorClient -> do
            paginated <- M.mcpListTools cursorClient
            assert "mcp repeated cursor error" (case paginated of
                Left err -> A.errorCode err == "MCP_PAGINATION"
                Right _ -> False)
    let failingTransport = M.McpTransport (\method _ -> case method of
            "initialize" -> pure (Right (json "{\"protocolVersion\":\"2024-11-05\"}"))
            "tools/call" -> pure (Right (json "{\"isError\":true}"))
            _ -> pure (Right (JObject [])))
    failingResult <- M.mcpClient failingTransport "" ""
    case failingResult of
        Left err -> fail (A.errorMessage err)
        Right failingClient -> do
            called <- M.mcpCallTool failingClient "echo" (JObject [])
            assert "mcp tool error" (case called of
                Left err -> A.errorCode err == "MCP_TOOL_ERROR"
                Right _ -> False)

seamTests :: IO ()
seamTests = do
    calls <- newIORef ([] :: [Ot.OtelRequest])
    let transport = Ot.OtelTransport (\request -> do
            modifyIORef' calls (++ [request])
            pure (Right (Ot.OtelResponse 200 "")))
        clock = pure 1794294000000000000
        sink = (Ot.newOtelSink "http://otel.test/v1/traces" transport clock)
            { Ot.otelAllowedDataKeys = ["name"] }
        event = Event "tool.call" "s1" (Just "run-123")
            (JObject [("name", JString "echo"), ("secret", JString "hidden")])
    emitted <- Ot.emitOtelEvent sink event
    assert "otel emit" (emitted == Right ())
    requests <- readIORef calls
    case requests of
        [request] -> do
            assert "otel url" (Ot.otelURL request == "http://otel.test/v1/traces")
            let payload = either error id (parseJson (Ot.otelBody request))
                resourceSpans = asArray (field "resourceSpans" payload)
            case resourceSpans of
                [resourceSpan] -> do
                    let scopeSpan = head (asArray (field "scopeSpans" resourceSpan))
                        spanValue = head (asArray (field "spans" scopeSpan))
                    assert "otel span name" (asString (field "name" spanValue) == "praxo.tool.call")
                    assert "otel trace id" (length (asString (field "traceId" spanValue)) == 32)
                    assert "otel span id" (length (asString (field "spanId" spanValue)) == 16)
                    let attributes = asArray (field "attributes" spanValue)
                        attributeValue key =
                            [ asString (field "stringValue" (field "value" item))
                            | item <- attributes
                            , asString (field "key" item) == key ]
                    assert "otel allowed data" (attributeValue "praxo.event.data.name" == ["echo"])
                    assert "otel data excluded" (null (attributeValue "praxo.event.data.secret"))
                _ -> fail "otel resource span count"
        _ -> fail "otel request count"
    let failing = (Ot.newOtelSink "http://otel.test/v1/traces"
            (Ot.OtelTransport (\_ -> pure (Right (Ot.OtelResponse 503 "down"))))
            clock)
    failed <- Ot.emitOtelEvent failing event
    assert "otel error" (case failed of
        Left err -> A.errorCode err == "OTEL_HTTP"
        Right () -> False)

    let retriever query limit = pure (Right
            [R.Document "doc-1" (query ++ ":" ++ show limit) [] 0.5])
    documents <- R.retrieveDocuments retriever "hello" 3
    assert "retriever" (case documents of
        Right [document] -> R.documentContent document == "hello:3"
            && R.documentScore document == 0.5
        _ -> False)

    let request = D.SubagentRequest "parent" "child" "do" "fork"
        runner _ = pure (Right (D.SubagentResult "" "" "done"))
    completed <- D.subagentRun runner request
    assert "delegation completed" (case completed of
        Right task -> D.subagentStatus task == "completed"
            && D.subagentTaskOutput task == "done"
            && D.subagentTaskMode task == "fork"
        Left _ -> False)
    let failingRunner _ = pure (Left (A.AgentError "TEST" "boom"))
    failedTask <- D.subagentRun failingRunner request
    assert "delegation failed" (case failedTask of
        Right task -> D.subagentStatus task == "failed"
            && "boom" `isInfixOf` D.subagentTaskError task
        Left _ -> False)
    invalid <- D.subagentRun runner (D.SubagentRequest "" "child" "do" "isolated")
    assert "delegation invalid" (case invalid of
        Left err -> A.errorCode err == "SUBAGENT_INVALID"
        Right _ -> False)

assert :: String -> Bool -> IO ()
assert label condition = unless condition (fail label)

json :: String -> Json
json = either error id . parseJson

validation :: String -> String -> [ValidationError]
validation schema value = either error id (validateSchema (json schema) (json value))

set :: String -> Json -> Json -> Json
set key value object = JObject ((key, value) : filter ((/= key) . fst) (asObject object))
