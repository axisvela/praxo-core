module Praxo.Mcp (McpTransport(..), McpClient(..), mcpClient, mcpListTools, mcpCallTool, mcpClose) where

import Data.IORef
import Praxo.Agent (AgentError(..))
import Praxo.Json

newtype McpTransport = McpTransport (String -> Json -> IO (Either AgentError Json))

data McpClient = McpClient
    { mcpTransport :: McpTransport
    , mcpClientVersion :: String
    , mcpProtocolVersion :: String
    , mcpServerInfo :: Json
    , mcpClosed :: IORef Bool
    }

mcpClient :: McpTransport -> String -> String -> IO (Either AgentError McpClient)
mcpClient transport clientVersion protocolVersion = do
    let version = if null clientVersion then "0.4.0" else clientVersion
        protocol = if null protocolVersion then "2024-11-05" else protocolVersion
        params = JObject
            [ ("protocolVersion", JString protocol)
            , ("capabilities", JObject [])
            , ("clientInfo", JObject
                [ ("name", JString "praxo-core")
                , ("version", JString version)
                ])
            ]
    result <- invoke transport "initialize" params
    case result of
        Left err -> pure (Left err)
        Right value -> case value of
            JObject _ ->
                let negotiated = asString (field "protocolVersion" value)
                in if null negotiated
                    then pure (Left (AgentError "MCP_HANDSHAKE" "mcp: initialize returned no protocol version"))
                    else do
                        closed <- newIORef False
                        let info = case field "serverInfo" value of
                                JObject _ -> field "serverInfo" value
                                _ -> JObject []
                        pure (Right (McpClient transport version negotiated info closed))
            _ -> pure (Left (AgentError "MCP_PROTOCOL" "mcp: initialize result must be an object"))

mcpListTools :: McpClient -> IO (Either AgentError [Json])
mcpListTools client = loop "" [] [] []
  where
    loop cursor tools names cursors = do
        let params = if null cursor then JObject [] else JObject [("cursor", JString cursor)]
        result <- invoke (mcpTransport client) "tools/list" params
        case result of
            Left err -> pure (Left err)
            Right value -> case field "tools" value of
                JArray items -> case collect items tools names of
                    Left err -> pure (Left err)
                    Right (updatedTools, updatedNames) ->
                        case field "nextCursor" value of
                            JNull -> pure (Right updatedTools)
                            JString next
                                | null next -> pure (Right updatedTools)
                                | next `elem` cursors -> pure (Left (AgentError "MCP_PAGINATION" "mcp: repeated tool pagination cursor"))
                                | otherwise -> loop next updatedTools updatedNames (next : cursors)
                            _ -> pure (Left (AgentError "MCP_PROTOCOL" "mcp: nextCursor must be a string"))
                _ -> pure (Left (AgentError "MCP_PROTOCOL" "mcp: tools/list tools must be an array"))
    collect [] tools names = Right (tools, names)
    collect (item:rest) tools names = case item of
        JObject _ ->
            let name = asString (field "name" item)
            in if null name
                then Left (AgentError "MCP_PROTOCOL" "mcp: tool name is required")
                else if name `elem` names
                    then Left (AgentError "MCP_DUPLICATE_TOOL" ("mcp: duplicate tool " ++ name))
                    else collect rest (tools ++ [item]) (name : names)
        _ -> Left (AgentError "MCP_PROTOCOL" "mcp: tool definition must be an object")

mcpCallTool :: McpClient -> String -> Json -> IO (Either AgentError Json)
mcpCallTool client name arguments
    | null name = pure (Left (AgentError "MCP_PROTOCOL" "mcp: tool name is required"))
    | otherwise = do
        result <- invoke (mcpTransport client) "tools/call"
            (JObject [("name", JString name), ("arguments", arguments)])
        case result of
            Left err -> pure (Left err)
            Right value -> case value of
                JObject _ ->
                    if field "isError" value == JBool True
                        then pure (Left (AgentError "MCP_TOOL_ERROR" ("mcp: tool " ++ name ++ " failed")))
                        else case lookup "structuredContent" (asObject value) of
                            Just structured -> pure (Right structured)
                            Nothing -> pure (Right (textContent (field "content" value)))
                _ -> pure (Left (AgentError "MCP_PROTOCOL" "mcp: tools/call result must be an object"))
  where
    textContent (JArray items) =
        case [asString (field "text" item) | item <- items, asString (field "type" item) == "text"] of
            [] -> JNull
            [text] -> JString text
            texts -> JArray (map JString texts)
    textContent _ = JNull

mcpClose :: McpClient -> IO ()
mcpClose client = writeIORef (mcpClosed client) True

invoke :: McpTransport -> String -> Json -> IO (Either AgentError Json)
invoke (McpTransport send) = send
