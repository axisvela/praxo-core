import io.axisvela.praxo.agent.Agent
import io.axisvela.praxo.agent.AgentOptions
import io.axisvela.praxo.agent.Session
import io.axisvela.praxo.model.Message
import io.axisvela.praxo.model.Model
import io.axisvela.praxo.model.Request
import io.axisvela.praxo.model.Response
import io.axisvela.praxo.tool.FuncTool
import io.axisvela.praxo.tool.Registry

fun main() {
    val model = object : Model {
        override fun generate(request: Request): Response =
            Response.of(Message.of("assistant", "hello from Kotlin"))
    }

    val registry = Registry()
    registry.register(FuncTool("echo", "Echo arguments") { arguments -> arguments })

    val options = AgentOptions(model)
    options.tools = registry
    options.maxSteps = 4

    val result = Agent(options).run(Session("demo"), "hello")
    check(result.output == "hello from Kotlin") { "unexpected output: ${result.output}" }
    println(result.output)
}
