module Main where

import Praxo.Json (Json(..), equalJson)
import Praxo.Runtime

main :: IO ()
main = do
  let allow = newCheckpoint
      registered = registerCheckpoint allow "order"
      value = JObject [("value", JString "x")]
  case registered of
    Left code -> error code
    Right ready -> case checkpointMarshal ready "order" value of
      Left code -> error code
      Right data' -> case checkpointUnmarshal ready data' of
        Left code -> error code
        Right decoded
          | equalJson decoded value -> putStrLn "Haskell checkpoint example passed"
          | otherwise -> error "checkpoint payload did not round trip"
