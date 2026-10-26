import Foundation

public enum JsonError: Error, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

public enum Json {
    public static func parse(_ text: String) throws -> Any {
        guard let data = text.data(using: .utf8) else {
            throw JsonError.invalid("invalid UTF-8")
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw JsonError.invalid("\(error)")
        }
    }

    public static func stringify(_ value: Any) throws -> String {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: value,
                options: [.fragmentsAllowed, .sortedKeys]
            )
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw JsonError.invalid("\(error)")
        }
    }

    public static func get(_ node: Any?, _ key: String) -> Any? {
        guard let object = node as? [String: Any] else {
            return nil
        }
        return object[key]
    }

    public static func string(_ node: Any?, _ key: String) -> String? {
        get(node, key) as? String
    }

    public static func bool(_ node: Any?, _ key: String, fallback: Bool = false) -> Bool {
        (get(node, key) as? Bool) ?? fallback
    }

    public static func int(_ node: Any?, _ key: String, fallback: Int = 0) -> Int {
        if let value = get(node, key) as? NSNumber {
            return value.intValue
        }
        return fallback
    }

    public static func array(_ node: Any?, _ key: String) -> [Any] {
        get(node, key) as? [Any] ?? []
    }

    public static func equals(_ left: Any?, _ right: Any?) -> Bool {
        if left == nil || right == nil {
            return left == nil && right == nil
        }
        guard let left = left, let right = right else {
            return false
        }
        if left is NSNull || right is NSNull {
            return left is NSNull && right is NSNull
        }
        if let left = left as? [String: Any], let right = right as? [String: Any] {
            if left.count != right.count {
                return false
            }
            for (key, value) in left {
                guard let other = right[key], Json.equals(value, other) else {
                    return false
                }
            }
            return true
        }
        if let left = left as? [Any], let right = right as? [Any] {
            if left.count != right.count {
                return false
            }
            for index in left.indices where !Json.equals(left[index], right[index]) {
                return false
            }
            return true
        }
        if let left = left as? Bool, let right = right as? Bool {
            return left == right
        }
        if let left = left as? NSNumber, let right = right as? NSNumber {
            return left.doubleValue == right.doubleValue
        }
        if let left = left as? String, let right = right as? String {
            return left == right
        }
        return String(describing: left) == String(describing: right)
    }
}
