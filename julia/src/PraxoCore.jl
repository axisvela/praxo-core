module PraxoCore

include("Json.jl")
include("ToolCall.jl")
include("JsonSchema.jl")
include("Plugin.jl")

export Json, ParsedToolCall, ToolCallParser
export ValidationError, JsonSchema
export PluginManifest, Plugin

end
