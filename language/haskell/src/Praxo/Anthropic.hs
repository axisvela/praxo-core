module Praxo.Anthropic
    ( AnthropicTool(..)
    , AnthropicConfig(..)
    , buildAnthropicRequest
    , parseAnthropicResponse
    , generateAnthropic
    ) where

import Data.List (intercalate)
import Praxo.Agent (AgentError(..), Message(..), Response(..), ToolCall(..))
import Praxo.Json (Json(..), asArray, asString, encodeJson, field, parseJson)
import Praxo.OpenAICompatible (HttpRequest(..), HttpResponse(..), Transport(..))

data AnthropicTool = AnthropicTool
    { anthropicToolName :: String
    , anthropicToolDescription :: String
    , anthropicToolParameters :: Json
    } deriving (Eq, Show)

data AnthropicConfig = AnthropicConfig
    { anthropicBaseURL :: String
    , anthropicModel :: String
    , anthropicKey :: Maybe String
    , anthropicVersion :: String
    , anthropicMaxTokens :: Integer
    , anthropicToolChoice :: Maybe String
    , anthropicTools :: [AnthropicTool]
    , anthropicTransport :: Transport
    }

buildAnthropicRequest :: AnthropicConfig -> [Message] -> Either AgentError HttpRequest
buildAnthropicRequest config messages
    | null (anthropicBaseURL config) = Left (AgentError "PROVIDER_HTTP" "provider base URL is required")
    | otherwise = do
        (system, encoded) <- messagesJson messages
        let toolValues = map toolJson (anthropicTools config)
            base =
                [ ("model", JString (anthropicModel config))
                , ("max_tokens", JNumber (fromIntegral (anthropicMaxTokens config)))
                , ("messages", JArray encoded)
                ]
            withSystem = if null system then base else base ++ [("system", JString (intercalate "\n\n" system))]
            withTools = if null toolValues then withSystem else withSystem ++ [("tools", JArray toolValues)]
            withChoice = case anthropicToolChoice config of
                Just "auto" -> withTools ++ [("tool_choice", choice "auto")]
                Just "required" -> withTools ++ [("tool_choice", choice "any")]
                Just "none" -> withTools ++ [("tool_choice", choice "none")]
                _ -> withTools
        case encodeJson (JObject withChoice) of
            Left detail -> Left (AgentError "PROVIDER_REQUEST" detail)
            Right text ->
                Right HttpRequest
                    { httpMethod = "POST"
                    , httpURL = trimSlash (anthropicBaseURL config) ++ "/v1/messages"
                    , httpHeaders =
                        [ ("Content-Type", "application/json")
                        , ("Accept", "application/json")
                        ] ++ case anthropicKey config of
                            Nothing -> []
                            Just key -> [("x-api-key", key), ("anthropic-version", anthropicVersion config)]
                    , httpBody = text
                    }
  where
    choice value = JObject [("type", JString value)]
    trimSlash = reverse . dropWhile (== '/') . reverse

messagesJson :: [Message] -> Either AgentError ([String], [Json])
messagesJson messages = go messages [] [] []
  where
    go [] system out pending = do
        flushed <- flush pending out
        pure (reverse system, reverse flushed)
    go (message : rest) system out pending
        | messageRole message == "system" =
            go rest (messageContent message : system) out pending
        | messageRole message == "tool" =
            go rest system out (pending ++ [toolResult message])
        | otherwise = do
            flushed <- flush pending out
            content <- messageContentJson message
            go rest system (if null content then flushed else JObject
                [("role", JString (messageRole message)), ("content", JArray content)] : flushed) []
    flush [] out = pure out
    flush pending out = pure (JObject [("role", JString "user"), ("content", JArray pending)] : out)

toolResult :: Message -> Json
toolResult message = JObject
    [ ("type", JString "tool_result")
    , ("tool_use_id", JString (messageToolCallId message))
    , ("content", JString (messageContent message))
    ]

messageContentJson :: Message -> Either AgentError [Json]
messageContentJson message = do
    calls <- mapM callJson (messageToolCalls message)
    let text = if null (messageContent message) then [] else [JObject [("type", JString "text"), ("text", JString (messageContent message))]]
    pure (text ++ calls)
  where
    callJson call =
        pure (JObject
            [ ("type", JString "tool_use")
            , ("id", JString (toolCallId call))
            , ("name", JString (toolCallName call))
            , ("input", toolCallArguments call)
            ])

toolJson :: AnthropicTool -> Json
toolJson tool = JObject
    [ ("name", JString (anthropicToolName tool))
    , ("description", JString (anthropicToolDescription tool))
    , ("input_schema", parameters)
    ]
  where
    parameters = case anthropicToolParameters tool of
        JNull -> JObject [("type", JString "object")]
        value -> value

parseAnthropicResponse :: String -> Either AgentError Response
parseAnthropicResponse text = do
    root <- parseJson text `orAgent` "PROVIDER_RESPONSE"
    if field "error" root /= JNull
        then Left (AgentError "PROVIDER_HTTP" "anthropic: provider error")
        else do
            allCalls <- mapM callFromJson (asArray (field "content" root))
            let calls = filter (\call -> not (null (toolCallName call))) allCalls
                content = concatMap blockText (asArray (field "content" root))
                usage = field "usage" root
            pure Response
                { responseContent = content
                , responseToolCalls = calls
                , inputTokens = jsonInteger (field "input_tokens" usage)
                , outputTokens = jsonInteger (field "output_tokens" usage)
                }
  where
    blockText block = if asString (field "type" block) == "text"
        then asString (field "text" block) else ""
    callFromJson block
        | asString (field "type" block) /= "tool_use" = Right emptyCall
        | otherwise = Right ToolCall
            { toolCallId = asString (field "id" block)
            , toolCallName = asString (field "name" block)
            , toolCallArguments = case field "input" block of
                value@(JObject _) -> value
                _ -> JObject []
            }
    emptyCall = ToolCall "" "" (JObject [])

generateAnthropic :: AnthropicConfig -> [Message] -> IO (Either AgentError Response)
generateAnthropic config messages =
    case buildAnthropicRequest config messages of
        Left errorValue -> pure (Left errorValue)
        Right httpRequest -> do
            result <- sendTransport (anthropicTransport config) httpRequest
            pure $ case result of
                Left errorValue -> Left errorValue
                Right response
                    | httpStatus response < 200 || httpStatus response >= 300 ->
                        Left (AgentError "PROVIDER_HTTP"
                            ("provider returned HTTP " ++ show (httpStatus response) ++ ": " ++ bounded (httpResponseBody response)))
                    | otherwise -> parseAnthropicResponse (httpResponseBody response)

orAgent :: Either String Json -> String -> Either AgentError Json
orAgent (Right value) _ = Right value
orAgent (Left detail) code = Left (AgentError code detail)

jsonInteger :: Json -> Integer
jsonInteger (JNumber value) = truncate value
jsonInteger _ = 0

bounded :: String -> String
bounded text = if length text > 512 then take 512 text else text
