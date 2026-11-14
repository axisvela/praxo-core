module Main where

import Praxo.Json (Json(..), asArray, asString, field)
import qualified Praxo.Mcp as M

transport :: M.McpTransport
transport = M.McpTransport $ \method _params -> pure $ case method of
  "initialize" -> Right (JObject [("protocolVersion", JString "2024-11-05"), ("serverInfo", JObject [("name", JString "example-mcp")])])
  "tools/list" -> Right (JObject [("tools", JArray
    [ JObject [("name", JString "echo"), ("inputSchema", JObject [("type", JString "object")])]
    , JObject [("name", JString "add"), ("inputSchema", JObject [("type", JString "object")])]
    ])])
  "tools/call" -> Right (JObject [("structuredContent", JObject [("sum", JNumber 5)])])
  _ -> Right (JObject [])

main :: IO ()
main = do
  result <- M.mcpClient transport "" ""
  case result of
    Left error_value -> fail (show error_value)
    Right client -> do
      tools <- M.mcpListTools client
      case tools of
        Left error_value -> fail (show error_value)
        Right items -> do
          if map (asString . field "name") items /= ["echo", "add"] then error "unexpected tools" else pure ()
          value <- M.mcpCallTool client "add" (JObject [])
          if value /= Right (JObject [("sum", JNumber 5)]) then error "unexpected result" else pure ()
      M.mcpClose client
      putStrLn "Haskell MCP example passed"
