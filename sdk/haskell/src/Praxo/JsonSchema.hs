module Praxo.JsonSchema (ValidationError(..), validateSchema) where

import Data.List (sortOn)
import Data.Ratio (denominator)
import Praxo.Json
import Praxo.Pattern

data ValidationError = ValidationError { errorPath :: String, errorMessage :: String } deriving (Eq, Show)

validateSchema :: Json -> Json -> Either String [ValidationError]
validateSchema schema = validate 0 "$" schema
  where
    validate :: Int -> String -> Json -> Json -> Either String [ValidationError]
    validate depth path definition value
        | depth > 64 = Left "SCHEMA_CAPACITY"
        | otherwise = case definition of
            JObject _ -> do
                checkShape depth definition
                let kind = asString (field "type" definition)
                if kind `notElem` ["", "object", "array", "string", "number", "integer", "boolean", "null"]
                    then Left "SCHEMA_TYPE_UNSUPPORTED"
                    else if not (matches kind value) then pure [ValidationError path ("expected " ++ kind)] else do
                        details <- case value of
                            JObject properties -> do
                                required <- mapM (requiredProperty value path) (asArray (field "required" definition))
                                children <- mapM (child depth path value properties) (sortOn fst (asObject (field "properties" definition)))
                                pure (concat required ++ concat children)
                            JArray items -> do
                                children <- case field "items" definition of
                                    JNull -> Right []
                                    itemSchema -> concat <$> mapM (\(index, item) -> validate (depth + 1) (path ++ "[" ++ show index ++ "]") itemSchema item) (zip [0 :: Int ..] items)
                                pure (bounds definition path "minItems" "maxItems" (fromIntegral (length items)) ++ children)
                            JString text -> do
                                patternErrors <- case field "pattern" definition of
                                    JNull -> Right []
                                    JString patternText -> do
                                        valid <- matchPattern patternText text
                                        pure [ValidationError path "pattern mismatch" | not valid]
                                    _ -> Left "SCHEMA_INVALID_PATTERN"
                                pure (bounds definition path "minLength" "maxLength" (fromIntegral (length text)) ++ patternErrors)
                            JNumber number -> pure (bounds definition path "minimum" "maximum" number)
                            _ -> pure []
                        let choices = asArray (field "enum" definition)
                            enumErrors = [ValidationError path "not in enum" | not (null choices) && not (any (equalJson value) choices)]
                        pure (enumErrors ++ details)
            _ -> Left "SCHEMA_INVALID"
    requiredProperty value path (JString key)
        | key `elem` map fst (asObject value) = Right []
        | otherwise = Right [ValidationError (path ++ "." ++ key) "required"]
    requiredProperty _ _ _ = Left "SCHEMA_INVALID_REQUIRED"
    child depth path value properties (key, definition)
        | key `elem` map fst properties = validate (depth + 1) (path ++ "." ++ key) definition (field key value)
        | otherwise = Right []
    matches "" _ = True
    matches "object" (JObject _) = True
    matches "array" (JArray _) = True
    matches "string" (JString _) = True
    matches "number" (JNumber _) = True
    matches "integer" (JNumber number) = denominator number == 1
    matches "boolean" (JBool _) = True
    matches "null" JNull = True
    matches _ _ = False
    bounds definition path low high number =
        [ValidationError path "below minimum" | JNumber limit <- [field low definition], limit /= 0, number < limit] ++
        [ValidationError path "above maximum" | JNumber limit <- [field high definition], limit /= 0, number > limit]
    checkShape level _ | level > 64 = Left "SCHEMA_CAPACITY"
    checkShape level definition = mapM_ (checkField level) (asObject definition)
    checkField level (key, value)
        | key `elem` ["type", "description", "pattern"] = case value of
            JString _ -> Right ()
            _ -> Left ("SCHEMA_INVALID_FIELD:" ++ key)
        | key `elem` ["minimum", "maximum"] = case value of
            JNumber _ -> Right ()
            _ -> Left ("SCHEMA_INVALID_FIELD:" ++ key)
        | key `elem` ["minLength", "maxLength", "minItems", "maxItems"] = case value of
            JNumber limit | denominator limit == 1 && limit >= 0 -> Right ()
            _ -> Left ("SCHEMA_INVALID_FIELD:" ++ key)
        | key == "required" = case value of
            JArray values | all isString values -> Right ()
            _ -> Left "SCHEMA_INVALID_REQUIRED"
        | key == "properties" = case value of
            JObject values -> mapM_ (checkDefinition (level + 1) . snd) values
            _ -> Left "SCHEMA_INVALID_PROPERTIES"
        | key == "items" = checkDefinition (level + 1) value
        | key == "enum" = case value of
            JArray _ -> Right ()
            _ -> Left "SCHEMA_INVALID_ENUM"
        | otherwise = Right ()
    checkDefinition level value@(JObject _) = checkShape level value
    checkDefinition _ _ = Left "SCHEMA_INVALID"
    isString (JString _) = True
    isString _ = False
