module Praxo.ToolCall (ToolCall(..), parseToolCall, stripToolCallMarkup) where

import Data.Char (isAlpha, isAlphaNum, isAscii, isSpace)
import Data.List (findIndex, isPrefixOf, isSuffixOf, stripPrefix, tails)
import Data.Maybe (mapMaybe)
import Praxo.Json

data ToolCall = ToolCall { callName :: String, callInput :: Json, callMetadata :: [(String, String)] } deriving (Eq, Show)

parseToolCall :: String -> Maybe ToolCall
parseToolCall content | length content > 262144 = Nothing
parseToolCall content = case parseJson content of
    Right object@(JObject _) | not (null (asString (field "name" object))) -> do
        let arguments = field "input" object
            metadataKeys = ["operation", "resource", "risk", "reason", "idempotency_key"]
            stringField key = case field key object of JString _ -> True; JNull -> True; _ -> False
        if not (all stringField metadataKeys) then Nothing else case arguments of
            JObject _ -> fromObject object arguments
            JNull -> fromObject object JNull
            _ -> Nothing
    _ -> case reverse (blocks content) of
        block:_ -> blockCall block
        [] -> case reverse (mapMaybe plain (lines content)) of
            candidate:_ -> blockCall candidate
            [] -> Nothing
  where
    fromObject object arguments = Just (ToolCall (asString (field "name" object)) arguments
        [(key, asString (field key object)) | key <- ["operation", "resource", "risk", "reason", "idempotency_key"]])
    blockCall (name, body) = do
        arguments <- parseInput body
        pure (ToolCall name arguments [])
    plain line =
        let (name, body) = break isSpace (trim line)
        in if validName name && '.' `elem` name && "{" `isPrefixOf` trim body && "}" `isSuffixOf` trim body then
            Just (name, body)
        else Nothing

parseInput :: String -> Maybe Json
parseInput raw = case parseJson (trim raw) of
    Right value@(JObject _) -> Just value
    _ -> case parseJson (concatMap (\c -> if c == '\\' then "\\\\" else [c]) (trim raw)) of
        Right value@(JObject _) -> Just value
        _ -> Nothing

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

validName :: String -> Bool
validName (first:rest) = isAscii first && isAlpha first && all (\c -> isAscii c && (isAlphaNum c || c `elem` "_.-")) rest
validName [] = False

splitAtText :: String -> String -> Maybe (String, String)
splitAtText needle haystack = do
    index <- findIndex (isPrefixOf needle) (tails haystack)
    pure (take index haystack, drop (index + length needle) haystack)

blocks :: String -> [(String, String)]
blocks content = case break (== '<') content of
    (_, []) -> []
    (_, _:rest) -> case splitAtText ">" rest of
        Nothing -> []
        Just (header, body) -> case headerName header of
            Nothing -> blocks body
            Just name -> case splitAtText ("</" ++ takeWhile (not . isSpace) header ++ ">") body of
                Nothing -> []
                Just (arguments, suffix) -> (name, arguments) : blocks suffix

headerName :: String -> Maybe String
headerName header
    | "tool_call" `isPrefixOf` header = do
        remainder <- stripPrefix "tool_call" header
        if null remainder || not (isSpace (firstCharacter remainder)) then Nothing else do
            named <- stripPrefix "name=\"" (dropWhile isSpace remainder)
            let (name, suffix) = break (== '"') named
            case suffix of
                '"':after | not (null name) && all isSpace after -> Just name
                _ -> Nothing
    | validName header && '.' `elem` header && not (".." `isInfix` header) && not ("." `isSuffixOf` header) = Just header
    | otherwise = Nothing
  where
    firstCharacter (first:_) = first
    firstCharacter [] = 'x'
    isInfix needle haystack = any (isPrefixOf needle) (tails haystack)

stripToolCallMarkup :: String -> String
stripToolCallMarkup content | length content > 262144 = content
stripToolCallMarkup content = trim (collapse (strip content))
  where
    strip [] = []
    strip text@('<':rest) = case splitAtText ">" rest of
        Just (header, body)
            | Just _ <- headerName header ->
                let closing = "</" ++ takeWhile (not . isSpace) header ++ ">"
                in case splitAtText closing body of
                    Just (_, suffix) -> strip suffix
                    Nothing -> ""
        Just (header, body) -> '<' : header ++ ">" ++ strip body
        Nothing -> text
    strip (first:rest) = first : strip rest
    collapse ('\n':'\n':'\n':rest) = collapse ('\n':'\n':rest)
    collapse (first:rest) = first : collapse rest
    collapse [] = []
