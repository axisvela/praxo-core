import CoreFoundation
import Foundation

public struct PluginManifest {
    public let schemaVersion: Int
    public let id: String
    public let version: String
    public let kind: String
    public let entrypoint: [String: Any]
    public let protocolName: String
    public let capabilities: [String]
    public let permissions: [String: Any]
    public let limits: [String: Any]
    public let isolation: String
    public let health: [String: Any]

    public init(
        schemaVersion: Int,
        id: String,
        version: String,
        kind: String,
        entrypoint: [String: Any],
        protocolName: String,
        capabilities: [String],
        permissions: [String: Any],
        limits: [String: Any],
        isolation: String,
        health: [String: Any]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.version = version
        self.kind = kind
        self.entrypoint = entrypoint
        self.protocolName = protocolName
        self.capabilities = capabilities
        self.permissions = permissions
        self.limits = limits
        self.isolation = isolation
        self.health = health
    }
}

public enum PluginError: Error, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

public enum Plugin {
    public static let kinds = [
        "tool.provider.v1", "model.provider.v1", "policy.provider.v1",
        "memory.provider.v1", "sandbox.provider.v1",
    ]

    private static let topKeys: Set<String> = [
        "schemaVersion", "id", "version", "kind", "entrypoint", "protocol",
        "capabilities", "permissions", "limits", "isolation", "health",
        "signature", "sbom",
    ]
    private static let entrypointKeys: Set<String> = ["type", "command", "module", "image", "args", "dir"]
    private static let permissionKeys: Set<String> = ["filesystem", "network", "env"]
    private static let limitKeys: Set<String> = ["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"]
    private static let healthKeys: Set<String> = ["method", "intervalMs"]
    private static let signatureKeys: Set<String> = ["algorithm", "keyId"]

    public static func parseManifest(_ raw: String) throws -> PluginManifest {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PluginError.invalid("plugin: manifest is empty")
        }
        let value: Any
        do {
            value = try Json.parse(raw)
        } catch {
            throw PluginError.invalid("plugin: manifest: \(error)")
        }
        guard let root = value as? [String: Any] else {
            throw PluginError.invalid("plugin: manifest must be an object")
        }
        try checkKeys(root, topKeys, "manifest")
        let schemaVersion = try asInt(root["schemaVersion"], "schemaVersion")
        if schemaVersion != 1 {
            throw PluginError.invalid("plugin: manifest: schemaVersion = \(schemaVersion), want 1")
        }
        let id = try asString(root["id"], "id")
        if !matches("^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", id) {
            throw PluginError.invalid("plugin: manifest: id \(id) is not reverse-DNS")
        }
        let version = try asString(root["version"], "version")
        if !matches("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$", version) {
            throw PluginError.invalid("plugin: manifest: version \(version) is not semver")
        }
        let kind = try asString(root["kind"], "kind")
        if !kinds.contains(kind) {
            throw PluginError.invalid("plugin: manifest: kind \(kind) is not a known contract")
        }
        let protocolName = try asString(root["protocol"], "protocol")
        if protocolName != "jsonrpc-2" {
            throw PluginError.invalid("plugin: manifest: protocol = \(protocolName), want jsonrpc-2")
        }
        let entrypoint = try asObject(root["entrypoint"], "entrypoint")
        try checkKeys(entrypoint, entrypointKeys, "entrypoint")
        let entryType = try asString(entrypoint["type"], "entrypoint.type")
        let required: String
        switch entryType {
        case "process":
            required = "command"
        case "wasm":
            required = "module"
        case "container":
            required = "image"
        default:
            throw PluginError.invalid("plugin: manifest: unknown entrypoint type \(entryType)")
        }
        if !textPresent(entrypoint[required]) {
            throw PluginError.invalid("plugin: manifest: \(entryType) entrypoint requires \(required)")
        }
        let isolation = try asString(root["isolation"], "isolation")
        if isolation != entryType {
            throw PluginError.invalid("plugin: manifest: isolation \(isolation) does not match entrypoint \(entryType)")
        }
        let permissions = try asObject(root["permissions"], "permissions")
        try checkKeys(permissions, permissionKeys, "permissions")
        let limits = try asObject(root["limits"], "limits")
        try checkKeys(limits, limitKeys, "limits")
        for (key, value) in limits {
            if try asInt(value, "limits.\(key)") < 0 {
                throw PluginError.invalid("plugin: manifest: limits must not be negative")
            }
        }
        let health = try asObject(root["health"], "health")
        try checkKeys(health, healthKeys, "health")
        if root["signature"] != nil {
            let signature = try asObject(root["signature"], "signature")
            try checkKeys(signature, signatureKeys, "signature")
            if !textPresent(signature["algorithm"]) || !textPresent(signature["keyId"]) {
                throw PluginError.invalid("plugin: manifest: signature requires algorithm and keyId")
            }
        }
        var capabilities: [String] = []
        if let rawCapabilities = root["capabilities"] {
            guard let items = rawCapabilities as? [Any] else {
                throw PluginError.invalid("plugin: manifest: capabilities must be an array")
            }
            for item in items {
                capabilities.append(try asString(item, "capabilities"))
            }
        }
        if capabilities.contains("") {
            throw PluginError.invalid("plugin: manifest: capability must not be empty")
        }
        if Set(capabilities).count != capabilities.count {
            throw PluginError.invalid("plugin: manifest: duplicate capability")
        }
        return PluginManifest(
            schemaVersion: schemaVersion,
            id: id,
            version: version,
            kind: kind,
            entrypoint: entrypoint,
            protocolName: protocolName,
            capabilities: capabilities,
            permissions: permissions,
            limits: limits,
            isolation: isolation,
            health: health
        )
    }

    private static func checkKeys(_ value: [String: Any], _ allowed: Set<String>, _ whereName: String) throws {
        for key in value.keys where !allowed.contains(key) {
            throw PluginError.invalid("plugin: manifest: unknown field \(key) in \(whereName)")
        }
    }

    private static func asObject(_ value: Any?, _ whereName: String) throws -> [String: Any] {
        if value == nil {
            return [:]
        }
        guard let object = value as? [String: Any] else {
            throw PluginError.invalid("plugin: manifest: \(whereName) must be an object")
        }
        return object
    }

    private static func asString(_ value: Any?, _ whereName: String) throws -> String {
        guard let text = value as? String else {
            throw PluginError.invalid("plugin: manifest: \(whereName) must be a string")
        }
        return text
    }

    private static func asInt(_ value: Any?, _ whereName: String) throws -> Int {
        guard let number = value as? NSNumber, !isBoolean(number) else {
            throw PluginError.invalid("plugin: manifest: \(whereName) must be an integer")
        }
        return number.intValue
    }

    private static func textPresent(_ value: Any?) -> Bool {
        (value as? String)?.isEmpty == false
    }

    private static func matches(_ pattern: String, _ value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID()
    }
}
