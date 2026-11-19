module Praxo.Anthropic
    ( AnthropicTool(..)
    , AnthropicConfig(..)
    , buildAnthropicRequest
    , parseAnthropicResponse
    , generateAnthropic
    , generateAnthropicStream
    ) where

import Control.Monad (foldM)
import Data.Char (isSpace)
import Data.List (dropWhileEnd, intercalate, stripPrefix)
import qualified Data.Map.Strict as Map
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
buildAnthropicRequest = buildAnthropicRequestWithStream False

buildAnthropicRequestWithStream :: Bool -> AnthropicConfig -> [Message] -> Either AgentError HttpRequest
buildAnthropicRequestWithStream stream config messages
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
            withStream = if stream then withChoice ++ [("stream", JBool True)] else withChoice
        case encodeJson (JObject withStream) of
            Left detail -> Left (AgentError "PROVIDER_REQUEST" detail)
            Right text ->
                Right HttpRequest
                    { httpMethod = "POST"
                    , httpURL = trimSlash (anthropicBaseURL config) ++ "/v1/messages"
                    , httpHeaders =
                        [ ("Content-Type", "application/json")
                        , ("Accept", if stream then "text/event-stream" else "application/json")
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

generateAnthropicStream :: AnthropicConfig -> [Message] -> (String -> IO ()) -> IO (Either AgentError Response)
generateAnthropicStream config messages onDelta =
    case buildAnthropicRequestWithStream True config messages of
        Left errorValue -> pure (Left errorValue)
        Right httpRequest -> do
            result <- sendTransport (anthropicTransport config) httpRequest
            case result of
                Left errorValue -> pure (Left errorValue)
                Right response
                    | httpStatus response < 200 || httpStatus response >= 300 ->
                        pure (Left (AgentError "PROVIDER_HTTP"
                            ("provider returned HTTP " ++ show (httpStatus response) ++ ": " ++ bounded (httpResponseBody response))))
                    | otherwise -> parseAnthropicSse (httpResponseBody response) onDelta

parseAnthropicSse :: String -> (String -> IO ()) -> IO (Either AgentError Response)
parseAnthropicSse body onDelta = go (lines body) "" Map.empty 0 0 Nothing False
  where
    go [] content calls inputTokens outputTokens finishReason done
        | done || maybe False (const True) finishReason = finish content calls inputTokens outputTokens
        | otherwise = pure (Left (AgentError "MODEL_STREAM" "stream ended before completion"))
    go (raw:rest) content calls inputTokens outputTokens finishReason done =
        case stripPrefix "data:" (trim raw) of
            Nothing -> go rest content calls inputTokens outputTokens finishReason done
            Just rawChunk ->
                let chunk = trim rawChunk
                in if null chunk
                    then go rest content calls inputTokens outputTokens finishReason done
                    else case parseJson chunk of
                        Left detail -> pure (Left (AgentError "MODEL_STREAM" ("invalid SSE packet: " ++ detail)))
                        Right event -> do
                            let kind = asString (field "type" event)
                            case kind of
                                "message_start" -> do
                                    let usage = field "usage" (field "message" event)
                                        inputTokens' = if field "input_tokens" usage == JNull
                                            then inputTokens else jsonInteger (field "input_tokens" usage)
                                    go rest content calls inputTokens' outputTokens finishReason done
                                "content_block_start" -> do
                                    let index = fromIntegral (jsonInteger (field "index" event)) :: Int
                                        block = field "content_block" event
                                        calls' = if asString (field "type" block) == "tool_use"
                                            then Map.insert index
                                                (asString (field "id" block), asString (field "name" block), "")
                                                calls
                                            else calls
                                    go rest content calls' inputTokens outputTokens finishReason done
                                "content_block_delta" -> do
                                    let index = fromIntegral (jsonInteger (field "index" event)) :: Int
                                        delta = field "delta" event
                                        deltaType = asString (field "type" delta)
                                    case deltaType of
                                        "text_delta" -> do
                                            let text = asString (field "text" delta)
                                            if null text
                                                then go rest content calls inputTokens outputTokens finishReason done
                                                else do
                                                    onDelta text
                                                    go rest (content ++ text) calls inputTokens outputTokens finishReason done
                                        "input_json_delta" -> do
                                            let partial = asString (field "partial_json" delta)
                                                calls' = Map.adjust
                                                    (\(identifier, name, rawArguments) ->
                                                        (identifier, name, rawArguments ++ partial))
                                                    index calls
                                            go rest content calls' inputTokens outputTokens finishReason done
                                        _ -> go rest content calls inputTokens outputTokens finishReason done
                                "message_delta" -> do
                                    let delta = field "delta" event
                                        reason = asString (field "stop_reason" delta)
                                        usage = field "usage" event
                                        outputTokens' = if field "output_tokens" usage == JNull
                                            then outputTokens else jsonInteger (field "output_tokens" usage)
                                        finishReason' = if null reason then finishReason else Just reason
                                    go rest content calls inputTokens outputTokens' finishReason' done
                                "message_stop" -> go rest content calls inputTokens outputTokens finishReason True
                                "error" -> pure (Left (AgentError "MODEL_STREAM" "provider stream error"))
                                _ -> go rest content calls inputTokens outputTokens finishReason done
    finish content calls inputTokens outputTokens =
        let built = foldl addCall (Right []) (Map.toAscList calls)
        in pure $ case built of
            Left errorValue -> Left errorValue
            Right toolCalls -> Right Response
                { responseContent = content
                , responseToolCalls = toolCalls
                , inputTokens = inputTokens
                , outputTokens = outputTokens
                }
      where
        addCall (Left errorValue) _ = Left errorValue
        addCall (Right acc) (_, (identifier, name, rawArguments))
            | null name = Right acc
            | otherwise = case if null rawArguments then Right (JObject []) else parseJson rawArguments of
                Left detail -> Left (AgentError "PROVIDER_JSON" ("tool arguments are not valid JSON: " ++ detail))
                Right value@(JObject _) -> Right (acc ++ [ToolCall identifier name value])
                Right _ -> Left (AgentError "PROVIDER_JSON" "tool arguments must be an object")

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace

orAgent :: Either String Json -> String -> Either AgentError Json
orAgent (Right value) _ = Right value
orAgent (Left detail) code = Left (AgentError code detail)

jsonInteger :: Json -> Integer
jsonInteger (JNumber value) = truncate value
jsonInteger _ = 0

bounded :: String -> String
bounded text = if length text > 512 then take 512 text else text
