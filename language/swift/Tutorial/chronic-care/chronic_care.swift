import Foundation
import PraxoCore

#if canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#else
import Darwin
#endif

let patientID = "patient-100"

final class FixtureModel: Model {
    let patient: String

    init(_ patient: String) {
        self.patient = patient
    }

    func generate(_ request: Request) throws -> Response {
        let toolMessages = request.messages.filter { $0.role == Roles.tool }
        if toolMessages.isEmpty {
            return Response(message: Message.assistant("", toolCalls: [
                ToolCall(id: "trends-1", name: "read_trends", arguments: ["patient": patient]),
            ]))
        }
        if toolMessages.count == 1 {
            return Response(message: Message.assistant("", toolCalls: [
                ToolCall(id: "alert-1", name: "draft_alert", arguments: [
                    "patient": patient,
                    "action": "review_alert",
                ]),
            ]))
        }
        let trends = toolMessages[0].content ?? "{}"
        let alert = toolMessages[toolMessages.count - 1].content ?? "{}"
        let report = """
        {"stage":"chronic_alert_drafted","trends":\(trends),"alert":\(alert),"dosage_changes":0,"treatment_changes":0}
        """
        return Response(message: Message.assistant(report))
    }
}

final class ReadTrendsTool: Tool {
    let name = "read_trends"
    let description = "Summarize fixed wearable trends; no device access or treatment change."
    let patient: String
    let simulateFailure: Bool
    var calls = 0

    init(patient: String, simulateFailure: Bool) {
        self.patient = patient
        self.simulateFailure = simulateFailure
    }

    func invoke(_ arguments: [String: Any]) throws -> Any {
        calls += 1
        guard arguments["patient"] as? String == patientID else {
            throw PraxoError("AGENT_POLICY_DENIED", "patient outside fixture")
        }
        if simulateFailure {
            throw PraxoError("TRENDS_UNAVAILABLE", "wearable trends unavailable")
        }
        return [
            "patient": patientID,
            "days": 7,
            "resting_hr": 78,
            "threshold": 75,
            "trend": "rising",
            "alert": true,
            "source": "trends_fixture",
        ] as [String: Any]
    }
}

final class DraftAlertTool: Tool {
    let name = "draft_alert"
    let description = "Draft a review-only care alert; never changes dosage or treatment."
    var calls = 0

    func invoke(_ arguments: [String: Any]) throws -> Any {
        calls += 1
        return [
            "alert_id": "chronic-100",
            "patient": patientID,
            "action": arguments["action"] as? String ?? "",
            "routed_to": "care_team",
            "status": "draft_only",
            "review_required": true,
            "dosage_changes": 0,
            "treatment_changes": 0,
        ] as [String: Any]
    }
}

struct CarePolicy: PolicyHook {
    func authorize(_ action: Action) -> Decision {
        if action.kind == "model.generate" {
            return Decision(allowed: true, reason: "deterministic follow-up")
        }
        guard action.kind == "tool.invoke" else {
            return Decision(allowed: false, reason: "unsupported action")
        }
        guard action.arguments?["patient"] as? String == patientID else {
            return Decision(allowed: false, reason: "only patient-100 is in scope")
        }
        if action.toolName == "read_trends" {
            return Decision(allowed: true, reason: "fixed trends")
        }
        if action.toolName == "draft_alert" {
            return Decision(
                allowed: action.arguments?["action"] as? String == "review_alert",
                reason: "only a review_alert draft is allowed"
            )
        }
        return Decision(allowed: false, reason: "unsupported tool")
    }
}

struct Outcome {
    let output: String
    let reads: Int
    let drafts: Int
    let error: Error?
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func runScenario(_ patient: String, simulateFailure: Bool = false) -> Outcome {
    let readTool = ReadTrendsTool(patient: patient, simulateFailure: simulateFailure)
    let draftTool = DraftAlertTool()
    let registry = ToolRegistry()
    registry.register(readTool)
    registry.register(draftTool)
    let options = AgentOptions(FixtureModel(patient))
    options.tools = registry
    options.maxSteps = 4
    options.allowedTools = ["read_trends", "draft_alert"]
    options.policy = CarePolicy()
    options.requirePolicy = true
    options.requireToolScope = true
    do {
        let result = try Agent(options).run(
            Session(id: "chronic-care-\(patient)"),
            "Summarize fixed wearable trends and draft a review-only care alert."
        )
        return Outcome(output: result.output, reads: readTool.calls, drafts: draftTool.calls, error: nil)
    } catch {
        return Outcome(output: "", reads: readTool.calls, drafts: draftTool.calls, error: error)
    }
}

func test() {
    let success = runScenario(patientID)
    if success.error != nil || success.reads != 1 || success.drafts != 1 {
        fail("success failed: reads=\(success.reads) drafts=\(success.drafts) error=\(String(describing: success.error))")
    }
    guard let data = success.output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let report = object as? [String: Any],
          let trends = report["trends"] as? [String: Any],
          let alert = report["alert"] as? [String: Any] else {
        fail("success output is not JSON")
    }
    if trends["resting_hr"] as? Int != 78 || alert["status"] as? String != "draft_only"
        || alert["routed_to"] as? String != "care_team"
        || report["dosage_changes"] as? Int != 0 || report["treatment_changes"] as? Int != 0 {
        fail("unexpected report")
    }

    let denied = runScenario("patient-200")
    if let error = denied.error as? PraxoError {
        if error.code != "AGENT_POLICY_DENIED" || denied.reads != 0 || denied.drafts != 0 {
            fail("denial failed")
        }
    } else {
        fail("denial did not raise policy error")
    }

    let failed = runScenario(patientID, simulateFailure: true)
    if let error = failed.error as? PraxoError {
        if error.code != "TRENDS_UNAVAILABLE" || failed.reads != 1 || failed.drafts != 0 {
            fail("dependency failure failed")
        }
    } else {
        fail("dependency failure did not fail")
    }

    print("Swift HC-02 chronic-care tutorial: success, denial and dependency failure passed")
}

let arguments = CommandLine.arguments
if arguments.contains("--test") {
    test()
} else {
    let patient = arguments.firstIndex(of: "--patient").flatMap { index in
        index + 1 < arguments.count ? arguments[index + 1] : nil
    } ?? patientID
    let outcome = runScenario(patient, simulateFailure: arguments.contains("--simulate-failure"))
    if let error = outcome.error {
        fail("chronic care failed: reads=\(outcome.reads) drafts=\(outcome.drafts); \(error)")
    }
    print(outcome.output)
}
