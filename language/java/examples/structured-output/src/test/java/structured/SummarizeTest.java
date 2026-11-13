package structured;

import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.util.Json;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

class SummarizeTest {
    static final class FakeModel implements Model {
        @Override
        public Response generate(Request request) {
            return Response.of(Message.assistant(
                    "{\"title\":\"Release status\","
                            + "\"summary\":\"All checks are green.\","
                            + "\"tags\":[\"release\",\"status\"]}",
                    List.of()));
        }
    }

    @Test
    void summaryMatchesSchema() throws Exception {
        String output = Summarize.summarize(
                "Quarterly status: all checks green.", new FakeModel());
        Map<String, Object> data = Json.object(output);
        assertEquals(List.of("summary", "tags", "title"), data.keySet().stream().sorted().toList());
        assertInstanceOf(List.class, data.get("tags"));
    }
}
