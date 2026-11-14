module Main where

import Praxo.Json (parseJson)
import Praxo.JsonSchema (validateSchema)

main :: IO ()
main = do
  let schema = parseJson "{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}"
      valid = parseJson "{\"name\":\"ok\"}"
      invalid = parseJson "{}"
  case (schema, valid, invalid) of
    (Right definition, Right good, Right bad) -> do
      case validateSchema definition good of
        Right [] -> pure ()
        _ -> error "valid output was rejected"
      case validateSchema definition bad of
        Right (_ : _) -> putStrLn "Haskell structured output example passed"
        _ -> error "invalid output was accepted"
    _ -> error "invalid fixture JSON"
