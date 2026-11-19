import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct PluginProcessConfig {
    public var pluginId: String
    public var path: String
    public var args: [String]
    public var env: [String: String]?
    public var token: String
    public var tokenEnvVar: String
    public var startTimeout: TimeInterval
    public var invokeTimeout: TimeInterval
    public var gracePeriod: TimeInterval

    public init(pluginId: String, path: String, args: [String] = [],
                env: [String: String]? = nil, token: String = "",
                tokenEnvVar: String = "PRAXOVELA_PLUGIN_TOKEN",
                startTimeout: TimeInterval = 10,
                invokeTimeout: TimeInterval = 30,
                gracePeriod: TimeInterval = 5) {
        self.pluginId = pluginId
        self.path = path
        self.args = args
        self.env = env
        self.token = token
        self.tokenEnvVar = tokenEnvVar
        self.startTimeout = startTimeout
        self.invokeTimeout = invokeTimeout
        self.gracePeriod = gracePeriod
    }
}

public struct PluginProcessError: Error, CustomStringConvertible {
    public let code: String
    public let message: String

    public init(_ code: String, _ message: String = "") {
        let known = ["CAPABILITY_DENIED", "NOT_ACTIVE", "NOT_FOUND",
                     "INVALID_REQUEST", "TIMEOUT", "INTERNAL", "CANCELED"]
        self.code = known.contains(code) ? code : "INTERNAL"
        self.message = message.isEmpty ? self.code : message
    }

    public var description: String { "\(code): \(message)" }
}

public final class PluginProcessHost {
    public static let protocolVersion = 1
    public static let controlService = "host.control"

    public let config: PluginProcessConfig
    private let token: String
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var error: FileHandle?
    private var buffer = ""
    private var stderrText = ""
    private var sequence = 0
    private var active = false

    public init(_ config: PluginProcessConfig) throws {
        guard !config.pluginId.isEmpty else {
            throw PluginProcessError("INVALID_REQUEST", "plugin: PluginID is required")
        }
        guard !config.path.isEmpty else {
            throw PluginProcessError("INVALID_REQUEST", "plugin: path is required")
        }
        self.config = config
        self.token = config.token.isEmpty
            ? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            : config.token
    }

    public var isActive: Bool { active }

    public func start() throws {
        guard process == nil else {
            throw PluginProcessError("INVALID_REQUEST", "plugin: host already started")
        }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: config.path)
        child.arguments = config.args
        var environment = config.env ?? ProcessInfo.processInfo.environment
        environment[config.tokenEnvVar] = token
        child.environment = environment
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        child.standardError = stderrPipe
        try child.run()
        process = child
        input = stdinPipe.fileHandleForWriting
        output = stdoutPipe.fileHandleForReading
        error = stderrPipe.fileHandleForReading
        DispatchQueue.global().async { [weak self] in
            guard let self, let error = self.error else { return }
            let data = error.availableData
            if !data.isEmpty {
                self.stderrText = String(data: data, encoding: .utf8) ?? ""
            }
        }
        do {
            _ = try call(Self.controlService, "health", "", timeout: config.startTimeout)
        } catch {
            terminate()
            throw error
        }
        active = true
    }

    public func invoke(_ service: String, _ method: String,
                       payload: String = "", timeout: TimeInterval? = nil) throws -> String {
        guard active else {
            throw PluginProcessError("NOT_ACTIVE", "plugin: host is not active")
        }
        return try call(service, method, payload,
                        timeout: timeout ?? config.invokeTimeout)
    }

    public func stop() {
        guard process != nil else { return }
        if active {
            _ = try? call(Self.controlService, "shutdown", "", timeout: config.gracePeriod)
        }
        active = false
        terminate()
    }

    private func call(_ service: String, _ method: String,
                      _ payload: String, timeout: TimeInterval) throws -> String {
        guard let input else {
            throw PluginProcessError("INTERNAL", "plugin: process is closed")
        }
        sequence += 1
        let requestId = "req-\(sequence)"
        let frame: [String: Any] = [
            "id": requestId,
            "version": Self.protocolVersion,
            "plugin_id": config.pluginId,
            "service": service,
            "method": method,
            "token": token,
            "payload": Data(payload.utf8).base64EncodedString(),
        ]
        let encoded = try Json.stringify(frame) + "\n"
        input.write(Data(encoded.utf8))
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                terminate()
                throw PluginProcessError("TIMEOUT", "plugin: invocation timed out")
            }
            let line = try readLine(timeout: remaining)
            guard let root = try? Json.parse(line) as? [String: Any] else { continue }
            guard Json.string(root, "id") == requestId else { continue }
            guard Json.get(root, "ok") as? Bool == true else {
                throw PluginProcessError(Json.string(root, "code") ?? "INTERNAL",
                                         Json.string(root, "message") ?? "")
            }
            let encodedPayload = Json.string(root, "payload") ?? ""
            guard let decoded = Data(base64Encoded: encodedPayload),
                  let text = String(data: decoded, encoding: .utf8) else {
                throw PluginProcessError("INTERNAL", "plugin: invalid payload")
            }
            return text
        }
    }

    private func readLine(timeout: TimeInterval) throws -> String {
        if let index = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<index])
            buffer = String(buffer[buffer.index(after: index)...])
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let semaphore = DispatchSemaphore(value: 0)
        var chunk = Data()
        var done = false
        DispatchQueue.global().async { [weak self] in
            guard let self, let output = self.output else {
                semaphore.signal()
                return
            }
            while !done {
                let data = output.availableData
                if data.isEmpty {
                    break
                }
                chunk.append(data)
                if data.contains(0x0A) {
                    break
                }
            }
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            terminate()
            throw PluginProcessError("TIMEOUT", "plugin: invocation timed out")
        }
        done = true
        buffer += String(data: chunk, encoding: .utf8) ?? ""
        if let index = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<index])
            buffer = String(buffer[buffer.index(after: index)...])
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return buffer
    }

    private func terminate() {
        active = false
        if let process, process.isRunning {
            process.terminate()
        }
        input?.closeFile()
        output?.closeFile()
        error?.closeFile()
        process = nil
        input = nil
        output = nil
        error = nil
    }
}
