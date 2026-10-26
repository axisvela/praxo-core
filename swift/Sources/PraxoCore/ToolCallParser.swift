import Foundation

public struct ParsedToolCall {
    public var callId: String
    public var name: String
    public var input: [String: Any]
    public var operation: String
    public var resource: String
    public var risk: String
    public var reason: String
    public var idempotencyKey: String

    public init(
        callId: String = "",
        name: String = "",
        input: [String: Any] = [:],
        operation: String = "",
        resource: String = "",
        risk: String = "",
        reason: String = "",
        idempotencyKey: String = ""
    ) {
        self.callId = callId
        self.name = name
        self.input = input
        self.operation = operation
        self.resource = resource
        self.risk = risk
        self.reason = reason
        self.idempotencyKey = idempotencyKey
    }
}

public enum ToolCallParser {
    public static func parse(_ content: String) -> ParsedToolCall? {
        var call = parseJson(content)
            ?? parseXml(content)
            ?? parseTag(content)
            ?? parsePlain(content)
        if call != nil {
            call?.callId = "tc-\(Int(Date().timeIntervalSince1970 * 1000))"
        }
        return call
    }

    public static func stripMarkup(_ content: String) -> String {
        let patterns = [
            "<tool_call\\s+name=\"[^\"]+\"\\s*>.*?(?:</tool_call>|$)",
            "<tool_call_invoke>.*?(?:</tool_call_invoke>|$)",
            "<[a-zA-Z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[a-zA-Z][\\w.-]*>|$)",
        ]
        var output = content
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(output.startIndex..<output.endIndex, in: output)
                output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "")
            }
        }
        if let regex = try? NSRegularExpression(pattern: "\\n{3,}") {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "\n\n")
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseInputJson(_ raw: String) -> [String: Any]? {
        if let value = try? Json.parse(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           let object = value as? [String: Any] {
            return object
        }
        let escaped = raw.replacingOccurrences(of: "\\", with: "\\\\")
        if let value = try? Json.parse(escaped.trimmingCharacters(in: .whitespacesAndNewlines)),
           let object = value as? [String: Any] {
            return object
        }
        return nil
    }

    private static func parseJson(_ content: String) -> ParsedToolCall? {
        guard let value = try? Json.parse(content),
              let object = value as? [String: Any],
              let name = object["name"] as? String,
              !name.isEmpty else {
            return nil
        }
        return ParsedToolCall(
            name: name,
            input: object["input"] as? [String: Any] ?? [:],
            operation: object["operation"] as? String ?? "",
            resource: object["resource"] as? String ?? "",
            risk: object["risk"] as? String ?? "",
            reason: object["reason"] as? String ?? "",
            idempotencyKey: object["idempotency_key"] as? String ?? ""
        )
    }

    private static func parseXml(_ content: String) -> ParsedToolCall? {
        guard let match = captures("<tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</tool_call>", content).last,
              let input = parseInputJson(match[2]) else {
            return nil
        }
        return ParsedToolCall(name: match[1], input: input)
    }

    private static func parseTag(_ content: String) -> ParsedToolCall? {
        let pattern = "<([a-zA-Z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[a-zA-Z][\\w.-]*>|$)"
        guard let match = captures(pattern, content).last,
              let input = parseInputJson(match[2]) else {
            return nil
        }
        return ParsedToolCall(name: match[1], input: input)
    }

    private static func parsePlain(_ content: String) -> ParsedToolCall? {
        guard let match = captures("(?m)^\\s*([a-zA-Z][\\w.-]*)\\s+(\\{.*\\})\\s*$", content).last,
              match[1].contains("."),
              let input = parseInputJson(match[2]) else {
            return nil
        }
        return ParsedToolCall(name: match[1], input: input)
    }

    private static func captures(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return []
        }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }
}
