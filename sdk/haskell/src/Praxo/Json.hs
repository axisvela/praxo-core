module Praxo.Json (Json(..), parseJson, encodeJson, equalJson, field, asString, asArray, asObject) where

import Control.Monad (guard)
import Data.Char (chr, digitToInt, isDigit, isHexDigit, ord)
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import Data.Ratio (denominator, numerator, (%))
import Numeric (showHex)
import Text.ParserCombinators.ReadP

data Json = JObject [(String, Json)] | JArray [Json] | JString String | JNumber Rational | JBool Bool | JNull deriving (Eq, Show)

field :: String -> Json -> Json
field name (JObject fields) = maybe JNull id (lookup name (reverse fields))
field _ _ = JNull

asString :: Json -> String
asString (JString value) = value
asString _ = ""

asArray :: Json -> [Json]
asArray (JArray values) = values
asArray _ = []

asObject :: Json -> [(String, Json)]
asObject (JObject fields) = fields
asObject _ = []

equalJson :: Json -> Json -> Bool
equalJson (JObject a) (JObject b) =
    let left = Map.fromList a
        right = Map.fromList b
    in Map.keys left == Map.keys right && and (zipWith equalJson (Map.elems left) (Map.elems right))
equalJson (JArray a) (JArray b) = length a == length b && and (zipWith equalJson a b)
equalJson a b = a == b

parseJson :: String -> Either String Json
parseJson input
    | length input > 1048576 = Left "JSON_CAPACITY"
    | otherwise = case readP_to_S (space *> value 0 <* space <* eof) input of
        [(result, "")] -> Right result
        _ -> Left "JSON_INVALID"
  where
    space = skipMany (satisfy (`elem` " \t\r\n"))
    token parser = parser <* space
    value :: Int -> ReadP Json
    value depth = do
        guard (depth <= 64)
        choice
            [ JObject <$> between (token (char '{')) (char '}')
                (sepBy ((,) <$> token stringValue <* token (char ':') <*> token (value (depth + 1))) (token (char ',')))
            , JArray <$> between (token (char '[')) (char ']')
                (sepBy (token (value (depth + 1))) (token (char ',')))
            , JString <$> stringValue
            , JBool True <$ string "true"
            , JBool False <$ string "false"
            , JNull <$ string "null"
            , JNumber <$> numberValue
            ]

stringValue :: ReadP String
stringValue = between (char '"') (char '"') (many character)
  where
    character = satisfy (\c -> c /= '"' && c /= '\\' && ord c >= 32 && scalar c) <++ escaped
    escaped = do
        _ <- char '\\'
        code <- get
        case lookup code [('"', '"'), ('\\', '\\'), ('/', '/'), ('b', '\b'), ('f', '\f'), ('n', '\n'), ('r', '\r'), ('t', '\t')] of
            Just result -> pure result
            Nothing -> do
                guard (code == 'u')
                first <- hexUnit
                if first >= 0xD800 && first <= 0xDBFF then do
                    _ <- string "\\u"
                    second <- hexUnit
                    guard (second >= 0xDC00 && second <= 0xDFFF)
                    pure (chr (0x10000 + (first - 0xD800) * 1024 + second - 0xDC00))
                else do
                    guard (first < 0xD800 || first > 0xDFFF)
                    pure (chr first)
    hexUnit = foldl (\n c -> n * 16 + digitToInt c) 0 <$> count 4 (satisfy isHexDigit)

scalar :: Char -> Bool
scalar c = ord c < 0xD800 || ord c > 0xDFFF

numberValue :: ReadP Rational
numberValue = do
    sign <- option 1 (-1 <$ char '-')
    whole <- string "0" <++ ((:) <$> satisfy (`elem` ['1'..'9']) <*> munch isDigit)
    fraction <- option "" (char '.' *> munch1 isDigit)
    power <- option 0 $ do
        _ <- satisfy (`elem` "eE")
        direction <- option 1 ((-1 <$ char '-') <++ (1 <$ char '+'))
        digits <- munch1 isDigit
        guard (length digits <= 4)
        pure (direction * read digits)
    guard (length whole + length fraction <= 4096 && abs power <= 4096)
    let coefficient = sign * read (whole ++ fraction)
        scale = power - length fraction
    pure (if scale >= 0 then (coefficient * 10 ^ scale) % 1 else coefficient % (10 ^ negate scale))

encodeJson :: Json -> Either String String
encodeJson value = do
    text <- render 0 value
    if length text > 1048576 then Left "JSON_CAPACITY" else Right text
  where
    render :: Int -> Json -> Either String String
    render depth _ | depth > 64 = Left "JSON_CAPACITY"
    render depth (JObject fields) = do
        entries <- mapM (\(key, item) -> do
            name <- quoted key
            body <- render (depth + 1) item
            pure (name ++ ":" ++ body)) fields
        pure ("{" ++ intercalate "," entries ++ "}")
    render depth (JArray items) = do
        entries <- mapM (render (depth + 1)) items
        pure ("[" ++ intercalate "," entries ++ "]")
    render _ (JString text) = quoted text
    render _ (JNumber number) = decimal number
    render _ (JBool flag) = Right (if flag then "true" else "false")
    render _ JNull = Right "null"
    quoted text
        | length text > 1048576 = Left "JSON_CAPACITY"
        | not (all scalar text) = Left "JSON_INVALID"
        | otherwise = Right ('"' : concatMap escape text ++ "\"")
    escape '"' = "\\\""
    escape '\\' = "\\\\"
    escape c | ord c < 32 = let digits = showHex (ord c) "" in "\\u" ++ replicate (4 - length digits) '0' ++ digits
    escape c = [c]

decimal :: Rational -> Either String String
decimal number = do
    let n = abs (numerator number)
        d = denominator number
        remove factor rest | rest `mod` factor == 0 = remove factor (rest `div` factor)
                           | otherwise = rest
    if remove 5 (remove 2 d) /= 1 then Left "JSON_NON_DECIMAL_NUMBER" else do
        tailDigits <- fractional 0 (n `mod` d) d
        let text = (if number < 0 then "-" else "") ++ show (n `div` d) ++
                   (if null tailDigits then "" else '.' : tailDigits)
        if length text > 16384 then Left "JSON_CAPACITY" else Right text
  where
    fractional :: Int -> Integer -> Integer -> Either String String
    fractional _ 0 _ = Right ""
    fractional countDigits _ _ | countDigits >= 8192 = Left "JSON_CAPACITY"
    fractional countDigits rest divisor = do
        let (digit, remaining) = (rest * 10) `divMod` divisor
        suffix <- fractional (countDigits + 1) remaining divisor
        pure (chr (ord '0' + fromInteger digit) : suffix)
