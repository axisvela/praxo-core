import Darwin
import Foundation
import PraxoCore

func repoRoot() -> String? {
    var current = FileManager.default.currentDirectoryPath
    while true {
        if FileManager.default.fileExists(atPath: current + "/spec/SPEC_VERSION") {
            return current
        }
        let parent = URL(fileURLWithPath: current).deletingLastPathComponent().path
        if parent == current {
            return nil
        }
        current = parent
    }
}

func check(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw JsonError.invalid(message)
    }
}

func runToolcall(_ input: Any?, _ expect: Any?) throws {
    let operation = Json.string(input, "operation") ?? ""
    let content = Json.string(input, "content") ?? ""
    if operation == "strip" {
        let got = ToolCallParser.stripMarkup(content)
        try check(got == (Json.string(expect, "text") ?? ""), "strip: got \(got)")
        return
    }
    let call = ToolCallParser.parse(content)
    if Json.bool(expect, "nil") {
        try check(call == nil, "expected nil")
        return
    }
    guard let call = call else {
        throw JsonError.invalid("expected a tool call")
    }
    try check(call.name == (Json.string(expect, "name") ?? ""), "name: got \(call.name)")
    let expected = Json.get(expect, "input") as? [String: Any] ?? [:]
    try check(Json.equals(call.input, expected), "input mismatch")
}

func runJsonSchema(_ input: Any?, _ expect: Any?) throws {
    let errors = JsonSchema.validate(Json.get(input, "schema"), Json.get(input, "data"))
    let paths = errors.map(\.path).sorted()
    let expected = Json.array(expect, "errorPaths").compactMap { $0 as? String }.sorted()
    try check(errors.isEmpty == Json.bool(expect, "valid"), "valid mismatch")
    try check(paths == expected, "errorPaths: got \(paths)")
}

func runPlugin(_ input: Any?, _ expect: Any?) throws {
    let raw = Json.string(input, "raw") ?? (try? Json.stringify(Json.get(input, "manifest") ?? [:])) ?? "{}"
    let manifest: PluginManifest?
    do {
        manifest = try Plugin.parseManifest(raw)
    } catch {
        manifest = nil
    }
    try check((manifest != nil) == Json.bool(expect, "valid"), "valid mismatch")
    guard let manifest = manifest else {
        return
    }
    if let id = Json.string(expect, "id") {
        try check(manifest.id == id, "id: got \(manifest.id)")
    }
    if let kind = Json.string(expect, "kind") {
        try check(manifest.kind == kind, "kind: got \(manifest.kind)")
    }
}

func runVector(_ group: String, _ vector: Any?) throws {
    let input = Json.get(vector, "input")
    let expect = Json.get(vector, "expect")
    switch group {
    case "toolcall":
        try runToolcall(input, expect)
    case "jsonschema":
        try runJsonSchema(input, expect)
    case "plugin":
        try runPlugin(input, expect)
    default:
        break
    }
}

func runAll() -> [String] {
    guard let root = repoRoot() else {
        return ["cannot find repository root"]
    }
    let versionPath = root + "/spec/SPEC_VERSION"
    guard let version = try? String(contentsOfFile: versionPath, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines) else {
        return ["cannot read SPEC_VERSION"]
    }
    let vectorDir = root + "/spec/vectors"
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: vectorDir) else {
        return ["cannot read spec/vectors"]
    }
    var failures: [String] = []
    var seen: [String: String] = [:]
    for file in files.filter({ $0.hasSuffix(".json") }).sorted() {
        let name = String(file.dropLast(5))
        let path = vectorDir + "/" + file
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let parsed = try? Json.parse(raw),
              let object = parsed as? [String: Any] else {
            failures.append("\(name): invalid vector file")
            continue
        }
        let group = object["group"] as? String ?? ""
        if (object["specVersion"] as? String) != version {
            failures.append("\(name): specVersion mismatch")
        }
        if name != group {
            failures.append("\(name): group mismatch")
        }
        for vector in Json.array(object, "vectors") {
            let id = Json.string(vector, "id") ?? ""
            if let previous = seen[id] {
                failures.append("\(group)/\(id): duplicate id with \(previous)")
            }
            seen[id] = group
            do {
                try runVector(group, vector)
            } catch {
                failures.append("\(group)/\(id): \(error)")
            }
        }
    }
    return failures
}

let failures = runAll()
if failures.isEmpty {
    print("all wire vectors passed")
    exit(0)
}
for failure in failures {
    fputs(failure + "\n", stderr)
}
exit(1)
