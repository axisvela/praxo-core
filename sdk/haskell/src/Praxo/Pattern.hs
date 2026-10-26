module Praxo.Pattern (matchPattern) where

import Data.Char (isAscii, isDigit, isSpace)
import qualified Data.IntSet as Set
import qualified Data.IntMap.Strict as Map

type Token = (Char -> Bool, Char)

matchPattern :: String -> String -> Either String Bool
matchPattern patternText input
    | length patternText > 256 || (toInteger (length patternText) + 1) * (toInteger (length input) + 1) ^ (2 :: Int) > 2000000 = Left "SCHEMA_PATTERN_CAPACITY"
    | not (all isAscii patternText) = Left "SCHEMA_PATTERN_UNSUPPORTED"
    | otherwise = do
        let (atStart, body) = case patternText of '^':rest -> (True, rest); _ -> (False, patternText)
        (tokens, atEnd) <- compile body
        let initial = if atStart then Set.singleton 0 else Set.fromList [0..length input]
            result = foldl transition initial tokens
        pure (if atEnd then Set.member inputSize result else not (Set.null result))
  where
    inputSize = length input
    characters = Map.fromList (zip [0..] input)
    transition positions (predicate, quantifier) = Set.fromList
        [end | start <- Set.toList positions, end <- consume predicate quantifier start]
    consume predicate quantifier start =
        let ends = takeWhile (\end -> end <= inputSize && (end == start || predicate (characters Map.! (end - 1)))) [start..]
        in case quantifier of
            '*' -> ends
            '+' -> drop 1 ends
            '?' -> take 2 ends
            _ -> take 1 (drop 1 ends)

compile :: String -> Either String ([Token], Bool)
compile [] = Right ([], False)
compile "$" = Right ([], True)
compile text = do
    (predicate, rest) <- atom text
    let (quantifier, remaining) = case rest of
            first:suffix | first `elem` "*+?" -> (first, suffix)
            _ -> ('1', rest)
    (tokens, atEnd) <- compile remaining
    pure ((predicate, quantifier) : tokens, atEnd)

atom :: String -> Either String (Char -> Bool, String)
atom ('.':rest) = Right ((/= '\n'), rest)
atom ('\\':code:rest) = do
    predicate <- escaped code
    pure (predicate, rest)
atom ('[':rest) = do
    let (negative, body) = case rest of '^':suffix -> (True, suffix); _ -> (False, rest)
    (predicates, remaining) <- characterClass body
    if null predicates then Left "SCHEMA_PATTERN_UNSUPPORTED" else
        Right ((\c -> any ($ c) predicates /= negative), remaining)
atom (first:rest)
    | first `elem` "^$[](){}|*+?\\" = Left "SCHEMA_PATTERN_UNSUPPORTED"
    | otherwise = Right ((== first), rest)
atom [] = Left "SCHEMA_PATTERN_UNSUPPORTED"

escaped :: Char -> Either String (Char -> Bool)
escaped 'd' = Right isDigit
escaped 'w' = Right (\c -> isAscii c && (c `elem` ['a'..'z'] || c `elem` ['A'..'Z'] || isDigit c || c == '_'))
escaped 's' = Right (\c -> isAscii c && isSpace c)
escaped code
    | code `elem` ".^$[](){}|*+?\\-" = Right (== code)
    | otherwise = Left "SCHEMA_PATTERN_UNSUPPORTED"

characterClass :: String -> Either String ([Char -> Bool], String)
characterClass (']':rest) = Right ([], rest)
characterClass ('\\':code:rest) = do
    predicate <- escaped code
    (others, remaining) <- characterClass rest
    pure (predicate : others, remaining)
characterClass (low:'-':high:rest) | high /= ']' = do
    if low > high || low == '\\' || high == '\\' then Left "SCHEMA_PATTERN_UNSUPPORTED" else do
        (others, remaining) <- characterClass rest
        pure ((\c -> c >= low && c <= high) : others, remaining)
characterClass (first:rest) = do
    (others, remaining) <- characterClass rest
    pure ((== first) : others, remaining)
characterClass [] = Left "SCHEMA_PATTERN_UNSUPPORTED"
