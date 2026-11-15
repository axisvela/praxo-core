module Main where

import Data.Maybe (isNothing)

import HitlExample (ScenarioResult(..), approveScenario, editScenario)
import Praxo.Agent (AgentError(..))

main :: IO ()
main = do
    approved <- approveScenario
    if isNothing (scenarioError approved)
        && scenarioOutput approved == "done"
        && scenarioEffects approved == 1
        then pure ()
        else error ("HITL approve scenario failed: " ++ show approved)
    edited <- editScenario
    case scenarioError edited of
        Just err | errorCode err == "AGENT_POLICY_DENIED" && scenarioEffects edited == 0 ->
            pure ()
        _ -> error ("HITL edit scenario failed: " ++ show edited)
    putStrLn "Haskell HITL example test passed"
