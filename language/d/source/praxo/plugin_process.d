module praxo.plugin_process;

import core.time : Duration;
import std.base64 : Base64;
import std.json : JSONValue;
import std.process : Config, Pipe, Pid, pipe, spawnProcess, wait;
import std.conv : to;
import std.format : format;
import std.random : uniform;
import std.stdio : File, stderr;
import std.string : strip;
import praxo.json;

enum PROTOCOL_VERSION = 1;
enum CONTROL_SERVICE = "host.control";
enum METHOD_HEALTH = "health";
enum METHOD_SHUTDOWN = "shutdown";
enum DEFAULT_TOKEN_ENV = "PRAXOVELA_PLUGIN_TOKEN";

struct ProcessConfig {
    string pluginId;
    string path;
    string[] args;
    string token;
    Duration startTimeout;
    Duration invokeTimeout;
}

class ProcessHost {
    private ProcessConfig config;
    private Pipe inputPipe;
    private Pipe outputPipe;
    private File input;
    private File output;
    private Pid pid;
    private string token;
    private int seq;
    private bool started;
    bool active;

    this(ProcessConfig config) {
        if (config.pluginId.length == 0)
            throw new Exception("plugin: PluginID is required");
        if (config.path.length == 0)
            throw new Exception("plugin: path is required");
        this.config = config;
        this.token = config.token.length ? config.token
            : format("%016x%016x", uniform!ulong, uniform!ulong);
    }

    void start() {
        if (started)
            throw new Exception("plugin: host already started");
        inputPipe = pipe();
        outputPipe = pipe();
        string[string] env = [DEFAULT_TOKEN_ENV: token];
        pid = spawnProcess([config.path] ~ config.args,
            inputPipe.readEnd, outputPipe.writeEnd, stderr, env);
        inputPipe.readEnd.close();
        outputPipe.writeEnd.close();
        input = inputPipe.writeEnd;
        output = outputPipe.readEnd;
        started = true;
        try {
            call(CONTROL_SERVICE, METHOD_HEALTH, []);
        } catch (Exception error) {
            stop();
            throw error;
        }
        started = true;
        active = true;
    }

    ubyte[] invoke(string service, string method, string payload = "") {
        if (!active)
            throw new Exception("plugin: host is not active");
        return call(service, method, cast(const(ubyte)[]) payload);
    }

    ubyte[] call(string service, string method, const(ubyte)[] payload) {
        seq++;
        JSONValue frame;
        frame["id"] = JSONValue("req-" ~ seq.to!string);
        frame["version"] = JSONValue(PROTOCOL_VERSION);
        frame["plugin_id"] = JSONValue(config.pluginId);
        frame["service"] = JSONValue(service);
        frame["method"] = JSONValue(method);
        frame["token"] = JSONValue(token);
        frame["payload"] = JSONValue(Base64.encode(payload));
        input.writeln(stringify(frame));
        input.flush();
        const line = output.readln();
        if (line.length == 0)
            throw new Exception("plugin: process closed the stream");
        auto response = parse(line.strip);
        if (!getBool(response, "ok"))
            throw new Exception(fallbackMessage(response));
        auto encoded = getString(response, "payload");
        return encoded.length ? Base64.decode(encoded) : [];
    }

    void stop() {
        if (started && active) {
            try {
                call(CONTROL_SERVICE, METHOD_SHUTDOWN, []);
            } catch (Exception) {
            }
        }
        active = false;
        if (started) {
            input.close();
            output.close();
        }
        if (pid !is null)
            wait(pid);
        started = false;
        pid = null;
    }
}

private string fallbackMessage(JSONValue response) {
    auto message = getString(response, "message");
    if (message.length)
        return message;
    auto code = getString(response, "code");
    return code.length ? code : "plugin: call failed";
}
