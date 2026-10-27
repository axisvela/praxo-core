module Praxo.Middleware
    ( piiRedact, redactValue, extractJson, StructuredOutput(..), structuredOutput, applyStructured
    , CallLimit(..), callLimit, callLimitModel, callLimitTool
    , toolSelection, selectTools, checkToolSelected
    , fallbackGenerate, fallbackEither
    ) where

import Data.Char (isAlphaNum, isDigit, isLetter)
import Data.List (findIndex)
import Praxo.Json (Json(..), parseJson)
import Praxo.JsonSchema (validateSchema)

piiRedact :: String -> String
piiRedact = redactPhone . redactCard . redactSsn . redactEmails

redactEmails :: String -> String
redactEmails text = go 0 ""
  where
    n = length text
    go cursor output
        | cursor >= n = output ++ drop cursor text
        | otherwise = case findIndex (== '@') (drop cursor text) of
            Nothing -> output ++ drop cursor text
            Just offset ->
                let at = cursor + offset
                    first = expandLeft at
                    endPos = expandRight (at + 1)
                    dots = [i | i <- [at + 1 .. endPos - 1], atChar i == '.']
                    dot = if null dots then 0 else last dots
                    suffix = expandLetters (dot + 1) endPos
                in if first < at && dot > at + 1 && suffix - dot - 1 >= 2
                    then go suffix (output ++ take (first - cursor) (drop cursor text) ++ "[REDACTED:email]")
                    else go (at + 1) (output ++ take (at - cursor + 1) (drop cursor text))
    atChar i = text !! i
    expandLeft i = if i > 0 && atChar (i - 1) `elem` emailLocal then expandLeft (i - 1) else i
    expandRight i = if i < n && atChar i `elem` emailDomain then expandRight (i + 1) else i
    expandLetters i limit = if i < limit && isLetter (atChar i) then expandLetters (i + 1) limit else i
    emailLocal = ['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'] ++ "._%+-"
    emailDomain = ['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'] ++ ".-"

redactSsn :: String -> String
redactSsn = replaceMatches match "[REDACTED:ssn]"
  where
    match i text
        | i + 10 < length text && boundaryLeft i text && digitsAt i 3 text
            && atChar (i + 3) text == '-' && digitsAt (i + 4) 2 text
            && atChar (i + 6) text == '-' && digitsAt (i + 7) 4 text
            && boundaryRight (i + 10) text = Just (i + 10)
        | otherwise = Nothing
    atChar i text = text !! i
    boundaryLeft i text = i == 0 || not (isWord (text !! (i - 1)))
    boundaryRight i text = i >= length text - 1 || not (isWord (text !! (i + 1)))
    digitsAt i count text = i >= 0 && i + count <= length text && all isDigit (take count (drop i text))
    isWord c = isAlphaNum c || c == '_'

redactCard :: String -> String
redactCard = replaceMatches match "[REDACTED:credit_card]"
  where
    match i text
        | boundaryLeft i text = case parseGroups i text of
            Just finish | boundaryRight finish text -> Just finish
            _ -> Nothing
        | otherwise = Nothing
    parseGroups i text = go i (1 :: Int)
      where
        go position group
            | group > 4 = Just (position - 1)
            | not (digitsAt position 4 text) = Nothing
            | otherwise =
                let next = position + 4
                    after = if group < 4 && next < length text && text !! next `elem` " -" then next + 1 else next
                in go after (group + 1)
    digitsAt i count text = i + count <= length text && all isDigit (take count (drop i text))
    boundaryLeft i text = i == 0 || not (isWord (text !! (i - 1)))
    boundaryRight i text = i >= length text - 1 || not (isWord (text !! (i + 1)))
    isWord c = isAlphaNum c || c == '_'

redactPhone :: String -> String
redactPhone = replaceMatches match "[REDACTED:phone]"
  where
    match i text
        | not (boundaryLeft i text) = Nothing
        | otherwise = case [finish | Just finish <- candidates, boundaryRightAt text finish] of
            (finish:_) -> Just finish
            [] -> Nothing
      where
        candidates =
            [parseBody i text] ++
            [parseBody (skipSeparator (i + 1) text) text | atChar i text == '1'] ++
            [parseBody (skipSeparator (i + 2) text) text | take 2 (drop i text) == "+1"]
    parseBody start text = go start
      where
        go position
            | position > length text = Nothing
            | position < length text && text !! position == '(' =
                if digitsAt (position + 1) 3 text && position + 4 < length text && text !! (position + 4) == ')'
                    then finish (position + 5)
                    else Nothing
            | digitsAt position 3 text = finish (position + 3)
            | otherwise = Nothing
        finish position =
            let p1 = skipSeparator position text
            in if digitsAt p1 3 text
                then let p2 = skipSeparator (p1 + 3) text
                     in if digitsAt p2 4 text then Just (p2 + 3) else Nothing
                else Nothing
    digitsAt i count text = i >= 0 && i + count <= length text && all isDigit (take count (drop i text))
    atChar i text = if i < length text then text !! i else '\0'
    skipSeparator i text = if i < length text && text !! i `elem` " -." then i + 1 else i
    boundaryLeft i text = i == 0 || not (isWord (text !! (i - 1)))
    boundaryRightAt text finish = finish >= length text - 1 || not (isWord (text !! (finish + 1)))
    isWord c = isAlphaNum c || c == '_'

replaceMatches :: (Int -> String -> Maybe Int) -> String -> String -> String
replaceMatches match replacement text = go 0 ""
  where
    n = length text
    go cursor output
        | cursor >= n = output
        | Just finish <- match cursor text = go (finish + 1) (output ++ replacement)
        | otherwise = go (cursor + 1) (output ++ [text !! cursor])


redactValue :: Json -> Json
redactValue (JString text) = JString (piiRedact text)
redactValue (JArray values) = JArray (map redactValue values)
redactValue (JObject fields) = JObject [(key, redactValue value) | (key, value) <- fields]
redactValue value = value

extractJson :: String -> Maybe Json
extractJson text =
    let trimmed = trim text
        stripped = if take 3 trimmed == "```" then trim (stripFence trimmed) else trimmed
    in case findIndex (`elem` "{[" ) stripped of
        Nothing -> Nothing
        Just start -> either (const Nothing) Just (parseJson (drop start stripped))

stripFence :: String -> String
stripFence text = case break (== '\n') text of
    (_, '\n':rest) -> reverse (dropWhile (== '\n') (reverse rest))
    _ -> text

trim :: String -> String
trim = reverse . dropWhile (`elem` " \t\r\n") . reverse . dropWhile (`elem` " \t\r\n")

data StructuredOutput = StructuredOutput
    { outputSchema :: Json
    , maxRepairs :: Int
    , repairer :: Maybe (String -> Either String String)
    }

structuredOutput :: Json -> Int -> Maybe (String -> Either String String) -> StructuredOutput
structuredOutput = StructuredOutput

applyStructured :: StructuredOutput -> String -> Either String String
applyStructured config = attempt 0
  where
    attempt count text =
        case extractJson text of
            Just value | either (const False) null (validateSchema (outputSchema config) value) -> Right text
            _ | count >= maxRepairs config -> Left "AGENT_STRUCTURED_OUTPUT"
            _ -> case repairer config of
                Nothing -> Left "AGENT_STRUCTURED_OUTPUT"
                Just repair -> case repair text of
                    Left errorCode -> Left errorCode
                    Right repaired
                        | null (trim repaired) -> Left "AGENT_STRUCTURED_OUTPUT"
                        | otherwise -> attempt (count + 1) repaired

data CallLimit = CallLimit
    { limitModel :: Int
    , limitTool :: Int
    , modelsCalled :: Int
    , toolsCalled :: Int
    } deriving (Eq, Show)

callLimit :: Int -> Int -> CallLimit
callLimit model tool = CallLimit model tool 0 0

callLimitModel :: CallLimit -> Either String CallLimit
callLimitModel limit =
    let updated = limit { modelsCalled = modelsCalled limit + 1 }
    in if limitModel limit > 0 && modelsCalled updated > limitModel limit
        then Left "AGENT_MODEL_CALL_LIMIT"
        else Right updated

callLimitTool :: CallLimit -> Either String CallLimit
callLimitTool limit =
    let updated = limit { toolsCalled = toolsCalled limit + 1 }
    in if limitTool limit > 0 && toolsCalled updated > limitTool limit
        then Left "AGENT_TOOL_CALL_LIMIT"
        else Right updated

type ToolSelection = [String]

toolSelection :: [String] -> ToolSelection
toolSelection = id

selectTools :: ToolSelection -> [String] -> [String]
selectTools selection = filter (`elem` selection)

checkToolSelected :: ToolSelection -> String -> Either String ()
checkToolSelected selection name
    | name `elem` selection = Right ()
    | otherwise = Left "AGENT_TOOL_NOT_SELECTED"

fallbackEither :: Either e a -> Either e a -> Either e a
fallbackEither primary fallback = case primary of
    Left _ -> fallback
    Right _ -> primary

fallbackGenerate :: IO (Either e a) -> IO (Either e a) -> IO (Either e a)
fallbackGenerate primary fallback = do
    result <- primary
    case result of
        Left _ -> fallback
        Right _ -> pure result
