module Main where

import Praxo.Json (Json(..))
import Praxo.Runtime

main :: IO ()
main = do
  let all = newSink
      tool = newSink
      filtered = filterSink tool ["tool.call"]
      multi = multiSink [all, filtered]
      events = [ Event "run.started" "s1" Nothing JNull
               , Event "tool.call" "s1" Nothing JNull
               , Event "run.completed" "s1" Nothing JNull
               ]
      result = foldl (flip emitSink) multi events
  if sinkKindLists result ==
      [["run.started", "tool.call", "run.completed"], ["tool.call"]]
    then putStrLn "Haskell event sink example passed"
    else error "unexpected event delivery"
