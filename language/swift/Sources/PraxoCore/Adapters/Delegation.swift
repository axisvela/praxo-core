import Foundation

public struct SubagentRequest {
    public var parentSessionID: String
    public var agentID: String
    public var prompt: String
    public var mode: String

    public init(parentSessionID: String,
                agentID: String,
                prompt: String,
                mode: String = "isolated") {
        self.parentSessionID = parentSessionID
        self.agentID = agentID
        self.prompt = prompt
        self.mode = mode
    }
}

public struct SubagentResult {
    public var taskID: String
    public var agentID: String
    public var output: String

    public init(taskID: String, agentID: String, output: String) {
        self.taskID = taskID
        self.agentID = agentID
        self.output = output
    }
}

public struct SubagentTask {
    public var id: String
    public var parentSessionID: String
    public var agentID: String
    public var mode: String
    public var status: String
    public var output: String
    public var error: String
    public var createdAt: String
    public var updatedAt: String

    public init(id: String,
                parentSessionID: String,
                agentID: String,
                mode: String,
                status: String,
                output: String,
                error: String,
                createdAt: String,
                updatedAt: String) {
        self.id = id
        self.parentSessionID = parentSessionID
        self.agentID = agentID
        self.mode = mode
        self.status = status
        self.output = output
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public typealias SubagentRunner = (SubagentRequest) throws -> SubagentResult

public final class SubagentManager {
    public var runner: SubagentRunner
    public var clock: () -> Date

    public init(runner: @escaping SubagentRunner,
                clock: @escaping () -> Date = { Date() }) {
        self.runner = runner
        self.clock = clock
    }

    public func run(_ request: SubagentRequest) throws -> SubagentTask {
        guard !request.parentSessionID.isEmpty, !request.agentID.isEmpty else {
            throw PraxoError("SUBAGENT_INVALID",
                             "agent: subagent parent session and agent id are required")
        }
        let timestamp = ISO8601DateFormatter().string(from: clock())
        var task = SubagentTask(
            id: "subagent",
            parentSessionID: request.parentSessionID,
            agentID: request.agentID,
            mode: request.mode == "fork" ? "fork" : "isolated",
            status: "running",
            output: "",
            error: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        do {
            let result = try runner(request)
            task.status = "completed"
            task.output = result.output
        } catch let error as PraxoError {
            task.status = "failed"
            task.error = error.code
        } catch {
            task.status = "failed"
            task.error = "SUBAGENT_ERROR"
        }
        return task
    }
}
