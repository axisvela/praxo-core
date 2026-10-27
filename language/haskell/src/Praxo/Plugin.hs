module Praxo.Plugin (parseManifest, validateManifest) where

import Control.Monad (unless)
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import qualified Data.Set as Set
import Data.Ratio (denominator)
import Praxo.Json

parseManifest :: String -> Either String Json
parseManifest raw = do
    manifest <- parseJson raw
    validateManifest manifest
    pure manifest

validateManifest :: Json -> Either String ()
validateManifest manifest = do
    strictObject topKeys manifest
    unless (all (`elem` map fst (asObject manifest)) requiredKeys) (Left "PLUGIN_MISSING_FIELD")
    unless (field "schemaVersion" manifest == JNumber 1) (Left "PLUGIN_SCHEMA_VERSION")
    identifier <- requiredString "id" manifest
    let labels = split '.' identifier
    unless (length labels >= 2 && all validLabel labels) (Left "PLUGIN_INVALID_ID")
    version <- requiredString "version" manifest
    unless (validVersion version) (Left "PLUGIN_INVALID_VERSION")
    kind <- requiredString "kind" manifest
    unless (kind `elem` [name ++ ".provider.v1" | name <- ["tool", "model", "policy", "memory", "sandbox"]]) (Left "PLUGIN_INVALID_KIND")
    protocol <- requiredString "protocol" manifest
    unless (protocol == "jsonrpc-2") (Left "PLUGIN_INVALID_PROTOCOL")
    let entrypoint = field "entrypoint" manifest
    strictObject ["type", "command", "module", "image", "args", "dir"] entrypoint
    launchType <- requiredString "type" entrypoint
    target <- case lookup launchType [("process", "command"), ("wasm", "module"), ("container", "image")] of
        Nothing -> Left "PLUGIN_INVALID_ENTRYPOINT"
        Just key -> requiredString key entrypoint
    unless (not (null target)) (Left "PLUGIN_INVALID_ENTRYPOINT")
    mapM_ (optionalString entrypoint) ["command", "module", "image", "dir"]
    optionalStrings entrypoint "args"
    isolation <- requiredString "isolation" manifest
    unless (isolation == launchType) (Left "PLUGIN_INVALID_ISOLATION")
    capabilities <- strings (field "capabilities" manifest)
    unless (all (not . null) capabilities && length capabilities == Set.size (Set.fromList capabilities)) (Left "PLUGIN_INVALID_CAPABILITIES")
    permissions (field "permissions" manifest)
    nonnegative ["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"] (field "limits" manifest)
    let health = field "health" manifest
    strictObject ["method", "intervalMs"] health
    optionalString health "method"
    interval <- optionalInteger health "intervalMs"
    unless (interval >= 0 && (interval == 0 || not (null (asString (field "method" health))))) (Left "PLUGIN_INVALID_HEALTH")
    case field "signature" manifest of
        JNull -> pure ()
        signature -> do
            strictObject ["algorithm", "keyId"] signature
            _ <- requiredString "algorithm" signature
            _ <- requiredString "keyId" signature
            pure ()
    optionalString manifest "sbom"
    let sbom = asString (field "sbom" manifest)
    unless (null sbom || relativePath sbom) (Left "PLUGIN_INVALID_SBOM")
  where
    requiredKeys = ["schemaVersion", "id", "version", "kind", "entrypoint", "protocol", "capabilities", "permissions", "limits", "health", "isolation"]
    topKeys = requiredKeys ++ ["signature", "sbom"]

strictObject :: [String] -> Json -> Either String ()
strictObject allowed (JObject fields) = do
    unless (all ((`elem` allowed) . fst) fields) (Left "PLUGIN_UNKNOWN_FIELD")
    unless (length fields == Set.size (Set.fromList (map fst fields))) (Left "PLUGIN_DUPLICATE_FIELD")
strictObject _ _ = Left "PLUGIN_EXPECTED_OBJECT"

requiredString :: String -> Json -> Either String String
requiredString key object = case field key object of
    JString value | not (null value) -> Right value
    _ -> Left ("PLUGIN_INVALID_STRING:" ++ key)

optionalString :: Json -> String -> Either String ()
optionalString object key
    | key `notElem` map fst (asObject object) = Right ()
    | otherwise = case field key object of
        JString _ -> Right ()
        _ -> Left ("PLUGIN_INVALID_STRING:" ++ key)

strings :: Json -> Either String [String]
strings (JArray values) = mapM stringItem values
  where
    stringItem (JString text) = Right text
    stringItem _ = Left "PLUGIN_EXPECTED_STRING"
strings _ = Left "PLUGIN_EXPECTED_ARRAY"

optionalStrings :: Json -> String -> Either String ()
optionalStrings object key
    | key `notElem` map fst (asObject object) = Right ()
    | otherwise = strings (field key object) >> pure ()

optionalInteger :: Json -> String -> Either String Integer
optionalInteger object key
    | key `notElem` map fst (asObject object) = Right 0
    | otherwise = case field key object of
        JNumber value | denominator value == 1 -> Right (round value)
        _ -> Left ("PLUGIN_INVALID_INTEGER:" ++ key)

nonnegative :: [String] -> Json -> Either String ()
nonnegative keys object = do
    strictObject keys object
    values <- mapM (optionalInteger object) keys
    unless (all (>= 0) values) (Left "PLUGIN_NEGATIVE_LIMIT")

permissions :: Json -> Either String ()
permissions object = do
    strictObject ["filesystem", "network", "env"] object
    optionalStrings object "env"
    env <- if field "env" object == JNull then Right [] else strings (field "env" object)
    unless (all validEnv env) (Left "PLUGIN_INVALID_ENV")
    entries "filesystem" object $ \entry -> do
        strictObject ["path", "mode"] entry
        path <- requiredString "path" entry
        mode <- requiredString "mode" entry
        unless (mode `elem` ["read", "write", "readwrite"] && ".." `notElem` split '/' (slashes path)) (Left "PLUGIN_INVALID_FILESYSTEM")
    entries "network" object $ \entry -> do
        strictObject ["host", "port"] entry
        _ <- requiredString "host" entry
        port <- optionalInteger entry "port"
        unless (port >= 1 && port <= 65535) (Left "PLUGIN_INVALID_NETWORK")
  where
    validEnv (first:rest) = (isAsciiLower first || isAsciiUpper first || first == '_') && all envChar rest
    validEnv [] = False
    envChar c = isAsciiLower c || isAsciiUpper c || isDigit c || c == '_'

entries :: String -> Json -> (Json -> Either String ()) -> Either String ()
entries key object check
    | key `notElem` map fst (asObject object) = Right ()
    | otherwise = case field key object of
        JArray values -> mapM_ check values
        _ -> Left "PLUGIN_EXPECTED_ARRAY"

split :: Char -> String -> [String]
split separator text = case break (== separator) text of
    (first, []) -> [first]
    (first, _:rest) -> first : split separator rest

validLabel :: String -> Bool
validLabel [] = False
validLabel label@(first:_) = alphaNumber first && alphaNumber (last label) && all (\c -> alphaNumber c || c == '-') label
  where alphaNumber c = isAsciiLower c || isDigit c

validVersion :: String -> Bool
validVersion text =
    let (baseAndPre, metadata) = break (== '+') text
        (base, prerelease) = break (== '-') baseAndPre
        numeric [] = False
        numeric part@(first:_) = all isDigit part && (part == "0" || first /= '0')
        suffix [] = True
        suffix (_:rest) = not (null rest) && all (\c -> isAsciiLower c || isAsciiUpper c || isDigit c || c `elem` ".-") rest
    in length (split '.' base) == 3 && all numeric (split '.' base) && suffix prerelease && suffix metadata

slashes :: String -> String
slashes = map (\c -> if c == '\\' then '/' else c)

relativePath :: String -> Bool
relativePath [] = False
relativePath path@(first:_) = first /= '/' && first /= '\\' && ':' `notElem` path && ".." `notElem` split '/' (slashes path)
