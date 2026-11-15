import Foundation

public let INTERRUPT_APPROVE = "approve"
public let INTERRUPT_EDIT = "edit"
public let INTERRUPT_REJECT = "reject"
public let INTERRUPT_RESPOND = "respond"

public enum InterruptAction {
    public static let approve = INTERRUPT_APPROVE
    public static let edit = INTERRUPT_EDIT
    public static let reject = INTERRUPT_REJECT
    public static let respond = INTERRUPT_RESPOND
}

public struct Interrupt {
    public var runID: String
    public var sessionID: String
    public var call: ToolCall

    public var runId: String {
        get { runID }
        set { runID = newValue }
    }

    public var sessionId: String {
        get { sessionID }
        set { sessionID = newValue }
    }

    public init(runID: String, sessionID: String, call: ToolCall) {
        self.runID = runID
        self.sessionID = sessionID
        self.call = call
    }

    public init(runId: String, sessionId: String, call: ToolCall) {
        self.init(runID: runId, sessionID: sessionId, call: call)
    }
}

public struct InterruptDecision {
    public var action: String
    public var arguments: [String: Any]?
    public var response: String?
    public var reason: String?

    public init(action: String, arguments: [String: Any]? = nil,
                response: String? = nil, reason: String? = nil) {
        self.action = action
        self.arguments = arguments
        self.response = response
        self.reason = reason
    }
}

public typealias InterruptHandler = (Interrupt) throws -> InterruptDecision
public typealias InterruptApproval = (Interrupt) throws -> Bool
