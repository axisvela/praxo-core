module Praxo.OpenAICompatible
    ( HttpRequest(..)
    , HttpResponse(..)
    , Transport(..)
    , OpenAITool(..)
    , OpenAIConfig(..)
    , buildRequest
    , parseResponse
    , generate
    ) where

import Praxo.Agent (AgentError(..), Message(..), Response(..), ToolCall(..))
import Praxo.Json (Json(..), asArray, asString, encodeJson, field, parseJson)

data HttpRequest = HttpRequest
    { httpMethod :: String
    , httpURL :: String
    , httpHeaders :: [(String, String)]
    , httpBody :: String
    } deriving (Eq, Show)

data HttpResponse = HttpResponse
    { httpStatus :: Int
    , httpResponseBody :: String
    } deriving (Eq, Show)

newtype Transport = Transport
    { sendTransport :: HttpRequest -> IO (Either AgentError HttpResponse)
    }

data OpenAITool = OpenAITool
    { openAIToolName :: String
    , openAIToolDescription :: String
    , openAIToolParameters :: Json
    } deriving (Eq, Show)

data OpenAIConfig = OpenAIConfig
    { openAIBaseURL :: String
    , openAIModel :: String
    , openAIKey :: Maybe String
    , openAIToolChoice :: Maybe String
    , openAITools :: [OpenAITool]
    , openAITransport :: Transport
    }

buildRequest :: OpenAIConfig -> [Message] -> Either AgentError HttpRequest
buildRequest config messages
    | null (openAIBaseURL config) = Left (AgentError "PROVIDER_HTTP" "provider base URL is required")
    | otherwise = do
        encoded <- mapM messageJson messages
        let toolValues = map toolJson (openAITools config)
            base =
                [ ("model", JString (openAIModel config))
                , ("messages", JArray encoded)
                ]
            withTools = if null toolValues then base else base ++ [("tools", JArray toolValues)]
            withChoice = case openAIToolChoice config of
                Nothing -> withTools
                Just choice -> withTools ++ [("tool_choice", JString choice)]
        case encodeJson (JObject withChoice) of
            Left detail -> Left (AgentError "PROVIDER_REQUEST" detail)
            Right text ->
                Right HttpRequest
                    { httpMethod = "POST"
                    , httpURL = trimSlash (openAIBaseURL config) ++ "/chat/completions"
                    , httpHeaders =
                        [ ("Content-Type", "application/json")
                        , ("Accept", "application/json")
                        ] ++ case openAIKey config of
                            Nothing -> []
                            Just key -> [("Authorization", "Bearer " ++ key)]
                    , httpBody = text
                    }
  where
    trimSlash = reverse . dropWhile (== '/') . reverse

parseResponse :: String -> Either AgentError Response
parseResponse text = do
    root <- case parseJson text of
        Left detail -> Left (AgentError "PROVIDER_RESPONSE" ("provider returned invalid JSON: " ++ detail))
        Right value -> Right value
    case asArray (field "choices" root) of
        [] -> Left (AgentError "PROVIDER_RESPONSE" "provider response has no choices")
        choice : _ -> do
            let message = field "message" choice
            calls <- mapM callFromJson (asArray (field "tool_calls" message))
            let usage = field "usage" root
            pure Response
                { responseContent = asString (field "content" message)
                , responseToolCalls = calls
                , inputTokens = jsonInteger (field "prompt_tokens" usage)
                , outputTokens = jsonInteger (field "completion_tokens" usage)
                }
  where
    callFromJson item = do
        let function = field "function" item
        arguments <- case field "arguments" function of
            JString raw | not (null raw) -> case parseJson raw of
                Left detail -> Left (AgentError "PROVIDER_RESPONSE" ("tool arguments are not valid JSON: " ++ detail))
                Right value@(JObject _) -> Right value
                Right _ -> Left (AgentError "PROVIDER_RESPONSE" "tool arguments must be an object")
            value@(JObject _) -> Right value
            _ -> Right (JObject [])
        pure ToolCall
            { toolCallId = asString (field "id" item)
            , toolCallName = asString (field "name" function)
            , toolCallArguments = arguments
            }

generate :: OpenAIConfig -> [Message] -> IO (Either AgentError Response)
generate config messages =
    case buildRequest config messages of
        Left errorValue -> pure (Left errorValue)
        Right httpRequest -> do
            result <- sendTransport (openAITransport config) httpRequest
            pure $ case result of
                Left errorValue -> Left errorValue
                Right response
                    | httpStatus response < 200 || httpStatus response >= 300 ->
                        Left (AgentError "PROVIDER_HTTP"
                            ("provider returned HTTP " ++ show (httpStatus response) ++ ": " ++ bounded (httpResponseBody response)))
                    | otherwise -> parseResponse (httpResponseBody response)

messageJson :: Message -> Either AgentError Json
messageJson message = do
    calls <- mapM callJson (messageToolCalls message)
    let base =
            [ ("role", JString (messageRole message))
            , ("content", JString (messageContent message))
            ]
        withCalls = if null calls then base else base ++ [("tool_calls", JArray calls)]
        withTool =
            if messageRole message == "tool" && messageToolCallId message /= ""
                then withCalls ++ [("tool_call_id", JString (messageToolCallId message))]
                else withCalls
    pure (JObject withTool)
  where
    callJson call = do
        arguments <- case encodeJson (toolCallArguments call) of
            Left detail -> Left (AgentError "PROVIDER_REQUEST" ("tool arguments: " ++ detail))
            Right text -> Right text
        pure (JObject
            [ ("id", JString (toolCallId call))
            , ("type", JString "function")
            , ("function", JObject
                [ ("name", JString (toolCallName call))
                , ("arguments", JString arguments)
                ])
            ])

toolJson :: OpenAITool -> Json
toolJson tool =
    JObject
        [ ("type", JString "function")
        , ("function", JObject
            [ ("name", JString (openAIToolName tool))
            , ("description", JString (openAIToolDescription tool))
            , ("parameters", parameters)
            ])
        ]
  where
    parameters = case openAIToolParameters tool of
        JNull -> JObject [("type", JString "object")]
        value -> value

jsonInteger :: Json -> Integer
jsonInteger (JNumber value) = truncate value
jsonInteger _ = 0

bounded :: String -> String
bounded text = if length text > 512 then take 512 text else text
