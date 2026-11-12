import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol McpTransport: AnyObject {
    func request(_ method: String, _ params: [String: Any],
                 timeout: TimeInterval) throws -> [String: Any]
    func notify(_ method: String, _ params: [String: Any]) throws
    func close()
}

public final class McpToolInfo {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]

    init(_ value: [String: Any]) throws {
        guard let name = value["name"] as? String, !name.isEmpty else {
            throw PraxoError("MCP_PROTOCOL", "mcp: tool name is required")
        }
        self.name = name
        self.description = value["description"] as? String ?? ""
        guard let schema = value["inputSchema"] as? [String: Any] else {
            throw PraxoError("MCP_PROTOCOL", "mcp: missing input schema for \(name)")
        }
        self.inputSchema = schema
    }
}

public final class McpClient {
    public static let defaultProtocolVersion = "2024-11-05"
    public static let httpProtocolVersion = "2025-03-26"

    public let transport: McpTransport
    public let clientVersion: String
    public let timeout: TimeInterval
    public let requestedProtocolVersion: String
    public private(set) var protocolVersion = ""
    public private(set) var serverInfo: [String: Any] = [:]
    private var connected = false
    private var closed = false

    public init(transport: McpTransport,
                clientVersion: String = "0.3.0",
                timeout: TimeInterval = 30,
                protocolVersion: String = McpClient.defaultProtocolVersion) {
        self.transport = transport
        self.clientVersion = clientVersion
        self.timeout = timeout
        self.requestedProtocolVersion = protocolVersion
    }

    public func start() throws -> McpClient {
        if connected { return self }
        if closed {
            throw PraxoError("MCP_CLOSED", "mcp: client is closed")
        }
        let result = try transport.request("initialize", [
            "protocolVersion": requestedProtocolVersion,
            "capabilities": [:],
            "clientInfo": ["name": "praxo-core", "version": clientVersion],
        ], timeout: timeout)
        guard let version = result["protocolVersion"] as? String, !version.isEmpty else {
            throw PraxoError("MCP_HANDSHAKE", "mcp: initialize returned no protocol version")
        }
        protocolVersion = version
        serverInfo = result["serverInfo"] as? [String: Any] ?? [:]
        try transport.notify("notifications/initialized", [:])
        connected = true
        return self
    }

    public func listTools() throws -> [McpToolInfo] {
        try ensureConnected()
        var tools: [McpToolInfo] = []
        var names = Set<String>()
        var cursors = Set<String>()
        var cursor: String?
        while true {
            var params: [String: Any] = [:]
            if let cursor { params["cursor"] = cursor }
            let result = try transport.request("tools/list", params, timeout: timeout)
            let raw = result["tools"] as? [[String: Any]] ?? []
            for item in raw {
                let tool = try McpToolInfo(item)
                if names.contains(tool.name) {
                    throw PraxoError("MCP_DUPLICATE_TOOL", "mcp: duplicate tool \(tool.name)")
                }
                names.insert(tool.name)
                tools.append(tool)
            }
            guard let next = result["nextCursor"] as? String, !next.isEmpty else {
                break
            }
            if cursors.contains(next) {
                throw PraxoError("MCP_PAGINATION", "mcp: repeated tool pagination cursor")
            }
            cursors.insert(next)
            cursor = next
        }
        return tools.sorted { $0.name < $1.name }
    }

    public func callTool(_ name: String, _ arguments: [String: Any] = [:]) throws -> Any {
        try ensureConnected()
        let result = try transport.request("tools/call", [
            "name": name,
            "arguments": arguments,
        ], timeout: timeout)
        if result["isError"] as? Bool == true {
            throw PraxoError("MCP_TOOL_ERROR", "mcp: tool \(name) failed")
        }
        if let structured = result["structuredContent"] {
            return structured
        }
        let content = result["content"] as? [[String: Any]] ?? []
        let texts = content.compactMap { item -> String? in
            guard item["type"] as? String == "text" else { return nil }
            return item["text"] as? String
        }
        if texts.isEmpty { return NSNull() }
        if texts.count == 1 { return texts[0] }
        return texts
    }

    public func close() {
        guard !closed else { return }
        closed = true
        connected = false
        transport.close()
    }

    private func ensureConnected() throws {
        if closed {
            throw PraxoError("MCP_CLOSED", "mcp: client is closed")
        }
        if !connected { _ = try start() }
    }
}

public final class StdioMcpTransport: McpTransport {
    private let command: String
    private let args: [String]
    private let environment: [String: String]?
    private let timeout: TimeInterval
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var nextId = 0
    private var closed = false

    public init(command: String, args: [String] = [],
                environment: [String: String]? = nil,
                timeout: TimeInterval = 30) {
        self.command = command
        self.args = args
        self.environment = environment
        self.timeout = timeout
    }

    public func start() throws {
        if process != nil { return }
        let process = Process()
        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "cmd.exe")
        process.arguments = ["/c", command] + args
        #else
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        #endif
        if let environment {
            var merged = ProcessInfo.processInfo.environment
            environment.forEach { merged[$0.key] = $0.value }
            process.environment = merged
        }
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw PraxoError("MCP_TRANSPORT", "mcp: failed to start server")
        }
        self.process = process
        self.input = stdinPipe.fileHandleForWriting
        self.output = stdoutPipe.fileHandleForReading
    }

    public func request(_ method: String, _ params: [String: Any],
                        timeout: TimeInterval) throws -> [String: Any] {
        try start()
        nextId += 1
        let id = nextId
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        ]
        try send(message)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let line = try readLine(), let message = try Json.parse(line) as? [String: Any] {
                if message["id"] as? Int != id { continue }
                if let error = message["error"] as? [String: Any] {
                    throw PraxoError("MCP_RPC", "mcp: \(method) failed: \(error["message"] ?? "rpc error")")
                }
                return message["result"] as? [String: Any] ?? [:]
            }
        }
        throw PraxoError("MCP_TIMEOUT", "mcp: \(method) timed out")
    }

    public func notify(_ method: String, _ params: [String: Any]) throws {
        try start()
        try send(["jsonrpc": "2.0", "method": method, "params": params])
    }

    public func close() {
        guard !closed else { return }
        closed = true
        try? input?.close()
        try? output?.close()
        process?.terminate()
    }

    private func send(_ message: [String: Any]) throws {
        guard let input else {
            throw PraxoError("MCP_TRANSPORT", "mcp: transport is not started")
        }
        let line = try Json.stringify(message) + "\n"
        input.write(Data(line.utf8))
    }

    private func readLine() throws -> String? {
        guard let output else { return nil }
        while true {
            if let index = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<index]
                buffer.removeSubrange(...index)
                return String(decoding: line, as: UTF8.self).trimmingCharacters(in: .newlines)
            }
            let chunk = output.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
    }
}

public final class HttpMcpTransport: McpTransport {
    private let endpoint: String
    private let headers: [String: String]
    private let timeout: TimeInterval
    private var protocolVersion: String
    private var sessionId = ""
    private var nextId = 0
    private var closed = false

    public init(endpoint: String, headers: [String: String] = [:],
                protocolVersion: String = McpClient.httpProtocolVersion,
                timeout: TimeInterval = 30) throws {
        guard let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw PraxoError("MCP_TRANSPORT", "mcp: invalid HTTP endpoint")
        }
        if scheme == "http", !HttpMcpTransport.loopback(url.host ?? "") {
            throw PraxoError("MCP_TRANSPORT", "mcp: HTTP endpoint must use HTTPS")
        }
        self.endpoint = endpoint
        self.headers = headers
        self.protocolVersion = protocolVersion
        self.timeout = timeout
    }

    public func request(_ method: String, _ params: [String: Any],
                        timeout: TimeInterval) throws -> [String: Any] {
        if closed {
            throw PraxoError("MCP_CLOSED", "mcp: client is closed")
        }
        nextId += 1
        let id = nextId
        let response = try post([
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        ], timeout: timeout)
        if let error = response["error"] as? [String: Any] {
            throw PraxoError("MCP_RPC", "mcp: \(method) failed: \(error["message"] ?? "rpc error")")
        }
        return response["result"] as? [String: Any] ?? [:]
    }

    public func notify(_ method: String, _ params: [String: Any]) throws {
        if closed { return }
        _ = try? post(["jsonrpc": "2.0", "method": method, "params": params],
                      timeout: timeout)
    }

    public func close() {
        guard !closed else { return }
        closed = true
        guard !sessionId.isEmpty, let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        applyHeaders(&request)
        _ = try? send(request)
    }

    private func post(_ message: [String: Any], timeout: TimeInterval) throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw PraxoError("MCP_TRANSPORT", "mcp: invalid HTTP endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = Data(try Json.stringify(message).utf8)
        applyHeaders(&request)
        let (status, responseHeaders, body) = try send(request)
        if let session = HttpMcpTransport.header(responseHeaders, "mcp-session-id"),
           !session.isEmpty {
            sessionId = session
        }
        if status == 202 || status == 204 || body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [:]
        }
        if status < 200 || status >= 300 {
            throw PraxoError("MCP_TRANSPORT", "mcp: HTTP \(status)")
        }
        let contentType = HttpMcpTransport.header(responseHeaders, "content-type") ?? ""
        let decoded = contentType.lowercased().contains("text/event-stream")
            ? try parseSse(body, id: message["id"] as? Int)
            : try parseJson(body)
        if let result = decoded["result"] as? [String: Any],
           let version = result["protocolVersion"] as? String, !version.isEmpty {
            protocolVersion = version
        }
        return decoded
    }

    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json, text/event-stream",
                         forHTTPHeaderField: "accept")
        request.setValue(protocolVersion, forHTTPHeaderField: "mcp-protocol-version")
        if !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "mcp-session-id")
        }
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    }

    private func send(_ request: URLRequest) throws -> (Int, [AnyHashable: Any], String) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Int, [AnyHashable: Any], String), Error>?
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                result = .failure(PraxoError("MCP_TRANSPORT", "mcp: invalid HTTP response"))
                return
            }
            result = .success((http.statusCode, http.allHeaderFields,
                               data.map { String(decoding: $0, as: UTF8.self) } ?? ""))
        }.resume()
        semaphore.wait()
        guard let result else {
            throw PraxoError("MCP_TRANSPORT", "mcp: HTTP transport failed")
        }
        switch result {
        case let .success(value): return value
        case let .failure(error): throw error
        }
    }

    private func parseJson(_ body: String) throws -> [String: Any] {
        guard let value = try Json.parse(body) as? [String: Any] else {
            throw PraxoError("MCP_PROTOCOL", "mcp: server sent invalid JSON")
        }
        return value
    }

    private func parseSse(_ body: String, id: Int?) throws -> [String: Any] {
        var messages: [[String: Any]] = []
        var data: [String] = []
        for raw in body.replacingOccurrences(of: "\r\n", with: "\n").split(
            separator: "\n", omittingEmptySubsequences: false
        ) {
            let line = String(raw)
            if line.isEmpty {
                if !data.isEmpty, let value = try Json.parse(data.joined(separator: "\n")) as? [String: Any] {
                    messages.append(value)
                }
                data.removeAll()
                continue
            }
            if line.hasPrefix(":") { continue }
            if line.hasPrefix("data:") {
                data.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        if !data.isEmpty, let value = try Json.parse(data.joined(separator: "\n")) as? [String: Any] {
            messages.append(value)
        }
        if let id, let match = messages.first(where: { $0["id"] as? Int == id }) {
            return match
        }
        guard let first = messages.first else {
            throw PraxoError("MCP_PROTOCOL", "mcp: response contained no message")
        }
        return first
    }

    private static func header(_ headers: [AnyHashable: Any], _ name: String) -> String? {
        for (key, value) in headers {
            if (key as? String)?.lowercased() == name.lowercased() {
                return value as? String
            }
        }
        return nil
    }

    private static func loopback(_ host: String) -> Bool {
        let value = host.lowercased()
        return value == "localhost" || value == "127.0.0.1" ||
            value == "::1" || value.hasPrefix("127.")
    }
}
