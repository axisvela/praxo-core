import Foundation

public final class PiiRedactor {
    private let rules: [(NSRegularExpression, String)]

    public init() {
        let patterns: [(String, String)] = [
            ("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "[REDACTED:email]"),
            ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED:ssn]"),
            ("\\b(?:\\d{4}[ -]?){3}\\d{4}\\b", "[REDACTED:credit_card]"),
        ]
        rules = patterns.compactMap {
            guard let regex = try? NSRegularExpression(pattern: $0.0) else { return nil }
            return (regex, $0.1)
        }
    }

    public func redact(_ text: String) -> String {
        var output = text
        for (regex, replacement) in rules {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: replacement)
        }
        return output
    }

    public func redactValue(_ value: Any?) -> Any? {
        if let text = value as? String { return redact(text) }
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues { redactValue($0) }
        }
        if let array = value as? [Any] { return array.map { redactValue($0) } }
        return value
    }
}

public final class StructuredOutput {
    public let schema: [String: Any]
    public let maxRepairs: Int
    public var repairer: ((String) -> String?)?

    public init(schema: [String: Any], maxRepairs: Int = 0) {
        self.schema = schema
        self.maxRepairs = maxRepairs
    }

    public func apply(_ text: String) -> (String?, String?) {
        var output = text
        for attempt in 0...maxRepairs {
            if let data = try? extractJSON(output),
               JsonSchema.validate(schema, data).isEmpty {
                return (output, nil)
            }
            if attempt == maxRepairs, repairer == nil { break }
            guard let repaired = repairer?(output) else { break }
            if repaired.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            output = repaired
        }
        return (nil, "AGENT_STRUCTURED_OUTPUT")
    }

    public static func extractJSON(_ text: String) throws -> Any {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            if let newline = value.firstIndex(of: "\n") {
                value = String(value[value.index(after: newline)...])
            }
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "` \n\r"))
        }
        guard let start = value.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            throw JsonError.invalid("output does not contain JSON")
        }
        return try Json.parse(String(value[start...]))
    }

    private func extractJSON(_ text: String) throws -> Any { try Self.extractJSON(text) }
}

public final class CallLimit {
    private let modelLimit: Int
    private let toolLimit: Int
    private var models = 0
    private var tools = 0

    public init(modelLimit: Int, toolLimit: Int) {
        self.modelLimit = modelLimit
        self.toolLimit = toolLimit
    }

    public func beforeModel() throws {
        models += 1
        if modelLimit > 0 && models > modelLimit {
            throw PraxoError("AGENT_MODEL_CALL_LIMIT", "model call limit")
        }
    }

    public func beforeTool() throws {
        tools += 1
        if toolLimit > 0 && tools > toolLimit {
            throw PraxoError("AGENT_TOOL_CALL_LIMIT", "tool call limit")
        }
    }
}

public protocol ToolSelector {
    func select(_ query: String, _ tools: [ToolSpec]) -> [String]
}

public final class ToolSelection {
    private let selected: Set<String>

    public init(_ selected: [String]) {
        self.selected = Set(selected)
    }

    public func filter(_ tools: [ToolSpec]) -> [ToolSpec] {
        tools.filter { selected.contains($0.name) }
    }

    public func reject(_ name: String) throws {
        if !selected.contains(name) {
            throw PraxoError("AGENT_TOOL_NOT_SELECTED", "tool not selected")
        }
    }
}

public typealias ModelHandler = (Request) throws -> Response
public typealias ModelMiddleware = (@escaping ModelHandler) -> ModelHandler

public enum Fallback {
    public static func wrap(_ fallback: (any Model)?) -> ModelMiddleware {
        return { (next: @escaping ModelHandler) -> ModelHandler in
            return { request in
                do {
                    return try next(request)
                } catch {
                    guard let fallback = fallback else { throw error }
                    do { return try fallback.generate(request) } catch { throw error }
                }
            }
        }
    }
}
