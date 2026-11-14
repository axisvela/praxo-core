module Main where

import Data.List (isInfixOf)

handle :: String -> String -> String -> String -> (Int, String)
handle method path principal body
  | method == "GET" && path == "/healthz" = (200, "{\"status\":\"ok\"}")
  | method /= "POST" || path /= "/run" = (404, "{\"error\":\"not found\"}")
  | null principal = (401, "{\"error\":\"missing X-Praxo-Principal\"}")
  | not ("\"prompt\"" `isInfixOf` body) = (400, "{\"error\":\"prompt is required\"}")
  | otherwise = (200, "{\"output\":\"hello from the service\"}")

main :: IO ()
main = do
  if fst (handle "GET" "/healthz" "" "") /= 200 then error "health failed" else pure ()
  if fst (handle "POST" "/run" "" "{\"prompt\":\"hi\"}") /= 401 then error "missing principal" else pure ()
  if fst (handle "POST" "/run" "user-1" "{\"prompt\":\"hi\"}") /= 200 then error "run failed" else pure ()
  putStrLn "Haskell service example passed"
