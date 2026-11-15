module Main where

import Data.Time (defaultTimeLocale, formatTime, getCurrentTime,
                  getCurrentTimeZone, utcToLocalTime)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Praxo.Agent
import Praxo.Json
import Praxo.OpenAICompatible hiding (generate)
import qualified Praxo.OpenAICompatible as OpenAI

getTimeText :: String -> IO String
getTimeText zone = do
    now <- getCurrentTime
    if zone == "local"
        then do
            local <- getCurrentTimeZone
            pure (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%z" (utcToLocalTime local now))
        else pure (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" now)

invokeTool :: ToolCall -> IO (Either AgentError Json)
invokeTool call
    | toolCallName call == "get_time" = do
        let zone = asString (field "zone" (toolCallArguments call))
        Right . JString <$> getTimeText (if null zone then "utc" else zone)
    | otherwise = pure (Left (AgentError "TOOL_NOT_FOUND"
        ("tool " ++ toolCallName call ++ " is not available")))

allowKinds :: Action -> Bool
allowKinds action = actionKind action == "model.generate" || actionKind action == "tool.invoke"

unconfiguredTransport :: Transport
unconfiguredTransport = Transport $ \_ ->
    pure (Left (AgentError "PROVIDER_HTTP"
        "no HTTP transport configured; supply a Transport backed by an HTTP client"))

getTimeSchema :: Json
getTimeSchema = JObject
    [ ("type", JString "object")
    , ("properties", JObject
        [ ("zone", JObject
            [ ("type", JString "string")
            , ("enum", JArray [JString "utc", JString "local"])
            , ("description", JString "utc or local; defaults to utc")
            ])
        ])
    ]

envOr :: String -> String -> IO String
envOr name fallback = do
    value <- lookupEnv name
    pure (case value of
        Just text | not (null text) -> text
        _ -> fallback)

main :: IO ()
main = do
    baseUrl <- envOr "PRAXO_BASE_URL" "http://localhost:11434/v1"
    modelName <- envOr "PRAXO_MODEL" "qwen3.5:4b"
    apiKeyValue <- lookupEnv "PRAXO_API_KEY"
    prompt <- envOr "PRAXO_PROMPT"
        "What time is it? Use get_time with zone set to utc and reply with the time."
    let apiKey = case apiKeyValue of
            Just key | not (null key) -> Just key
            _ -> Nothing
        config = OpenAIConfig
            { openAIBaseURL = baseUrl
            , openAIModel = modelName
            , openAIKey = apiKey
            , openAIToolChoice = Just "auto"
            , openAITools =
                [ OpenAITool
                    "get_time"
                    "Return the current time in ISO 8601 format for the requested zone."
                    getTimeSchema
                ]
            , openAITransport = unconfiguredTransport
            }
        options = AgentOptions
            { generate = OpenAI.generate config
            , invoke = invokeTool
            , emit = \_ -> pure (Right ())
            , maxSteps = 4
            , maxTokens = 0
            , policy = Just allowKinds
            , allowedTools = ["get_time"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-live"
            , sessionId = "session-live"
            , interruptOn = []
            , onInterruptDecision = Nothing
            , onInterrupt = Nothing
            , beforeTool = Nothing
            }
    result <- runAgent options [] prompt
    case result of
        Right value -> putStrLn (runOutput value)
        Left errorValue -> do
            hPutStrLn stderr ("live model run failed: " ++ errorMessage errorValue ++ "\n\n"
                ++ "Check PRAXO_BASE_URL (" ++ baseUrl ++ "), PRAXO_MODEL ("
                ++ modelName ++ "), and PRAXO_API_KEY")
            exitFailure
