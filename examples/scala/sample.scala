import io.axisvela.praxo.agent.{Agent, AgentOptions, Session}
import io.axisvela.praxo.model.{Message, Model, Request, Response}
import io.axisvela.praxo.tool.{FuncTool, Registry}

object Sample:
  def main(args: Array[String]): Unit =
    val model = new Model:
      override def generate(request: Request): Response =
        Response.of(Message.of("assistant", "hello from Scala"))

    val registry = new Registry()
    registry.register(new FuncTool("echo", "Echo arguments", arguments => arguments))

    val options = new AgentOptions(model)
    options.tools = registry
    options.maxSteps = 4

    val result = new Agent(options).run(new Session("demo"), "hello")
    if result.output != "hello from Scala" then
      throw new IllegalStateException(s"unexpected output: ${result.output}")
    println(result.output)
