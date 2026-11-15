module Main where

import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)

import Praxo.Agent
import Praxo.Json (Json(..), asArray, asString, field)
import Praxo.Runtime
    ( checkpointMarshal
    , checkpointUnmarshal
    , newCheckpoint
    , registerCheckpoint
    )

data Checkpoint = Checkpoint
    { checkpointId :: String
    , checkpointSessionId :: String
    , checkpointRunId :: String
    , checkpointStatus :: String
    , checkpointMessages :: [Message]
    } deriving (Eq, Show)

type MemoryStore = Map.Map String String

saveCheckpoint :: [String] -> MemoryStore -> Checkpoint -> Either String MemoryStore
saveCheckpoint allowlist store checkpoint = do
    encoded <- checkpointMarshal allowlist "session" (checkpointJson checkpoint)
    Right (Map.insert (checkpointSessionId checkpoint) encoded store)

loadCheckpoint :: [String] -> MemoryStore -> String -> Either String (Maybe Checkpoint)
loadCheckpoint allowlist store sessionId =
    case Map.lookup sessionId store of
        Nothing -> Right Nothing
        Just encoded -> do
            payload <- checkpointUnmarshal allowlist encoded
            checkpoint <- checkpointFromJson payload
            Right (Just checkpoint)

checkpointJson :: Checkpoint -> Json
checkpointJson checkpoint = JObject
    [ ("id", JString (checkpointId checkpoint))
    , ("sessionId", JString (checkpointSessionId checkpoint))
    , ("runId", JString (checkpointRunId checkpoint))
    , ("status", JString (checkpointStatus checkpoint))
    , ("messages", JArray (map messageJson (checkpointMessages checkpoint)))
    ]

checkpointFromJson :: Json -> Either String Checkpoint
checkpointFromJson value =
    Checkpoint
        <$> required "id" value
        <*> required "sessionId" value
        <*> required "runId" value
        <*> required "status" value
        <*> mapM messageFromJson (asArray (field "messages" value))

required :: String -> Json -> Either String String
required key value =
    case asString (field key value) of
        "" -> Left ("CHECKPOINT_ERROR: missing " ++ key)
        text -> Right text

messageJson :: Message -> Json
messageJson message = JObject
    [ ("role", JString (messageRole message))
    , ("content", JString (messageContent message))
    , ("toolCalls", JArray
        [ JObject
            [ ("id", JString (toolCallId call))
            , ("name", JString (toolCallName call))
            , ("arguments", toolCallArguments call)
            ]
        | call <- messageToolCalls message
        ])
    , ("toolCallId", JString (messageToolCallId message))
    ]

messageFromJson :: Json -> Either String Message
messageFromJson value =
    case asString (field "role" value) of
        "" -> Left "CHECKPOINT_ERROR: message role is required"
        role -> Right Message
            { messageRole = role
            , messageContent = asString (field "content" value)
            , messageToolCalls = mapMaybe parseCall (asArray (field "toolCalls" value))
            , messageToolCallId = asString (field "toolCallId" value)
            }

parseCall :: Json -> Maybe ToolCall
parseCall value =
    case asString (field "name" value) of
        "" -> Nothing
        name -> Just ToolCall
            { toolCallId = asString (field "id" value)
            , toolCallName = name
            , toolCallArguments = field "arguments" value
            }

turnModel :: [Message] -> IO (Either AgentError Response)
turnModel messages = pure (Right Response
    { responseContent = "turn " ++ show (length messages)
    , responseToolCalls = []
    , inputTokens = 0
    , outputTokens = 0
    })

options :: AgentOptions
options = AgentOptions
    { generate = turnModel
    , invoke = \_ -> pure (Left (AgentError "TOOL_ERROR" "no tools"))
    , emit = \_ -> pure (Right ())
    , maxSteps = 2
    , maxTokens = 0
    , policy = Nothing
    , allowedTools = []
    , requirePolicy = False
    , requireToolScope = False
    }

main :: IO ()
main = do
    allowlist <- case registerCheckpoint newCheckpoint "session" of
        Left code -> error code
        Right value -> pure value
    let initial =
            [ Message "user" "first" [] ""
            , Message "assistant" "ack" [] ""
            ]
    store1 <- either error pure (saveCheckpoint allowlist Map.empty
        (Checkpoint "cp-1" "session-1" "run-1" "completed" initial))
    loaded1 <- either error pure (loadCheckpoint allowlist store1 "session-1")
    checkpoint1 <- case loaded1 of
        Nothing -> error "checkpoint not found"
        Just checkpoint -> pure checkpoint
    result1 <- runAgent options (checkpointMessages checkpoint1) "second"
    output1 <- either (error . errorMessage) (pure . runOutput) result1
    if output1 /= "turn 3"
        then error ("unexpected second turn: " ++ show output1)
        else pure ()
    let updated = checkpointMessages checkpoint1 ++
            [ Message "user" "second" [] ""
            , Message "assistant" output1 [] ""
            ]
    store2 <- either error pure (saveCheckpoint allowlist store1
        (Checkpoint "cp-2" "session-1" "run-2" "completed" updated))
    loaded2 <- either error pure (loadCheckpoint allowlist store2 "session-1")
    checkpoint2 <- case loaded2 of
        Nothing -> error "checkpoint not found"
        Just checkpoint -> pure checkpoint
    result2 <- runAgent options (checkpointMessages checkpoint2) "third"
    output2 <- either (error . errorMessage) (pure . runOutput) result2
    if output2 /= "turn 5"
        then error ("unexpected third turn: " ++ show output2)
        else pure ()
    putStrLn ("restored messages: " ++ show (length (checkpointMessages checkpoint2)))
    putStrLn ("output: " ++ output2)
