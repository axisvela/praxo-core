module Praxo.OpenAICompatible
    ( HttpRequest(..)
    , HttpResponse(..)
    , Transport(..)
    , OpenAITool(..)
    , OpenAIConfig(..)
    , buildRequest
    , parseResponse
    , generate
    , generateStream
    ) where

import Control.Monad (foldM)
import Data.Char (isSpace)
import Data.List (dropWhileEnd, stripPrefix)
import qualified Data.Map.Strict as Map

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
buildRequest = buildRequestWithStream False

buildRequestWithStream :: Bool -> OpenAIConfig -> [Message] -> Either AgentError HttpRequest
buildRequestWithStream stream config messages
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
            withStream = if stream then withChoice ++ [("stream", JBool True)] else withChoice
        case encodeJson (JObject withStream) of
            Left detail -> Left (AgentError "PROVIDER_REQUEST" detail)
            Right text ->
                Right HttpRequest
                    { httpMethod = "POST"
                    , httpURL = trimSlash (openAIBaseURL config) ++ "/chat/completions"
                    , httpHeaders =
                        [ ("Content-Type", "application/json")
                        , ("Accept", if stream then "text/event-stream" else "application/json")
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

generateStream :: OpenAIConfig -> [Message] -> (String -> IO ()) -> IO (Either AgentError Response)
generateStream config messages onDelta =
    case buildRequestWithStream True config messages of
        Left errorValue -> pure (Left errorValue)
        Right httpRequest -> do
            result <- sendTransport (openAITransport config) httpRequest
            case result of
                Left errorValue -> pure (Left errorValue)
                Right response
                    | httpStatus response < 200 || httpStatus response >= 300 ->
                        pure (Left (AgentError "PROVIDER_HTTP"
                            ("provider returned HTTP " ++ show (httpStatus response) ++ ": " ++ bounded (httpResponseBody response))))
                    | otherwise -> parseSse (httpResponseBody response) onDelta

parseSse :: String -> (String -> IO ()) -> IO (Either AgentError Response)
parseSse body onDelta = go (lines body) "" Map.empty 0 0 Nothing False
  where
    go [] content calls inputTokens outputTokens finishReason done
        | done = finish content calls inputTokens outputTokens finishReason
        | otherwise = pure (Left (AgentError "MODEL_STREAM" "stream ended before completion"))
    go (raw:rest) content calls inputTokens outputTokens finishReason done =
        case stripPrefix "data:" (trim raw) of
            Nothing -> go rest content calls inputTokens outputTokens finishReason done
            Just rawChunk ->
                let chunk = trim rawChunk
                in if null chunk
                    then go rest content calls inputTokens outputTokens finishReason done
                    else if chunk == "[DONE]"
                        then finish content calls inputTokens outputTokens finishReason
                        else case parseJson chunk of
                            Left detail -> pure (Left (AgentError "MODEL_STREAM" ("invalid SSE packet: " ++ detail)))
                            Right event -> do
                                let usage = field "usage" event
                                    inputTokens' = if field "prompt_tokens" usage == JNull
                                        then inputTokens else jsonInteger (field "prompt_tokens" usage)
                                    outputTokens' = if field "completion_tokens" usage == JNull
                                        then outputTokens else jsonInteger (field "completion_tokens" usage)
                                (content', calls', finishReason', done') <-
                                    foldM (handleChoice onDelta) (content, calls, finishReason, done)
                                        (asArray (field "choices" event))
                                go rest content' calls' inputTokens' outputTokens' finishReason' done'
    finish content calls inputTokens outputTokens finishReason =
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
                Right value@(JObject _) ->
                    Right (acc ++ [ToolCall identifier name value])
                Right _ -> Left (AgentError "PROVIDER_JSON" "tool arguments must be an object")

handleChoice :: (String -> IO ()) -> (String, Map.Map Integer (String, String, String), Maybe String, Bool)
             -> Json -> IO (String, Map.Map Integer (String, String, String), Maybe String, Bool)
handleChoice onDelta (content, calls, finishReason, done) choice = do
    let delta = field "delta" choice
        piece = asString (field "content" delta)
    if null piece then pure () else onDelta piece
    let calls' = foldl updateCall calls (asArray (field "tool_calls" delta))
        reason = asString (field "finish_reason" choice)
        finishReason' = if null reason then finishReason else Just reason
        done' = done || not (null reason)
    pure (content ++ piece, calls', finishReason', done')
  where
    updateCall current item =
        let index = jsonInteger (field "index" item)
            function = field "function" item
            (identifier, name, arguments) = Map.findWithDefault ("", "", "") index current
        in Map.insert index
            ( identifier ++ asString (field "id" item)
            , name ++ asString (field "name" function)
            , arguments ++ asString (field "arguments" function)
            ) current

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace

jsonInteger :: Json -> Integer
jsonInteger (JNumber value) = truncate value
jsonInteger _ = 0

bounded :: String -> String
bounded text = if length text > 512 then take 512 text else text
