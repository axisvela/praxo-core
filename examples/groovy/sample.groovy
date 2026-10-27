import io.axisvela.praxo.agent.Agent
import io.axisvela.praxo.agent.AgentOptions
import io.axisvela.praxo.agent.Session
import io.axisvela.praxo.model.Message
import io.axisvela.praxo.model.Model
import io.axisvela.praxo.model.Request
import io.axisvela.praxo.model.Response

def model = new Model() {
    Response generate(Request request) {
        return Response.of(Message.of("assistant", "hello from Groovy"))
    }
}

def result = new Agent(new AgentOptions(model)).run(new Session("demo"), "hello")
assert result.output == "hello from Groovy"
println "Groovy sample passed: ${result.output}"
