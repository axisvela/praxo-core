import com.axisvela.praxo.agent.Agent
import com.axisvela.praxo.agent.AgentOptions
import com.axisvela.praxo.agent.Session
import com.axisvela.praxo.model.Message
import com.axisvela.praxo.model.Model
import com.axisvela.praxo.model.Request
import com.axisvela.praxo.model.Response
import com.axisvela.praxo.tool.FuncTool
import com.axisvela.praxo.tool.Registry

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
