module HitlExample
    ( ScenarioResult(..)
    , approveScenario
    , editScenario
    , runExample
    ) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Maybe (isNothing)

import Praxo.Agent
import Praxo.Json

data ScenarioResult = ScenarioResult
    { scenarioOutput :: String
    , scenarioError :: Maybe AgentError
    , scenarioEffects :: Int
    } deriving (Eq, Show)

data Fixture = Fixture

generateFixture :: Fixture -> [Message] -> IO (Either AgentError Response)
generateFixture _ messages = pure $ case reverse messages of
    (lastMessage:_)
        | messageRole lastMessage == "tool" ->
            Right (Response "done" [] 0 0)
    _ -> Right (Response "" [ToolCall "write-note-1" "write_note" (noteArguments "public")] 0 0)

noteArguments :: String -> Json
noteArguments visibility = JObject
    [ ("text", JString "hello")
    , ("visibility", JString visibility)
    ]

notePolicy :: Action -> Bool
notePolicy action
    | actionKind action == "model.generate" = True
    | actionKind action == "tool.invoke" =
        actionToolName action == "write_note"
            && asString (field "visibility" (actionArguments action)) == "public"
    | otherwise = False

runScenario :: String -> InterruptDecision -> IO ScenarioResult
runScenario session decision = do
    effects <- newIORef 0
    let tool _ = modifyIORef' effects (+ 1) >> pure (Right (JString "written"))
        options = AgentOptions
            { generate = generateFixture Fixture
            , invoke = tool
            , emit = \_ -> pure (Right ())
            , maxSteps = 3
            , maxTokens = 0
            , policy = Just notePolicy
            , allowedTools = ["write_note"]
            , requirePolicy = True
            , requireToolScope = True
            , runId = "run-" ++ session
            , sessionId = session
            , interruptOn = ["write_note"]
            , onInterruptDecision = Just (\_ -> pure decision)
            , onInterrupt = Nothing
            , beforeTool = Nothing
            , onDelta = Nothing
            , generateStream = Nothing
            }
    result <- runAgent options [] "Write a note."
    count <- readIORef effects
    pure $ case result of
        Left err -> ScenarioResult "" (Just err) count
        Right value -> ScenarioResult (runOutput value) Nothing count

approveScenario :: IO ScenarioResult
approveScenario =
    runScenario "hitl-approve" (InterruptDecision interruptApprove Nothing "" "")

editScenario :: IO ScenarioResult
editScenario =
    runScenario "hitl-edit" (InterruptDecision interruptEdit (Just (noteArguments "private")) "" "")

runExample :: IO ()
runExample = do
    approved <- approveScenario
    if isNothing (scenarioError approved)
        && scenarioOutput approved == "done"
        && scenarioEffects approved == 1
        then putStrLn "approve: written; effects=1"
        else ioError (userError ("approve scenario failed: output="
            ++ show (scenarioOutput approved) ++ " effects="
            ++ show (scenarioEffects approved) ++ " error="
            ++ show (scenarioError approved)))
    edited <- editScenario
    case scenarioError edited of
        Just err | errorCode err == "AGENT_POLICY_DENIED" && scenarioEffects edited == 0 ->
            putStrLn "edit: policy rejected; effects=0"
        _ -> ioError (userError ("edit scenario failed: effects="
            ++ show (scenarioEffects edited) ++ " error="
            ++ show (scenarioError edited)))
