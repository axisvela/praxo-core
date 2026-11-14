module Main where

runFallback :: Bool -> Bool -> String
runFallback primaryFails fallbackFails
  | not primaryFails = "primary"
  | not fallbackFails = "fallback"
  | otherwise = "MODEL_UNAVAILABLE"

main :: IO ()
main = do
  if runFallback False False /= "primary" then error "primary path failed" else pure ()
  if runFallback True False /= "fallback" then error "fallback path failed" else pure ()
  if runFallback True True /= "MODEL_UNAVAILABLE" then error "both-failure path failed" else pure ()
  putStrLn "Haskell provider fallback example passed"
