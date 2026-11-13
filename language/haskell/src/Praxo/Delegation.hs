module Praxo.Delegation
    ( SubagentRequest(..)
    , SubagentResult(..)
    , SubagentTask(..)
    , SubagentRunner
    , subagentRun
    ) where

import Control.Exception (SomeException, try)
import Praxo.Agent (AgentError(..))

data SubagentRequest = SubagentRequest
    { subagentParentSessionId :: String
    , subagentAgentId :: String
    , subagentPrompt :: String
    , subagentMode :: String
    } deriving (Eq, Show)

data SubagentResult = SubagentResult
    { subagentTaskId :: String
    , subagentResultAgentId :: String
    , subagentOutput :: String
    } deriving (Eq, Show)

data SubagentTask = SubagentTask
    { subagentTaskKey :: String
    , subagentParentSession :: String
    , subagentAgent :: String
    , subagentTaskMode :: String
    , subagentStatus :: String
    , subagentTaskOutput :: String
    , subagentTaskError :: String
    } deriving (Eq, Show)

type SubagentRunner = SubagentRequest -> IO (Either AgentError SubagentResult)

subagentRun :: SubagentRunner -> SubagentRequest -> IO (Either AgentError SubagentTask)
subagentRun runner request
    | null (subagentParentSessionId request) || null (subagentAgentId request) =
        pure (Left (AgentError "SUBAGENT_INVALID"
            "agent: subagent parent session and agent id are required"))
    | otherwise = do
        outcome <- try (runner request)
            :: IO (Either SomeException (Either AgentError SubagentResult))
        pure $ case outcome of
            Left error -> Right (failedTask (show error))
            Right (Left err) -> Right (failedTask (errorCode err ++ ": " ++ errorMessage err))
            Right (Right result) -> Right (completedTask result)
  where
    base = SubagentTask
        { subagentTaskKey = "subagent"
        , subagentParentSession = subagentParentSessionId request
        , subagentAgent = subagentAgentId request
        , subagentTaskMode = if subagentMode request == "fork" then "fork" else "isolated"
        , subagentStatus = "running"
        , subagentTaskOutput = ""
        , subagentTaskError = ""
        }
    completedTask result = base
        { subagentStatus = "completed"
        , subagentTaskOutput = subagentOutput result
        }
    failedTask detail = base
        { subagentStatus = "failed"
        , subagentTaskError = detail
        }
