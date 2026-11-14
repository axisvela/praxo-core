module Main where

runRetry :: Int -> Int -> Either (String, Int) (String, Int)
runRetry failures maxAttempts = go 1
  where
    go attempt
      | attempt > failures = Right ("status: green", attempt)
      | attempt == maxAttempts = Left ("MODEL_UNAVAILABLE", attempt)
      | otherwise = go (attempt + 1)

main :: IO ()
main = do
  case runRetry 2 3 of
    Right ("status: green", 3) -> pure ()
    _ -> error "transient retry failed"
  case runRetry 3 3 of
    Left ("MODEL_UNAVAILABLE", 3) -> putStrLn "Haskell retry example passed"
    _ -> error "exhausted retry failed"
