module Praxo.Retriever
    ( Document(..)
    , Retriever
    , newRetriever
    , retrieveDocuments
    ) where

import Praxo.Agent (AgentError(..))

data Document = Document
    { documentId :: String
    , documentContent :: String
    , documentMetadata :: [(String, String)]
    , documentScore :: Double
    } deriving (Eq, Show)

type Retriever = String -> Int -> IO (Either AgentError [Document])

newRetriever :: (String -> Int -> IO (Either AgentError [Document])) -> Retriever
newRetriever = id

retrieveDocuments :: Retriever -> String -> Int -> IO (Either AgentError [Document])
retrieveDocuments retriever query limit
    | limit < 0 = pure (Left (AgentError "RETRIEVER_INVALID" "retriever: invalid limit"))
    | otherwise = retriever query limit
