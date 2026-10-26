import CoreFoundation
import Foundation

public struct ValidationError {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public enum JsonSchema {
    public static func validate(_ schema: Any?, _ data: Any?) -> [ValidationError] {
        var errors: [ValidationError] = []
        visit(schema as? [String: Any] ?? [:], data, "$", &errors)
        return errors
    }

    private static func visit(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        let kind = schema["type"] as? String ?? ""
        if data == nil || (data as? NSNull) != nil {
            if !kind.isEmpty {
                errors.append(ValidationError(path: path, message: "expected \(kind), got null"))
            }
            return
        }
        switch kind {
        case "object":
            visitObject(schema, data, path, &errors)
        case "array":
            visitArray(schema, data, path, &errors)
        case "string":
            visitString(schema, data, path, &errors)
        case "number", "integer":
            visitNumber(schema, kind, data, path, &errors)
        case "boolean":
            visitBoolean(schema, data, path, &errors)
        default:
            break
        }
    }

    private static func visitObject(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let object = data as? [String: Any] else {
            errors.append(ValidationError(path: path, message: "expected object"))
            return
        }
        if let required = schema["required"] as? [Any] {
            for item in required {
                if let name = item as? String, object[name] == nil {
                    errors.append(ValidationError(
                        path: "\(path).\(name)",
                        message: "required field missing"
                    ))
                }
            }
        }
        if let properties = schema["properties"] as? [String: Any] {
            for (name, child) in properties {
                if let value = object[name], let child = child as? [String: Any] {
                    visit(child, value, "\(path).\(name)", &errors)
                }
            }
        }
    }

    private static func visitArray(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let array = data as? [Any] else {
            errors.append(ValidationError(path: path, message: "expected array"))
            return
        }
        if let items = schema["items"] as? [String: Any] {
            for (index, value) in array.enumerated() {
                visit(items, value, "\(path)[\(index)]", &errors)
            }
        }
    }

    private static func visitString(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let text = data as? String else {
            errors.append(ValidationError(path: path, message: "expected string"))
            return
        }
        let length = text.unicodeScalars.count
        let min = (schema["minLength"] as? NSNumber)?.intValue ?? 0
        let max = (schema["maxLength"] as? NSNumber)?.intValue ?? 0
        if min > 0 && length < min {
            errors.append(ValidationError(path: path, message: "min length \(min), got \(length)"))
        }
        if max > 0 && length > max {
            errors.append(ValidationError(path: path, message: "max length \(max), got \(length)"))
        }
        if let pattern = schema["pattern"] as? String {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, range: range) == nil {
                    errors.append(ValidationError(path: path, message: "pattern '\(pattern)' not matched"))
                }
            } else {
                errors.append(ValidationError(path: path, message: "invalid pattern '\(pattern)'"))
            }
        }
        checkEnum(schema, data, path, &errors)
    }

    private static func visitNumber(
        _ schema: [String: Any],
        _ kind: String,
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let number = data as? NSNumber, !isBoolean(number) else {
            errors.append(ValidationError(path: path, message: "expected number"))
            return
        }
        if kind == "integer" && number.doubleValue.truncatingRemainder(dividingBy: 1) != 0 {
            errors.append(ValidationError(path: path, message: "expected integer, got \(number)"))
            return
        }
        checkEnum(schema, data, path, &errors)
        if let minimum = schema["minimum"] as? NSNumber, minimum.doubleValue != 0,
           number.doubleValue < minimum.doubleValue {
            errors.append(ValidationError(path: path, message: "value below minimum"))
        }
        if let maximum = schema["maximum"] as? NSNumber, maximum.doubleValue != 0,
           number.doubleValue > maximum.doubleValue {
            errors.append(ValidationError(path: path, message: "value above maximum"))
        }
    }

    private static func visitBoolean(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let number = data as? NSNumber, isBoolean(number) else {
            errors.append(ValidationError(path: path, message: "expected boolean"))
            return
        }
        checkEnum(schema, data, path, &errors)
    }

    private static func checkEnum(
        _ schema: [String: Any],
        _ data: Any?,
        _ path: String,
        _ errors: inout [ValidationError]
    ) {
        guard let values = schema["enum"] as? [Any], !values.isEmpty else {
            return
        }
        for value in values where Json.equals(value, data) {
            return
        }
        errors.append(ValidationError(path: path, message: "value not in enum"))
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID()
    }
}
