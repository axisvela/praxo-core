import Foundation

public struct PraxoError: Error {
    public let code: String
    public let message: String

    public init(_ code: String, _ message: String) {
        self.code = code
        self.message = message
    }
}

public protocol EventSink {
    func emit(_ event: Event)
}

public final class MultiSink: EventSink {
    private let sinks: [EventSink]
    public init(_ sinks: [EventSink]) { self.sinks = sinks }
    public func emit(_ event: Event) { for sink in sinks { sink.emit(event) } }
}

public final class FilterSink: EventSink {
    private let sink: EventSink
    private let predicate: (Event) -> Bool
    public init(_ sink: EventSink, _ predicate: @escaping (Event) -> Bool) {
        self.sink = sink
        self.predicate = predicate
    }
    public func emit(_ event: Event) { if predicate(event) { sink.emit(event) } }
}

public final class MemoryStore {
    private var records: [String: [MemoryRecord]] = [:]
    private var sequence = 0

    public init() {}

    public func put(_ sessionID: String, _ record: MemoryRecord) {
        if record.id.isEmpty {
            record.id = "mem-\(Int(Date().timeIntervalSince1970 * 1000))-\(sequence)"
            sequence += 1
        }
        record.createdAt = record.createdAt ?? ISO8601DateFormatter().string(from: Date())
        records[sessionID, default: []].append(record)
    }

    public func search(_ sessionID: String, _ query: String, _ limit: Int) -> [MemoryRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var matches = (records[sessionID] ?? []).filter {
            needle.isEmpty || $0.content.lowercased().contains(needle)
        }
        matches.sort { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        if limit > 0 { matches = Array(matches.prefix(limit)) }
        return matches
    }
}

public final class CheckpointAllowlist {
    private var registered = Set<String>()

    public init() {}

    public func register(_ type: String) throws {
        if type.isEmpty { throw PraxoError("CHECKPOINT_ERROR", "checkpoint: type is required") }
        registered.insert(type)
    }

    public func marshal(_ type: String, _ value: Any?) throws -> String {
        guard registered.contains(type) else {
            throw PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed: \(type)")
        }
        return try Json.stringify(["type": type, "data": value ?? NSNull()])
    }

    public func unmarshal(_ data: String) throws -> Any? {
        let envelope = try Json.parse(data)
        guard let object = envelope as? [String: Any] else {
            throw PraxoError("CHECKPOINT_ERROR", "checkpoint: envelope must be an object")
        }
        let type = object["type"] as? String ?? ""
        guard registered.contains(type) else {
            throw PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed: \(type)")
        }
        return object["data"]
    }
}

public struct PathChecker {
    private let grants: [PathGrant]

    public init(_ grants: [PathGrant]) {
        self.grants = grants.map { PathGrant(root: resolvePath($0.root), access: $0.access) }
    }

    public func check(_ target: String, _ need: String) throws -> Decision {
        if !["read", "write", "readwrite"].contains(need) {
            throw PraxoError("POLICY_ERROR", "policy: invalid access")
        }
        if grants.isEmpty { return Decision(allowed: false, reason: "no allowed roots") }
        let resolved = resolvePath(target)
        var matched: String?
        for grant in grants where within(grant.root, resolved) {
            matched = grant.root
            if allows(grant.access, need) {
                return Decision(allowed: true, reason: "path within \(grant.root)")
            }
        }
        return Decision(allowed: false, reason: matched == nil ? "outside roots" : "insufficient grant")
    }

    public func allowed(_ target: String, _ need: String) -> Bool {
        (try? check(target, need))?.allowed ?? false
    }
}

private func resolvePath(_ value: String) -> String {
    let url = URL(fileURLWithPath: value).standardizedFileURL
    if FileManager.default.fileExists(atPath: url.path) { return url.path }
    let parent = url.deletingLastPathComponent()
    if parent.path == url.path { return url.path }
    return resolvePath(parent.path).appending("/\(url.lastPathComponent)")
}

private func within(_ root: String, _ target: String) -> Bool {
    let rootValue = root.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let targetValue = target.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return targetValue == rootValue || targetValue.hasPrefix(rootValue + "/")
}

private func allows(_ grant: String, _ need: String) -> Bool {
    switch need {
    case "read": return grant == "read" || grant == "readwrite"
    case "write": return grant == "write" || grant == "readwrite"
    default: return grant == "readwrite"
    }
}

public enum ContextEstimator {
    public static func estimate(_ messages: [Message]) -> Int {
        var total = 0
        for message in messages {
            total += 4 + bytes(message.content) / 4 + bytes(message.toolID) / 4
            for block in message.contentBlocks {
                total += 4 + bytes(block.text) / 4 + bytes(block.imageURL) / 4 + bytes(block.data) / 4
            }
            for call in message.toolCalls {
                total += 4 + call.name.utf8.count / 4
                total += ((try? Json.stringify(call.arguments))?.utf8.count ?? 0) / 4
            }
        }
        return total
    }

    public static func truncate(_ value: String, tokens: Int) -> String {
        if tokens <= 0 { return "" }
        let limit = tokens * 4
        let bytes = Array(value.utf8)
        if bytes.count <= limit { return value }
        if limit <= 16 { return String(decoding: bytes.prefix(limit), as: UTF8.self) }
        return String(decoding: bytes.prefix(limit - 16), as: UTF8.self) + "\n[truncated]"
    }

    private static func bytes(_ value: String?) -> Int { value?.utf8.count ?? 0 }
}

public struct ContextBudget {
    public var maxTokens: Int
    public var keepRecent: Int

    public init(maxTokens: Int, keepRecent: Int) {
        self.maxTokens = maxTokens
        self.keepRecent = keepRecent
    }

    public func compact(_ messages: [Message]) -> ([Message], Bool) {
        if maxTokens == 0 || ContextEstimator.estimate(messages) <= maxTokens {
            return (messages, true)
        }
        var system: [Message] = []
        var rest: [Message] = []
        for message in messages {
            if message.role == Roles.system {
                if (message.content ?? "").hasPrefix("[context compacted:") { continue }
                system.append(message)
            } else {
                rest.append(message)
            }
        }
        if ContextEstimator.estimate(system) > maxTokens {
            guard let first = system.first else { return ([], false) }
            var truncated = first
            truncated.content = ContextEstimator.truncate(first.content ?? "", tokens: max(0, maxTokens - 4))
            system = [truncated]
            if ContextEstimator.estimate(system) > maxTokens { return ([], false) }
        }
        let keep = keepRecent > 0 ? keepRecent : 4
        var start = max(0, rest.count - keep)
        while start > 0 && start < rest.count && rest[start].role == Roles.tool { start -= 1 }
        let marker = Message.text(Roles.system, "[context compacted: \(start) older messages omitted]")
        var kept = Array(rest.dropFirst(start))
        var output = system + (start > 0 ? [marker] : []) + kept
        while ContextEstimator.estimate(output) > maxTokens && kept.count > 1 {
            if kept[1].role == Roles.tool { break }
            kept.removeFirst()
            output = system + (start > 0 ? [marker] : []) + kept
        }
        return (output, ContextEstimator.estimate(output) <= maxTokens)
    }
}
