module Main (main) where

import Control.Monad (forM, unless)
import Data.List (sort)
import Praxo.Json
import Praxo.JsonSchema
import Praxo.Plugin
import Praxo.ToolCall
import Praxo.Wire
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (IOMode(ReadMode), hGetContents, hSetEncoding, utf8, withFile)

main :: IO ()
main = do
    arguments <- getArgs
    spec <- case arguments of
        [path] -> pure path
        _ -> fail "usage: praxo-haskell-conformance <spec-directory>"
    failures <- fmap concat $ forM ["toolcall", "jsonschema", "plugin"] $ \group -> do
        withFile (spec ++ "/vectors/" ++ group ++ ".json") ReadMode $ \handle -> do
            hSetEncoding handle utf8
            text <- hGetContents handle
            fixture <- either fail pure (parseJson text)
            unless (field "specVersion" fixture == JString specVersion && field "group" fixture == JString group)
                (fail "unsupported fixture contract or group")
            let vectors = asArray (field "vectors" fixture)
            unless (not (null vectors)) (fail "empty vector group")
            forM vectors $ \vector -> do
                let name = asString (field "id" vector)
                    result = checkVector group (field "input" vector) (field "expect" vector)
                case result of
                    Right () -> putStrLn ("PASS " ++ name) >> pure []
                    Left message -> pure [name ++ ": " ++ message]
    let errors = concat failures
    unless (null errors) (mapM_ putStrLn errors >> exitFailure)
    putStrLn "All declared wire vector groups passed"

checkVector :: String -> Json -> Json -> Either String ()
checkVector "toolcall" input expected
    | field "operation" input == JString "strip" =
        check (stripToolCallMarkup content == asString (field "text" expected)) "stripped text mismatch"
    | field "operation" input == JString "parse" = case parseToolCall content of
        Nothing -> check (field "nil" expected == JBool True) "expected a tool call"
        Just call -> do
            check (field "nil" expected /= JBool True) "unexpected tool call"
            check (callName call == asString (field "name" expected)) "name mismatch"
            check (equalJson (callInput call) (field "input" expected)) "input mismatch"
    | otherwise = Left "unknown toolcall operation"
  where content = asString (field "content" input)
checkVector "jsonschema" input expected = do
    errors <- validateSchema (field "schema" input) (field "data" input)
    check (null errors == (field "valid" expected == JBool True)) "validation result mismatch"
    check (sort (map errorPath errors) == sort (map asString (asArray (field "errorPaths" expected)))) "validation paths mismatch"
checkVector "plugin" input expected = do
    raw <- case field "raw" input of
        JString text -> Right text
        _ -> encodeJson (field "manifest" input)
    case parseManifest raw of
        Left _ -> check (field "valid" expected == JBool False) "manifest unexpectedly rejected"
        Right manifest -> do
            check (field "valid" expected == JBool True) "manifest unexpectedly accepted"
            mapM_ (\key -> unless (field key expected == JNull) (check (field key manifest == field key expected) (key ++ " mismatch"))) ["id", "kind"]
checkVector _ _ _ = Left "unsupported vector group"

check :: Bool -> String -> Either String ()
check True _ = Right ()
check False message = Left message
