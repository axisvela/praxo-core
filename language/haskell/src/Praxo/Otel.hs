module Praxo.Otel
    ( OtelRequest(..)
    , OtelResponse(..)
    , OtelTransport(..)
    , OtelSink(..)
    , newOtelSink
    , buildOtelRequest
    , emitOtelEvent
    ) where

import Data.Bits (xor)
import Data.Char (ord)
import Data.Word (Word64)
import Numeric (showHex)
import Praxo.Agent (AgentError(..))
import Praxo.Harmovela (formatHarmovelaTimestamp)
import Praxo.Json
import Praxo.Runtime (Event(..))

data OtelRequest = OtelRequest
    { otelMethod :: String
    , otelURL :: String
    , otelHeaders :: [(String, String)]
    , otelBody :: String
    } deriving (Eq, Show)

data OtelResponse = OtelResponse
    { otelStatus :: Int
    , otelResponseBody :: String
    } deriving (Eq, Show)

newtype OtelTransport = OtelTransport
    { sendOtel :: OtelRequest -> IO (Either AgentError OtelResponse)
    }

data OtelSink = OtelSink
    { otelEndpoint :: String
    , otelServiceName :: String
    , otelAllowedDataKeys :: [String]
    , otelClock :: IO Integer
    , otelTransport :: OtelTransport
    }

newOtelSink :: String -> OtelTransport -> IO Integer -> OtelSink
newOtelSink endpoint transport clock = OtelSink
    { otelEndpoint = endpoint
    , otelServiceName = "praxo-core"
    , otelAllowedDataKeys = []
    , otelClock = clock
    , otelTransport = transport
    }

buildOtelRequest :: OtelSink -> Event -> IO (Either AgentError OtelRequest)
buildOtelRequest sink event = do
    nanos <- otelClock sink
    let dataText = either (const "") id (encodeJson (eventData event))
        key = eventSessionId event ++ "|" ++ maybe "" id (eventRunId event)
            ++ "|" ++ eventKind event ++ "|" ++ show nanos ++ "|" ++ dataText
        traceId = hex64 (fnv key 0xcbf29ce484222325)
            ++ hex64 (fnv key 0x84222325cbf29ce4)
        spanId = hex64 (fnv (key ++ "|span") 0x100000001b3)
        stamp = formatHarmovelaTimestamp nanos
        attributes = baseAttributes event stamp
            ++ dataAttributes sink event
        spanValue = JObject
            [ ("traceId", JString traceId)
            , ("spanId", JString spanId)
            , ("name", JString ("praxo." ++ eventKind event))
            , ("kind", JNumber 1)
            , ("startTimeUnixNano", JString (show nanos))
            , ("endTimeUnixNano", JString (show nanos))
            , ("attributes", JArray attributes)
            ]
        scopeSpan = JObject
            [ ("scope", JObject [("name", JString "praxo-core")])
            , ("spans", JArray [spanValue])
            ]
        resourceAttributes =
            JArray [ attribute "service.name" (otelServiceName sink) ]
        resourceSpan = JObject
            [ ("resource", JObject [("attributes", resourceAttributes)])
            , ("scopeSpans", JArray [scopeSpan])
            ]
        payload = JObject [ ("resourceSpans", JArray [resourceSpan]) ]
    pure $ case encodeJson payload of
        Left detail -> Left (AgentError "OTEL_JSON" detail)
        Right body -> Right OtelRequest
            { otelMethod = "POST"
            , otelURL = otelEndpoint sink
            , otelHeaders = [("content-type", "application/json")]
            , otelBody = body
            }

emitOtelEvent :: OtelSink -> Event -> IO (Either AgentError ())
emitOtelEvent sink event = do
    request <- buildOtelRequest sink event
    case request of
        Left err -> pure (Left err)
        Right httpRequest -> do
            response <- sendOtel (otelTransport sink) httpRequest
            pure $ case response of
                Left err -> Left err
                Right value
                    | otelStatus value >= 200 && otelStatus value < 300 -> Right ()
                    | otherwise -> Left (AgentError "OTEL_HTTP"
                        ("otel: HTTP " ++ show (otelStatus value) ++ ": "
                            ++ bounded (otelResponseBody value)))

baseAttributes :: Event -> String -> [Json]
baseAttributes event stamp =
    [ attribute "praxo.event.type" (eventKind event) ]
        ++ (if null (eventSessionId event)
                then []
                else [ attribute "praxo.session.id" (eventSessionId event) ])
        ++ maybe [] (\runId -> [ attribute "praxo.run.id" runId ]) (eventRunId event)
        ++ [ attribute "praxo.event.at" stamp ]

dataAttributes :: OtelSink -> Event -> [Json]
dataAttributes sink event =
    [ attribute ("praxo.event.data." ++ name) (textValue value)
    | name <- otelAllowedDataKeys sink
    , Just value <- [lookup name (asObject (eventData event))]
    ]

attribute :: String -> String -> Json
attribute key value = JObject
    [ ("key", JString key)
    , ("value", JObject [("stringValue", JString value)])
    ]

textValue :: Json -> String
textValue (JString value) = value
textValue value = either (const "") id (encodeJson value)

fnv :: String -> Word64 -> Word64
fnv text seed = foldl step seed (map (fromIntegral . ord) text)
  where
    step value byte = (value `xor` byte) * 0x100000001b3

hex64 :: Word64 -> String
hex64 value =
    let text = showHex value ""
    in replicate (16 - length text) '0' ++ text

bounded :: String -> String
bounded = take 512
