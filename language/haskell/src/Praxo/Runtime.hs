module Praxo.Runtime
    ( MemoryRecord(..), MemoryStore, newMemoryStore, memoryPut, memorySearch
    , Event(..), Sink(..), newSink, multiSink, filterSink, emitSink, sinkKinds, sinkKindLists
    , streamKinds
    , newCheckpoint, registerCheckpoint, checkpointMarshal, checkpointUnmarshal
    , PathGrant(..), PathChecker(..), Decision(..), normalizePath, pathChecker, pathCheck, pathAllowed
    , ContextBudget(..), ContextMessage(..), estimateTokens, compactContext, messageWire
    ) where

import Data.Char (toLower)
import Data.List (intercalate, isInfixOf, sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (comparing)
import Praxo.Json (Json(..), asString, encodeJson, field, parseJson)
import System.Info (os)

data MemoryRecord = MemoryRecord
    { recordId :: String
    , recordFrame :: String
    , recordContent :: String
    , recordCreatedAt :: String
    } deriving (Eq, Show)

data MemoryStore = MemoryStore
    { storeRecords :: Map String [MemoryRecord]
    , storeSequence :: Int
    } deriving (Eq, Show)

newMemoryStore :: MemoryStore
newMemoryStore = MemoryStore Map.empty 0

memoryPut :: MemoryStore -> String -> MemoryRecord -> (MemoryStore, MemoryRecord)
memoryPut store session record =
    let (withId, nextSequence) =
            if null (recordId record)
                then (record { recordId = "mem-" ++ show (storeSequence store) ++ "-" ++ show (length current) }, storeSequence store + 1)
                else (record, storeSequence store)
        withTime = if null (recordCreatedAt withId) then withId { recordCreatedAt = show nextSequence } else withId
        current = Map.findWithDefault [] session (storeRecords store)
        updated = store { storeRecords = Map.insert session (current ++ [withTime]) (storeRecords store), storeSequence = nextSequence }
    in (updated, withTime)

memorySearch :: MemoryStore -> String -> String -> Int -> [MemoryRecord]
memorySearch store session query limit =
    let needle = map toLower query
        records = Map.findWithDefault [] session (storeRecords store)
        matches = filter (\record -> null needle || needle `isInfixOf` map toLower (recordContent record)) records
        ordered = sortBy (flip (comparing recordCreatedAt)) matches
    in if limit > 0 then take limit ordered else ordered

data Event = Event
    { eventKind :: String
    , eventSessionId :: String
    , eventRunId :: Maybe String
    , eventData :: Json
    } deriving (Eq, Show)

data Sink = RecordSink [String] | MultiSink [Sink] | FilterSink Sink [String] deriving (Eq, Show)

newSink :: Sink
newSink = RecordSink []

multiSink :: [Sink] -> Sink
multiSink = MultiSink

filterSink :: Sink -> [String] -> Sink
filterSink = FilterSink

emitSink :: Sink -> Event -> Sink
emitSink (MultiSink sinks) event = MultiSink (map (`emitSink` event) sinks)
emitSink (FilterSink target predicate) event
    | null predicate || eventKind event `elem` predicate = FilterSink (emitSink target event) predicate
    | otherwise = FilterSink target predicate
emitSink (RecordSink kinds) event = RecordSink (kinds ++ [eventKind event])

sinkKinds :: Sink -> [String]
sinkKinds (RecordSink kinds) = kinds
sinkKinds (FilterSink target _) = sinkKinds target
sinkKinds (MultiSink _) = []

sinkKindLists :: Sink -> [[String]]
sinkKindLists (MultiSink sinks) = map sinkKinds sinks
sinkKindLists sink = [sinkKinds sink]

streamKinds :: [String]
streamKinds = ["values", "updates", "messages", "tasks", "debug", "checkpoint"]

type CheckpointAllowlist = [String]

newCheckpoint :: CheckpointAllowlist
newCheckpoint = []

registerCheckpoint :: CheckpointAllowlist -> String -> Either String CheckpointAllowlist
registerCheckpoint _ "" = Left "CHECKPOINT_ERROR"
registerCheckpoint allowlist kind = Right (allowlist ++ [kind | kind `notElem` allowlist])

checkpointMarshal :: CheckpointAllowlist -> String -> Json -> Either String String
checkpointMarshal allowlist kind value
    | kind `elem` allowlist = encodeJson (JObject [("type", JString kind), ("data", value)])
    | otherwise = Left "CHECKPOINT_TYPE_NOT_ALLOWED"

checkpointUnmarshal :: CheckpointAllowlist -> String -> Either String Json
checkpointUnmarshal allowlist raw = do
    envelope <- either (const (Left "CHECKPOINT_ERROR")) Right (parseJson raw)
    let kind = asString (field "type" envelope)
    if kind `elem` allowlist
        then Right (field "data" envelope)
        else Left "CHECKPOINT_TYPE_NOT_ALLOWED"

data PathGrant = PathGrant { grantRoot :: String, grantAccess :: String } deriving (Eq, Show)
newtype PathChecker = PathChecker [PathGrant] deriving (Eq, Show)
data Decision = Decision { decisionAllowed :: Bool, decisionReason :: String } deriving (Eq, Show)

normalizePath :: String -> String
normalizePath value =
    let path = map (\c -> if c == '\\' then '/' else c) value
        (prefix, body, absolute) =
            case path of
                drive : ':' : rest -> let isAbs = take 1 rest == "/" in (drive : ":" ++ if isAbs then "/" else "", rest, isAbs)
                '/' : _ -> ("/", path, True)
                _ -> ("", path, False)
        parts = reduce absolute (splitSlash body)
        result = prefix ++ intercalate "/" parts
    in if os == "mingw32" then map toLower result else result

splitSlash :: String -> [String]
splitSlash "" = [""]
splitSlash text = case break (== '/') text of
    (part, []) -> [part]
    (part, _ : rest) -> part : splitSlash rest

reduce :: Bool -> [String] -> [String]
reduce absolute = foldl step []
  where
    step acc "" = acc
    step acc "." = acc
    step acc ".."
        | null acc = if absolute then [] else [".."]
        | last acc == ".." = acc ++ [".."]
        | otherwise = init acc
    step acc part = acc ++ [part]

pathChecker :: [PathGrant] -> Either String PathChecker
pathChecker grants = PathChecker <$> mapM checkGrant grants
  where
    checkGrant grant
        | null (grantRoot grant) = Left "POLICY_ERROR"
        | grantAccess grant `notElem` ["read", "write", "readwrite"] = Left "POLICY_ERROR"
        | otherwise = Right grant { grantRoot = normalizePath (grantRoot grant) }

pathCheck :: PathChecker -> String -> String -> Either String Decision
pathCheck (PathChecker grants) target need
    | need `notElem` ["read", "write", "readwrite"] = Left "POLICY_ERROR"
    | null grants = Right (Decision False "no allowed roots")
    | any matches grants = Right (Decision True "allowed")
    | any (\grant -> within (grantRoot grant) resolved) grants = Right (Decision False "insufficient grant")
    | otherwise = Right (Decision False "outside roots")
  where
    resolved = normalizePath target
    matches grant = within (grantRoot grant) resolved && allows (grantAccess grant) need
    within root value = root == value || (root ++ "/") `isPrefixOf` value

allows :: String -> String -> Bool
allows "readwrite" _ = True
allows "read" "read" = True
allows "write" "write" = True
allows _ _ = False

pathAllowed :: PathChecker -> String -> String -> Bool
pathAllowed checker target need = case pathCheck checker target need of
    Right decision -> decisionAllowed decision
    Left _ -> False

isPrefixOf :: String -> String -> Bool
isPrefixOf prefix value = take (length prefix) value == prefix

data ContextBudget = ContextBudget { budgetMaxTokens :: Int, budgetKeepRecent :: Int } deriving (Eq, Show)
data ContextMessage = ContextMessage
    { messageRole :: String
    , messageContent :: String
    , messageBlocks :: [String]
    , messageCalls :: [(String, Json)]
    , messageToolId :: Maybe String
    } deriving (Eq, Show)

estimateTokens :: [ContextMessage] -> Int
estimateTokens = sum . map messageTokens
  where
    messageTokens message = 4
        + length (messageContent message) `div` 4
        + length (fromMaybe "" (messageToolId message)) `div` 4
        + sum [4 + length block `div` 4 | block <- messageBlocks message]
        + sum [4 + length name `div` 4 + length (render arguments) `div` 4 | (name, arguments) <- messageCalls message]
    render value = either (const "") id (encodeJson value)

compactContext :: ContextBudget -> [ContextMessage] -> ([ContextMessage], Bool)
compactContext budget messages
    | budgetMaxTokens budget <= 0 || estimateTokens messages <= budgetMaxTokens budget = (messages, True)
    | otherwise =
        let (system, rest) = partitionSystem messages
            system' = filter (not . isCompaction . messageContent) system
        in case fitSystem system' (budgetMaxTokens budget) of
            Nothing -> ([], False)
            Just fitted ->
                let keep = if budgetKeepRecent budget > 0 then budgetKeepRecent budget else 4
                    start = alignStart rest (max (length rest - keep) 0)
                    marker = ContextMessage "system" ("[context compacted: " ++ show start ++ " older messages omitted]") [] [] Nothing
                    kept = drop start rest
                    output = fitted ++ (if start > 0 then [marker] else []) ++ kept
                in shrink output kept fitted marker start (budgetMaxTokens budget)
  where
    isCompaction value = take 19 value == "[context compacted:"

partitionSystem :: [ContextMessage] -> ([ContextMessage], [ContextMessage])
partitionSystem messages = (filter isSystem messages, filter (not . isSystem) messages)
  where isSystem message = messageRole message == "system"

fitSystem :: [ContextMessage] -> Int -> Maybe [ContextMessage]
fitSystem [] _ = Just []
fitSystem system maxTokens
    | estimateTokens system <= maxTokens = Just system
    | otherwise =
        case system of
            (first:rest) ->
                let trimmed = first { messageContent = truncateToTokens (messageContent first) (maxTokens - 4) }
                    candidate = trimmed : rest
                in if estimateTokens candidate <= maxTokens then Just candidate else Nothing

truncateToTokens :: String -> Int -> String
truncateToTokens text tokens
    | tokens <= 0 = ""
    | length text <= limit = text
    | limit <= 16 = take limit text
    | otherwise = take (limit - 16) text ++ "\n[truncated]"
  where limit = tokens * 4

alignStart :: [ContextMessage] -> Int -> Int
alignStart _ 0 = 0
alignStart rest start
    | messageRole (rest !! start) == "tool" = alignStart rest (start - 1)
    | otherwise = start

shrink :: [ContextMessage] -> [ContextMessage] -> [ContextMessage] -> ContextMessage -> Int -> Int -> ([ContextMessage], Bool)
shrink output kept system marker start maxTokens
    | estimateTokens output > maxTokens && length kept > 1 =
        if messageRole (kept !! 1) == "tool"
            then (output, False)
            else
                let kept' = drop 1 kept
                    output' = system ++ (if start > 0 then [marker] else []) ++ kept'
                in shrink output' kept' system marker start maxTokens
    | otherwise = (output, estimateTokens output <= maxTokens)

messageWire :: ContextMessage -> Json
messageWire message =
    let base = [("role", JString (messageRole message))]
        content = if not (null (messageContent message)) || null (messageBlocks message) && null (messageCalls message) && messageToolId message == Nothing
            then [("content", JString (messageContent message))]
            else []
        blocks = if null (messageBlocks message) then [] else [("contentBlocks", JArray [JObject [("type", JString "text"), ("text", JString block)] | block <- messageBlocks message])]
        calls = if null (messageCalls message) then [] else [("toolCalls", JArray [JObject [("id", JString ""), ("name", JString name), ("arguments", arguments)] | (name, arguments) <- messageCalls message])]
        toolId = maybe [] (\value -> [("toolId", JString value)]) (messageToolId message)
    in JObject (base ++ content ++ blocks ++ calls ++ toolId)
