module Main where

import Data.IORef
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json

recordCall :: String -> String -> ToolCall
recordCall ident target =
    ToolCall ident "record" (JObject [("target", JString target)])

toolResponse :: ToolCall -> Response
toolResponse call = Response "" [call] 0 0

parentPolicy :: Action -> Bool
parentPolicy action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" = actionToolName action == "delegate"
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
    , runId = "run-demo"
    , sessionId = "demo-session"
    , interruptOn = []
    , onInterruptDecision = Nothing
    , onInterrupt = Nothing
    , beforeTool = Nothing
    , onDelta = Nothing
    , generateStream = Nothing
    }

main :: IO ()
main = do
    effects <- newIORef ([] :: [String])
    childCalls <- newIORef (0 :: Int)

    let invokeTool call
            | toolCallName call == "record" = do
                let target = asString (field "target" (toolCallArguments call))
                modifyIORef' effects (++ [target])
                pure (Right (JString ("recorded:" ++ target)))
            | toolCallName call == "delegate" = do
                childSteps <- newIORef [toolResponse (recordCall "child-record" "child")]
                let childGenerate = scriptedGenerate childSteps "child done"
                        (Just (modifyIORef' childCalls (+ 1)))
                    childOptions = (baseOptions childGenerate invokeTool)
                        { maxSteps = 3
                        , policy = Just childPolicy
                        , allowedTools = ["record"]
                        , requirePolicy = True
                        , requireToolScope = True
                        }
                result <- runAgent childOptions [] "record child"
                pure $ case result of
                    Left err -> Left err
                    Right value -> Right (JString (runOutput value))
            | otherwise =
                pure (Left (AgentError "TOOL_NOT_FOUND" ("unknown tool " ++ toolCallName call)))

    parentSteps <- newIORef [toolResponse (ToolCall "parent-delegate" "delegate"
        (JObject [("task", JString "record child")]))]
    let parentGenerate = scriptedGenerate parentSteps "parent done" Nothing
        parentOptions = (baseOptions parentGenerate invokeTool)
            { allowedTools = ["delegate"]
            , policy = Just parentPolicy
            , requirePolicy = True
            , requireToolScope = True
            }
    parent <- runAgent parentOptions [] "delegate"
    parentOutput <- case parent of
        Left err -> fail (show err)
        Right value -> pure (runOutput value)
    putStrLn "delegation: child recorded; parent scope enforced"

    directSteps <- newIORef [toolResponse (recordCall "direct-record" "child")]
    let directGenerate = scriptedGenerate directSteps "parent done" Nothing
        directOptions = (baseOptions directGenerate invokeTool)
            { allowedTools = ["delegate"]
            , policy = Just parentPolicy
            , requirePolicy = True
            , requireToolScope = True
            }
    direct <- runAgent directOptions [] "record directly"
    let denied = case direct of
            Left err -> errorCode err `elem` ["AGENT_POLICY_DENIED", "AGENT_TOOL_NOT_ALLOWED"]
            Right _ -> False
    putStrLn "deny: parent record blocked; child effect unchanged"
    recorded <- readIORef effects
    calls <- readIORef childCalls
    if parentOutput == "parent done"
        && length (filter (== "child") recorded) == 1
        && calls == 2
        && denied
        then pure ()
        else do
            hPutStrLn stderr "delegation example failed"
            exitFailure
