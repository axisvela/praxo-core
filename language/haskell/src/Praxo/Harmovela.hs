module Praxo.Harmovela
    ( HarmovelaRequest(..)
    , HarmovelaResponse(..)
    , HarmovelaTransport(..)
    , HarmovelaSink(..)
    , newHarmovelaSink
    , buildHarmovelaRequest
    , emitHarmovelaEvent
    , formatHarmovelaTimestamp
    ) where

import Data.Char (isSpace)
import Praxo.Agent (AgentError(..))
import Praxo.Json (Json(..), encodeJson)
import Praxo.Runtime (Event(..))

data HarmovelaRequest = HarmovelaRequest
    { harmovelaMethod :: String
    , harmovelaURL :: String
    , harmovelaHeaders :: [(String, String)]
    , harmovelaBody :: String
    } deriving (Eq, Show)

data HarmovelaResponse = HarmovelaResponse
    { harmovelaStatus :: Int
    , harmovelaResponseBody :: String
    } deriving (Eq, Show)

newtype HarmovelaTransport = HarmovelaTransport
    { sendHarmovela :: HarmovelaRequest -> IO (Either AgentError HarmovelaResponse)
    }

data HarmovelaSink = HarmovelaSink
    { harmovelaBaseURL :: String
    , harmovelaSource :: String
    , harmovelaSpecVersion :: String
    , harmovelaClock :: IO Integer
    , harmovelaTransport :: HarmovelaTransport
    }

newHarmovelaSink :: String -> HarmovelaTransport -> IO Integer -> HarmovelaSink
newHarmovelaSink base transport clock = HarmovelaSink
    { harmovelaBaseURL = base
    , harmovelaSource = "praxo-core"
    , harmovelaSpecVersion = "0.2"
    , harmovelaClock = clock
    , harmovelaTransport = transport
    }

buildHarmovelaRequest :: HarmovelaSink -> Event -> IO (Either AgentError HarmovelaRequest)
buildHarmovelaRequest sink event
    | null (harmovelaBaseURL sink) =
        pure (Left (AgentError "HARMOVELA_URL" "harmovela: base URL is required"))
    | otherwise = do
        nanos <- harmovelaClock sink
        case encodeJson (envelope sink event nanos) of
            Left detail -> pure (Left (AgentError "HARMOVELA_ENVELOPE" detail))
            Right body -> pure (Right HarmovelaRequest
                { harmovelaMethod = "POST"
                , harmovelaURL = trimSlash (harmovelaBaseURL sink) ++ "/events"
                , harmovelaHeaders = [("content-type", "application/json")]
                , harmovelaBody = body
                })

emitHarmovelaEvent :: HarmovelaSink -> Event -> IO (Either AgentError ())
emitHarmovelaEvent sink event = do
    request <- buildHarmovelaRequest sink event
    case request of
        Left err -> pure (Left err)
        Right httpRequest -> do
            response <- sendHarmovela (harmovelaTransport sink) httpRequest
            pure $ case response of
                Left err -> Left err
                Right value
                    | harmovelaStatus value >= 200 && harmovelaStatus value < 300 -> Right ()
                    | otherwise -> Left (AgentError "HARMOVELA_HTTP"
                        ("harmovela: HTTP " ++ show (harmovelaStatus value) ++ ": " ++ bounded (harmovelaResponseBody value)))

envelope :: HarmovelaSink -> Event -> Integer -> Json
envelope sink event nanos = JObject
    [ ("spec_version", JString (specVersion sink))
    , ("id", JString (eventID event nanos))
    , ("type", JString (eventKind event))
    , ("source", JString (source sink))
    , ("created_at", JString (formatHarmovelaTimestamp nanos))
    , ("payload", JObject (payload event))
    ]

payload :: Event -> [(String, Json)]
payload event =
    let base = case eventData event of
            JObject fields -> fields
            _ -> []
    in apply "session_id" (maybeValue (eventSessionId event)) (apply "run_id" (maybeValue =<< eventRunId event) base)

maybeValue :: String -> Maybe String
maybeValue "" = Nothing
maybeValue value = Just value

apply :: String -> Maybe String -> [(String, Json)] -> [(String, Json)]
apply _ Nothing fields = fields
apply key (Just value) fields = filter ((/= key) . fst) fields ++ [(key, JString value)]

eventID :: Event -> Integer -> String
eventID event nanos =
    let prefix = case eventRunId event of
            Just run | not (null run) -> run
            _ -> if null (eventSessionId event) then "event" else eventSessionId event
    in prefix ++ "-" ++ show nanos

source :: HarmovelaSink -> String
source sink = if null (harmovelaSource sink) then "praxo-core" else harmovelaSource sink

specVersion :: HarmovelaSink -> String
specVersion sink = if null (harmovelaSpecVersion sink) then "0.2" else harmovelaSpecVersion sink

formatHarmovelaTimestamp :: Integer -> String
formatHarmovelaTimestamp nanos =
    let (seconds, fraction) = nanos `divMod` 1000000000
        (days, daySeconds) = seconds `divMod` 86400
        (year, month, day) = civilFromDays days
        hour = daySeconds `div` 3600
        minute = (daySeconds `mod` 3600) `div` 60
        second = daySeconds `mod` 60
    in pad 4 year ++ "-" ++ pad 2 month ++ "-" ++ pad 2 day ++ "T" ++
       pad 2 hour ++ ":" ++ pad 2 minute ++ ":" ++ pad 2 second ++ "." ++
       pad 9 fraction ++ "Z"

civilFromDays :: Integer -> (Integer, Integer, Integer)
civilFromDays offset =
    let z = offset + 719468
        era = if z >= 0 then z `div` 146097 else (z - 146096) `div` 146097
        doe = z - era * 146097
        yoe = (doe - doe `div` 1460 + doe `div` 36524 - doe `div` 146096) `div` 365
        year = yoe + era * 400
        doy = doe - (365 * yoe + yoe `div` 4 - yoe `div` 100)
        mp = (5 * doy + 2) `div` 153
        day = doy - (153 * mp + 2) `div` 5 + 1
        month = if mp < 10 then mp + 3 else mp - 9
    in (if month <= 2 then year + 1 else year, month, day)

pad :: Int -> Integer -> String
pad width value =
    let text = show value
    in replicate (max 0 (width - length text)) '0' ++ text

trimSlash :: String -> String
trimSlash = reverse . dropWhile (== '/') . reverse

bounded :: String -> String
bounded text =
    let trimmed = trim text
    in if length trimmed > 512 then take 512 trimmed else trimmed

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace

dropWhileEnd :: (a -> Bool) -> [a] -> [a]
dropWhileEnd predicate = reverse . dropWhile predicate . reverse
