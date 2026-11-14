module Main where

authorize :: String -> String -> Bool -> String -> String -> Bool
authorize tenant role active tool target =
  active && role == "operator" && tenant == target && tool == "record"

main :: IO ()
main = do
  if not (authorize "acme" "operator" True "record" "acme") then error "operator denied" else pure ()
  if authorize "acme" "viewer" True "record" "acme" then error "viewer allowed" else pure ()
  if authorize "acme" "operator" True "record" "other" then error "tenant mismatch" else pure ()
  putStrLn "Haskell identity policy example passed"
