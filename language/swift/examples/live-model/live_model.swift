import Foundation
import PraxoCore

#if canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#else
import Darwin
#endif

let getTimeSchema: [String: Any] = [
    "type": "object",
    "properties": [
        "zone": [
            "type": "string",
            "enum": ["utc", "local"],
            "description": "utc or local; defaults to utc",
        ],
    ],
]

final class GetTimeTool: Tool {
    let name = "get_time"
    let description = "Return the current time in ISO 8601 format for the requested zone."

    func invoke(_ arguments: [String: Any]) throws -> Any {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = (arguments["zone"] as? String) == "local"
            ? TimeZone.current
            : TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}

final class SchemaModel: Model {
    private let base: OpenAICompatibleModel

    init(_ base: OpenAICompatibleModel) {
        self.base = base
    }

    func generate(_ request: Request) throws -> Response {
        var request = request
        request.tools = request.tools.map { tool in
            tool.name == "get_time"
                ? ToolSpec(
                    name: tool.name,
                    description: tool.description,
                    parameters: getTimeSchema,
                    risk: "read"
                )
                : tool
        }
        return try base.generate(request)
    }
}

struct LivePolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" {
            return Decision(allowed: true, reason: "model generation")
        }
        if action.kind == "tool.invoke" {
            return Decision(
                allowed: action.toolName == "get_time",
                reason: "only get_time is permitted"
            )
        }
        return Decision(allowed: false, reason: "unsupported action")
    }
}

func envOr(_ name: String, _ fallback: String) -> String {
    let value = ProcessInfo.processInfo.environment[name]
    return value == nil || value!.isEmpty ? fallback : value!
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let baseURL = envOr("PRAXO_BASE_URL", "http://localhost:11434/v1")
let modelName = envOr("PRAXO_MODEL", "qwen3.5:4b")
let apiKey = envOr("PRAXO_API_KEY", "")
let prompt = envOr(
    "PRAXO_PROMPT",
    "What time is it? Use get_time with zone set to utc and reply with the time."
)

let config = OpenAICompatibleConfig(
    baseURL: baseURL,
    model: modelName,
    apiKey: apiKey.isEmpty ? nil : apiKey
)
let registry = ToolRegistry()
registry.register(GetTimeTool())
let options = AgentOptions(SchemaModel(OpenAICompatibleModel(config)))
options.tools = registry
options.systemPrompt = "You are a concise assistant. Use the provided tools when they help."
options.maxSteps = 4
options.allowedTools = ["get_time"]
options.policy = LivePolicy()

do {
    let result = try Agent(options).run(Session(id: "live-model"), prompt)
    print(result.output)
} catch {
    fail(
        "live model run failed: \(error)\n\n"
            + "Check PRAXO_BASE_URL (\(baseURL)), PRAXO_MODEL (\(modelName)), and PRAXO_API_KEY"
    )
}
