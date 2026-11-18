module Main where

import Data.IORef
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json
import Praxo.Runtime (Event(..))
import qualified Praxo.Harmovela as H
import qualified Praxo.Mcp as M
import qualified Praxo.Otel as O

recordCall :: String -> String -> ToolCall
recordCall ident target =
    ToolCall ident "record" (JObject [("target", JString target)])

delegateCall :: String -> ToolCall
delegateCall ident =
    ToolCall ident "delegate" (JObject [("task", JString "record child")])

toolResponse :: ToolCall -> Response
toolResponse call = Response "" [call] 0 0

parentPolicy :: Action -> Bool
parentPolicy action
    | actionKind action == "model.generate" = True
    | actionKind action /= "tool.invoke" = False
    | actionToolName action == "record" =
        asString (field "target" (actionArguments action)) /= "blocked"
    | actionToolName action == "delegate" = True
    | otherwise = False

childPolicy :: Action -> Bool
childPolicy action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" = actionToolName action == "record"
    | otherwise = False

scriptedGenerate :: IORef [Response] -> String -> Maybe (IO ()) -> [Message] -> IO (Either AgentError Response)
scriptedGenerate steps final onCall _messages = do
    remaining <- readIORef steps
    case onCall of
        Just callback -> callback
        Nothing -> pure ()
    case remaining of
        step : rest -> writeIORef steps rest >> pure (Right step)
        [] -> pure (Right (Response final [] 0 0))

main :: IO ()
main = do
    effects <- newIORef ([] :: [String])
    otelEvents <- newIORef ([] :: [String])
    harmovelaEvents <- newIORef ([] :: [String])
    childCalls <- newIORef (0 :: Int)

    let transport = M.McpTransport $ \method params -> case method of
            "initialize" -> pure (Right (JObject [
                ("protocolVersion", JString "2024-11-05"),
                ("serverInfo", JObject [("name", JString "fake-mcp")])]))
            "tools/list" -> pure (Right (JObject [
                ("tools", JArray [JObject [
                    ("name", JString "record"),
                    ("description", JString "Record a target"),
                    ("inputSchema", JObject [
                        ("type", JString "object"),
                        ("properties", JObject [
                            ("target", JObject [("type", JString "string")])]),
                        ("required", JArray [JString "target"])])]])]))
            "tools/call" -> do
                let arguments = field "arguments" params
                    target = asString (field "target" arguments)
                modifyIORef' effects (++ [target])
                pure (Right (JObject [
                    ("content", JArray [JObject [
                        ("type", JString "text"),
                        ("text", JString ("recorded:" ++ target))]])]))
            _ -> pure (Right (JObject []))

    clientResult <- M.mcpClient transport "" ""
    client <- case clientResult of
        Left err -> fail (show err)
        Right value -> pure value
    tools <- M.mcpListTools client
    case tools of
        Left err -> fail (show err)
        Right items -> if length items /= 1 then fail "unexpected MCP tools" else pure ()

    let clock = pure (1794294000000000000 :: Integer)
        otel = O.newOtelSink "http://otel.local/v1/traces"
            (O.OtelTransport $ \request -> do
                let payload = either (const JNull) id (parseJson (O.otelBody request))
                    names =
                        [ asString (field "name" span)
                        | resource <- asArray (field "resourceSpans" payload)
                        , scope <- asArray (field "scopeSpans" resource)
                        , span <- asArray (field "spans" scope)
                        ]
                modifyIORef' otelEvents (++ names)
                pure (Right (O.OtelResponse 200 "")))
            clock
        harmovela = H.newHarmovelaSink "http://harmovela.local"
            (H.HarmovelaTransport $ \request -> do
                let payload = either (const JNull) id (parseJson (H.harmovelaBody request))
                modifyIORef' harmovelaEvents (++ [asString (field "type" payload)])
                pure (Right (H.HarmovelaResponse 202 "")))
            clock

    let emitEvent kind = do
            let event = Event kind "chain-session" (Just "run-chain") JNull
            otelResult <- O.emitOtelEvent otel event
            harmResult <- H.emitHarmovelaEvent harmovela event
            pure $ case (otelResult, harmResult) of
                (Left err, _) -> Left err
                (_, Left err) -> Left err
                _ -> Right ()

    let invokeTool call
            | toolCallName call == "record" =
                M.mcpCallTool client "record" (toolCallArguments call)
            | toolCallName call == "delegate" = do
                childSteps <- newIORef [toolResponse (recordCall "child-record" "child")]
                let childGenerate = scriptedGenerate childSteps "DONE"
                        (Just (modifyIORef' childCalls (+ 1)))
                    childOptions = (baseOptions childGenerate invokeTool emitEvent)
                        { maxSteps = 3
                        , policy = Just childPolicy
                        , allowedTools = ["record"]
                        , requirePolicy = True
                        , requireToolScope = True
                        }
                result <- runAgent childOptions [] "record child"
                pure $ case result of
                    Left err -> Left err
                    Right value -> Right (JObject [("output", JString (runOutput value))])
            | otherwise =
                pure (Left (AgentError "TOOL_NOT_FOUND" ("unknown tool " ++ toolCallName call)))

    parentSteps <- newIORef
        [ toolResponse (recordCall "parent-record" "parent")
        , toolResponse (delegateCall "parent-delegate")
        ]
    let parentGenerate = scriptedGenerate parentSteps "DONE" Nothing
        parentOptions = (baseOptions parentGenerate invokeTool emitEvent)
            { maxSteps = 4
            , policy = Just parentPolicy
            , allowedTools = ["record", "delegate"]
            , requirePolicy = True
            , requireToolScope = True
            }
    parent <- runAgent parentOptions [] "record parent, then delegate"
    parentOutput <- case parent of
        Left err -> fail (show err)
        Right value -> pure (runOutput value)

    deniedSteps <- newIORef [toolResponse (recordCall "denied-record" "edit-me")]
    let deniedGenerate = scriptedGenerate deniedSteps "DONE" Nothing
        deniedOptions = (baseOptions deniedGenerate invokeTool emitEvent)
            { maxSteps = 2
            , policy = Just parentPolicy
            , allowedTools = ["record"]
            , requirePolicy = True
            , requireToolScope = True
            , interruptOn = ["record"]
            , onInterruptDecision = Just $ \_interrupt ->
                pure (InterruptDecision interruptEdit
                    (Just (JObject [("target", JString "blocked")])) "" "")
            }
    denied <- runAgent deniedOptions [] "attempt a denied edit"
    let deniedError = case denied of
            Left err -> errorCode err
            Right _ -> ""

    M.mcpClose client
    recordedEffects <- readIORef effects
    spans <- readIORef otelEvents
    events <- readIORef harmovelaEvents
    calls <- readIORef childCalls
    let count name = length (filter (== name) recordedEffects)
    putStrLn ("output: " ++ parentOutput)
    putStrLn ("effects: parent=" ++ show (count "parent")
        ++ " child=" ++ show (count "child"))
    putStrLn ("child calls: " ++ show calls)
    putStrLn ("otel spans: " ++ show (length spans))
    putStrLn ("harmovela events: " ++ show (length events))
    putStrLn ("denied effects: " ++ show (count "blocked"))
    if parentOutput == "DONE"
        && count "parent" == 1
        && count "child" == 1
        && calls == 2
        && length spans >= 3
        && length events >= 3
        && count "blocked" == 0
        && not (null deniedError)
        then pure ()
        else do
            hPutStrLn stderr "representative chain failed"
            exitFailure

baseOptions :: ([Message] -> IO (Either AgentError Response))
    -> (ToolCall -> IO (Either AgentError Json))
    -> (String -> IO (Either AgentError ()))
    -> AgentOptions
baseOptions generateFn invokeFn emitFn = AgentOptions
    { generate = generateFn
    , invoke = invokeFn
    , emit = emitFn
    , maxSteps = 8
    , maxTokens = 0
    , policy = Nothing
    , allowedTools = []
    , requirePolicy = False
    , requireToolScope = False
    , runId = "run-chain"
    , sessionId = "chain-session"
    , interruptOn = []
    , onInterruptDecision = Nothing
    , onInterrupt = Nothing
    , beforeTool = Nothing
    }
