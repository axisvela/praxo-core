module Main where

main :: IO ()
main = do
  let chunks = ["status: ", "green"]
      output = concat chunks
  if output == "status: green" && concat chunks == output
    then putStrLn "Haskell streaming example passed"
    else error "deltas did not reconstruct the output"
