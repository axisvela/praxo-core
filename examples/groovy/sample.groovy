import com.axisvela.praxo.agent.Agent
import com.axisvela.praxo.agent.AgentOptions
import com.axisvela.praxo.agent.Session
import com.axisvela.praxo.model.Message
import com.axisvela.praxo.model.Model
import com.axisvela.praxo.model.Request
import com.axisvela.praxo.model.Response

def model = new Model() {
    Response generate(Request request) {
        return Response.of(Message.of("assistant", "hello from Groovy"))
    }
}

def result = new Agent(new AgentOptions(model)).run(new Session("demo"), "hello")
assert result.output == "hello from Groovy"
println "Groovy sample passed: ${result.output}"
