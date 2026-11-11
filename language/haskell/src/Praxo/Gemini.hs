module Praxo.Gemini
    ( GeminiTool(..)
    , GeminiConfig(..)
    , buildGeminiRequest
    , parseGeminiResponse
    , generateGemini
    ) where

import Praxo.Agent (AgentError(..), Message(..), Response(..), ToolCall(..))
import Praxo.Json (Json(..), asArray, asString, encodeJson, field, parseJson)
import Praxo.OpenAICompatible (HttpRequest(..), HttpResponse(..), Transport(..))

data GeminiTool = GeminiTool
    { geminiToolName :: String
    , geminiToolDescription :: String
    , geminiToolParameters :: Json
    } deriving (Eq, Show)

data GeminiConfig = GeminiConfig
    { geminiBaseURL :: String
    , geminiModel :: String
    , geminiKey :: Maybe String
    , geminiMaxOutputTokens :: Integer
    , geminiToolChoice :: Maybe String
    , geminiTools :: [GeminiTool]
    , geminiTransport :: Transport
    }

buildGeminiRequest :: GeminiConfig -> [Message] -> Either AgentError HttpRequest
buildGeminiRequest config messages = do
    (system, contents) <- contentsJson messages
    let declarations = map toolJson (geminiTools config)
        base = [("contents", JArray contents)]
        withSystem = if null system then base else base ++ [("system_instruction", JObject [("parts", JArray (map (\text -> JObject [("text", JString text)]) system))])]
        withTools = if null declarations then withSystem else withSystem ++
            [ ("tools", JArray [JObject [("functionDeclarations", JArray declarations)]])
            , ("toolConfig", JObject [("functionCallingConfig", JObject [("mode", JString (toolMode (geminiToolChoice config)))])])
            ]
        withGeneration = if geminiMaxOutputTokens config > 0
            then withTools ++ [("generationConfig", JObject [("maxOutputTokens", JNumber (fromIntegral (geminiMaxOutputTokens config)))])]
            else withTools
    case encodeJson (JObject withGeneration) of
        Left detail -> Left (AgentError "PROVIDER_REQUEST" detail)
        Right text ->
            Right HttpRequest
                { httpMethod = "POST"
                , httpURL = trimSlash (geminiBaseURL config) ++ "/v1beta/models/" ++ geminiModel config ++ ":generateContent"
                , httpHeaders =
                    [ ("Content-Type", "application/json")
                    , ("Accept", "application/json")
                    ] ++ case geminiKey config of
                        Nothing -> []
                        Just key -> [("x-goog-api-key", key)]
                , httpBody = text
                }
  where
    toolMode (Just "required") = "ANY"
    toolMode (Just "none") = "NONE"
    toolMode _ = "AUTO"
    trimSlash = reverse . dropWhile (== '/') . reverse

contentsJson :: [Message] -> Either AgentError ([String], [Json])
contentsJson messages = go messages [] [] [] []
  where
    go [] system out pending _ = do
        flushed <- flush pending out
        pure (reverse system, reverse flushed)
    go (message : rest) system out pending names
        | messageRole message == "system" =
            go rest (messageContent message : system) out pending names
        | messageRole message == "tool" =
            let name = maybe (messageToolCallId message) id (lookup (messageToolCallId message) names)
                result = JObject [("functionResponse", JObject
                    [ ("name", JString name)
                    , ("response", JObject [("result", JString (messageContent message))])
                    ])]
            in go rest system out (pending ++ [result]) names
        | otherwise = do
            flushed <- flush pending out
            parts <- partsJson message
            let role = if messageRole message == "assistant" then "model" else "user"
                names' = names ++ [(toolCallId call, toolCallName call) | call <- messageToolCalls message, not (null (toolCallId call)), not (null (toolCallName call))]
            go rest system (if null parts then flushed else JObject [("role", JString role), ("parts", JArray parts)] : flushed) [] names'
    flush [] out = pure out
    flush pending out = pure (JObject [("role", JString "user"), ("parts", JArray pending)] : out)

partsJson :: Message -> Either AgentError [Json]
partsJson message = do
    let text = if null (messageContent message) then [] else [JObject [("text", JString (messageContent message))]]
    pure (text ++ map callJson (messageToolCalls message))
  where
    callJson call = JObject [("functionCall", JObject
        [ ("name", JString (toolCallName call))
        , ("args", toolCallArguments call)
        ])]

toolJson :: GeminiTool -> Json
toolJson tool = JObject
    [ ("name", JString (geminiToolName tool))
    , ("description", JString (geminiToolDescription tool))
    , ("parameters", parameters)
    ]
  where
    parameters = case geminiToolParameters tool of
        JNull -> JObject [("type", JString "object")]
        value -> value

parseGeminiResponse :: String -> Either AgentError Response
parseGeminiResponse text = do
    root <- parseJson text `orAgent` "PROVIDER_RESPONSE"
    if field "error" root /= JNull
        then Left (AgentError "PROVIDER_HTTP" "gemini: provider error")
        else case asArray (field "candidates" root) of
            [] -> Left (AgentError "PROVIDER_HTTP" "gemini: empty response")
            candidate : _ -> do
                let content = field "content" candidate
                    parts = asArray (field "parts" content)
                allCalls <- mapM callFromJson (zip [1 ..] parts)
                let calls = filter (\call -> not (null (toolCallName call))) allCalls
                let textValue = concatMap (\part -> asString (field "text" part)) parts
                    usage = field "usageMetadata" root
                pure Response
                    { responseContent = textValue
                    , responseToolCalls = calls
                    , inputTokens = jsonInteger (field "promptTokenCount" usage)
                    , outputTokens = jsonInteger (field "candidatesTokenCount" usage)
                    }
  where
    callFromJson (index, part) = case field "functionCall" part of
        JObject _ -> Right ToolCall
            { toolCallId = "call-" ++ show index
            , toolCallName = asString (field "name" (field "functionCall" part))
            , toolCallArguments = case field "args" (field "functionCall" part) of
                value@(JObject _) -> value
                _ -> JObject []
            }
        _ -> Right (ToolCall "" "" (JObject []))

generateGemini :: GeminiConfig -> [Message] -> IO (Either AgentError Response)
generateGemini config messages =
    case buildGeminiRequest config messages of
        Left errorValue -> pure (Left errorValue)
        Right httpRequest -> do
            result <- sendTransport (geminiTransport config) httpRequest
            pure $ case result of
                Left errorValue -> Left errorValue
                Right response
                    | httpStatus response < 200 || httpStatus response >= 300 ->
                        Left (AgentError "PROVIDER_HTTP"
                            ("provider returned HTTP " ++ show (httpStatus response) ++ ": " ++ bounded (httpResponseBody response)))
                    | otherwise -> parseGeminiResponse (httpResponseBody response)

orAgent :: Either String Json -> String -> Either AgentError Json
orAgent (Right value) _ = Right value
orAgent (Left detail) code = Left (AgentError code detail)

jsonInteger :: Json -> Integer
jsonInteger (JNumber value) = truncate value
jsonInteger _ = 0

bounded :: String -> String
bounded text = if length text > 512 then take 512 text else text
