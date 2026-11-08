package starter;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.Version;
import com.axisvela.praxo.agent.Session;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AppTest {
    @Test
    void allowedToolRunsOnce() throws Exception {
        var built = App.buildAgent("public");
        var result = built.agent().run(
                new Session("test-public"), "Record the requested target.");
        assertEquals("recorded", result.output);
        assertEquals(1, built.tool().calls());
    }

    @Test
    void deniedToolHasNoEffect() {
        var built = App.buildAgent("private");
        PraxoException error = assertThrows(PraxoException.class, () -> built.agent().run(
                new Session("test-private"), "Record the requested target."));
        assertEquals("AGENT_POLICY_DENIED", error.code);
        assertEquals(0, built.tool().calls());
    }

    @Test
    void starterOutputIsDeterministic() throws Exception {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        try (PrintStream out = new PrintStream(buffer, true, StandardCharsets.UTF_8)) {
            App.run(out);
        }
        String expected = "allow: recorded; effects=1" + System.lineSeparator()
                + "deny: policy rejected; effects=0" + System.lineSeparator();
        assertEquals(expected, buffer.toString(StandardCharsets.UTF_8));
    }

    @Test
    void dependencyComesFromPublishedJar() throws Exception {
        assertEquals("0.4.1", Version.SDK_VERSION);
        URL location = Version.class.getProtectionDomain().getCodeSource().getLocation();
        String filename = Path.of(location.toURI()).getFileName().toString();
        assertEquals("praxo-core-0.4.1.jar", filename);
        assertTrue(location.toURI().toString().contains("/com/axisvela/praxo-core/0.4.1/"));
    }
}
