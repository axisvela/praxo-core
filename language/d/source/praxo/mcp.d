module praxo.mcp;

import core.time : Duration, seconds;
import std.conv : to;
import std.file : exists, readText, remove, tempDir, write;
import std.format : format;
import std.json : JSONType, JSONValue;
import std.path : buildPath;
import std.process : ProcessPipes, Redirect, execute, kill, pipeProcess;
import std.algorithm.sorting : sort;
import std.random : uniform;
import std.stdio : File;
import std.string : indexOf, join, lastIndexOf, replace, split, startsWith, strip, toLower;

import praxo.errors : PraxoError;
import praxo.json : get, getArray, getBool, getInt, getString, hasKey, parse, stringify;

interface McpTransport {
    JSONValue request(string method, JSONValue params, Duration timeout);
    void notify(string method, JSONValue params);
    void close();
}

class McpToolInfo {
    string name;
    string description;
    JSONValue inputSchema;

    this(JSONValue value) {
        name = getString(value, "name");
        if (name.length == 0) {
            throw new PraxoError("MCP_PROTOCOL", "mcp: tool name is required");
        }
        description = getString(value, "description");
        if (description is null) description = "";
        inputSchema = get(value, "inputSchema");
        if (inputSchema.type != JSONType.object) {
            throw new PraxoError("MCP_PROTOCOL",
                "mcp: missing input schema for " ~ name);
        }
    }
}

class McpClient {
    McpTransport transport;
    string clientVersion;
    Duration timeout;
    string requestedProtocolVersion;
    string protocolVersion;
    JSONValue serverInfo;

    this(McpTransport transport,
         string protocolVersion = "2024-11-05",
         string clientVersion = "0.4.0",
         Duration timeout = 30.seconds) {
        this.transport = transport;
        this.requestedProtocolVersion = protocolVersion;
        this.clientVersion = clientVersion;
        this.timeout = timeout;
        this.serverInfo = emptyObject();
    }

    McpClient start() {
        if (protocolVersion.length > 0) return this;
        JSONValue[string] info;
        info["name"] = JSONValue("praxo-core");
        info["version"] = JSONValue(clientVersion);
        JSONValue[string] params;
        params["protocolVersion"] = JSONValue(requestedProtocolVersion);
        params["capabilities"] = emptyObject();
        params["clientInfo"] = JSONValue(info);
        auto result = transport.request("initialize", JSONValue(params), timeout);
        auto negotiated = getString(result, "protocolVersion");
        if (negotiated is null || negotiated.length == 0) {
            throw new PraxoError("MCP_HANDSHAKE",
                "mcp: initialize returned no protocol version");
        }
        protocolVersion = negotiated;
        serverInfo = get(result, "serverInfo");
        JSONValue[string] empty;
        transport.notify("notifications/initialized", JSONValue(empty));
        return this;
    }

    McpToolInfo[] listTools() {
        start();
        McpToolInfo[] tools;
        bool[string] names;
        bool[string] cursors;
        string cursor;
        while (true) {
            JSONValue[string] params;
            if (cursor.length > 0) params["cursor"] = JSONValue(cursor);
            auto result = transport.request("tools/list", JSONValue(params), timeout);
            foreach (item; getArray(result, "tools")) {
                auto tool = new McpToolInfo(item);
                if (tool.name in names) {
                    throw new PraxoError("MCP_DUPLICATE_TOOL",
                        "mcp: duplicate tool " ~ tool.name);
                }
                names[tool.name] = true;
                tools ~= tool;
            }
            auto next = getString(result, "nextCursor");
            if (next is null || next.length == 0) break;
            if (next in cursors) {
                throw new PraxoError("MCP_PAGINATION",
                    "mcp: repeated tool pagination cursor");
            }
            cursors[next] = true;
            cursor = next;
        }
        // Tools are returned in the server order.
        return tools;
    }

    JSONValue callTool(string name, JSONValue arguments = JSONValue(null)) {
        start();
        if (arguments.type != JSONType.object) arguments = emptyObject();
        JSONValue[string] params;
        params["name"] = JSONValue(name);
        params["arguments"] = arguments;
        auto result = transport.request("tools/call", JSONValue(params), timeout);
        if (getBool(result, "isError")) {
            throw new PraxoError("MCP_TOOL_ERROR", "mcp: tool " ~ name ~ " failed");
        }
        if (hasKey(result, "structuredContent")) {
            return get(result, "structuredContent");
        }
        JSONValue[] texts;
        foreach (item; getArray(result, "content")) {
            if (getString(item, "type") == "text") {
                texts ~= JSONValue(getString(item, "text"));
            }
        }
        if (texts.length == 0) return JSONValue(null);
        if (texts.length == 1) return texts[0];
        return JSONValue(texts);
    }

    void close() {
        transport.close();
        protocolVersion = "";
    }
}

class StdioMcpTransport : McpTransport {
    private string[] command;
    private Duration timeout;
    private ProcessPipes pipes;
    private bool started;
    private bool closed;
    private int nextId;

    this(string[] command, Duration timeout = 30.seconds) {
        this.command = command;
        this.timeout = timeout;
    }

    void start() {
        if (started) return;
        pipes = pipeProcess(command,
            Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout);
        started = true;
    }

    JSONValue request(string method, JSONValue params, Duration requestTimeout) {
        start();
        nextId++;
        auto id = nextId;
        JSONValue[string] message;
        message["jsonrpc"] = JSONValue("2.0");
        message["id"] = JSONValue(cast(long) id);
        message["method"] = JSONValue(method);
        message["params"] = params;
        pipes.stdin.writeln(stringify(JSONValue(message)));
        pipes.stdin.flush();
        while (true) {
            auto line = pipes.stdout.readln();
            if (line.length == 0) {
                throw new PraxoError("MCP_CLOSED", "mcp: connection closed");
            }
            auto response = parse(line);
            if (getInt(response, "id") != id) continue;
            if (hasKey(response, "error")) {
                throw new PraxoError("MCP_RPC", "mcp: " ~ method ~ " failed");
            }
            return get(response, "result");
        }
    }

    void notify(string method, JSONValue params) {
        start();
        JSONValue[string] message;
        message["jsonrpc"] = JSONValue("2.0");
        message["method"] = JSONValue(method);
        message["params"] = params;
        pipes.stdin.writeln(stringify(JSONValue(message)));
        pipes.stdin.flush();
    }

    void close() {
        if (closed) return;
        closed = true;
        if (started) {
            try pipes.stdin.close();
            catch (Exception) {}
            try pipes.stdout.close();
            catch (Exception) {}
            try kill(pipes.pid);
            catch (Exception) {}
        }
    }
}

class HttpMcpTransport : McpTransport {
    private string endpoint;
    private string[string] headers;
    private string protocolVersion;
    private string sessionId;
    private int nextId;
    private bool closed;

    this(string endpoint, string[string] headers = null,
         string protocolVersion = "2025-03-26") {
        auto lower = endpoint.toLower;
        if (!lower.startsWith("https://") && !lower.startsWith("http://")) {
            throw new PraxoError("MCP_TRANSPORT", "mcp: invalid HTTP endpoint");
        }
        if (lower.startsWith("http://") && !loopback(endpoint)) {
            throw new PraxoError("MCP_TRANSPORT",
                "mcp: HTTP endpoint must use HTTPS");
        }
        this.endpoint = endpoint;
        this.headers = headers;
        this.protocolVersion = protocolVersion;
    }

    JSONValue request(string method, JSONValue params, Duration timeout) {
        if (closed) throw new PraxoError("MCP_CLOSED", "mcp: client is closed");
        nextId++;
        JSONValue[string] message;
        message["jsonrpc"] = JSONValue("2.0");
        message["id"] = JSONValue(cast(long) nextId);
        message["method"] = JSONValue(method);
        message["params"] = params;
        auto response = post(JSONValue(message), timeout);
        if (hasKey(response, "error")) {
            throw new PraxoError("MCP_RPC", "mcp: " ~ method ~ " failed");
        }
        return get(response, "result");
    }

    void notify(string method, JSONValue params) {
        if (closed) return;
        JSONValue[string] message;
        message["jsonrpc"] = JSONValue("2.0");
        message["method"] = JSONValue(method);
        message["params"] = params;
        try post(JSONValue(message), 30.seconds);
        catch (Exception) {}
    }

    void close() {
        if (closed) return;
        closed = true;
        if (sessionId.length == 0) return;
        try {
            string[] command = ["curl", "-sS", "-X", "DELETE"];
            command ~= headerArgs();
            command ~= ["-H", "mcp-session-id: " ~ sessionId];
            command ~= [endpoint];
            execute(command);
        } catch (Exception) {}
    }

    private JSONValue post(JSONValue message, Duration timeout) {
        auto bodyFile = buildPath(tempDir(),
            "praxo-mcp-" ~ uniform(0, 2_000_000_000).to!string ~ ".json");
        auto headerFile = bodyFile ~ ".headers";
        write(bodyFile, stringify(message));
        scope(exit) {
            remove(bodyFile);
            remove(headerFile);
        }
        string[] command = ["curl", "-sS", "-X", "POST", "-D", headerFile];
        command ~= headerArgs();
        if (sessionId.length > 0) {
            command ~= ["-H", "mcp-session-id: " ~ sessionId];
        }
        command ~= ["--data-binary", "@" ~ bodyFile,
            "-w", "\n%{http_code}", endpoint];
        auto result = execute(command);
        auto text = result.output;
        auto index = text.lastIndexOf('\n');
        int status = 0;
        string body = text;
        if (index >= 0) {
            body = text[0 .. index];
            try status = strip(text[index + 1 .. $]).to!int;
            catch (Exception) {}
        }
        string contentType = "";
        if (headerFile.exists) {
            foreach (line; readText(headerFile).split("\n")) {
                auto colon = line.indexOf(':');
                if (colon < 0) continue;
                auto key = strip(line[0 .. cast(size_t) colon]).toLower;
                auto value = strip(line[cast(size_t)(colon + 1) .. $]);
                if (key == "mcp-session-id") sessionId = value;
                if (key == "content-type") contentType = value;
            }
        }
        if (status == 202 || status == 204 || strip(body).length == 0) {
            return emptyObject();
        }
        if (status < 200 || status >= 300) {
            throw new PraxoError("MCP_TRANSPORT",
                "mcp: HTTP " ~ status.to!string ~ ": " ~ bounded(body));
        }
        JSONValue decoded;
        if (contentType.toLower.indexOf("text/event-stream") >= 0) {
            decoded = parseSse(body);
        } else {
            try decoded = parse(body);
            catch (Exception) {
                throw new PraxoError("MCP_PROTOCOL", "mcp: server sent invalid JSON");
            }
        }
        if (hasKey(decoded, "result")) {
            auto resultValue = get(decoded, "result");
            auto negotiated = getString(resultValue, "protocolVersion");
            if (negotiated !is null && negotiated.length > 0) protocolVersion = negotiated;
        }
        return decoded;
    }

    private string[] headerArgs() {
        string[] args = [
            "content-type: application/json",
            "accept: application/json, text/event-stream",
            "mcp-protocol-version: " ~ protocolVersion,
        ];
        foreach (key, value; headers) args ~= key ~ ": " ~ value;
        string[] command;
        foreach (header; args) command ~= ["-H", header];
        return command;
    }
}

JSONValue emptyObject() {
    JSONValue[string] value;
    return JSONValue(value);
}

JSONValue parseSse(string body) {
    JSONValue[] messages;
    string[] data;
    foreach (line; body.replace("\r\n", "\n").split("\n")) {
        if (line.length == 0) {
            if (data.length > 0) {
                messages ~= parse(data.join("\n"));
                data = [];
            }
            continue;
        }
        if (line.startsWith(":")) continue;
        if (line.startsWith("data:")) {
            data ~= strip(line[5 .. $]);
        }
    }
    if (data.length > 0) messages ~= parse(data.join("\n"));
    if (messages.length == 0) {
        throw new PraxoError("MCP_PROTOCOL", "mcp: response contained no message");
    }
    return messages[0];
}

string bounded(string body) {
    return body.length > 512 ? body[0 .. 512] : body;
}

bool loopback(string endpoint) {
    auto start = endpoint.indexOf("://") + 3;
    if (start < 3) return false;
    auto rest = endpoint[start .. $];
    auto slash = rest.indexOf('/');
    auto host = slash < 0 ? rest : rest[0 .. slash];
    auto colon = host.indexOf(':');
    if (colon >= 0) host = host[0 .. colon];
    host = host.toLower;
    return host == "localhost" || host == "127.0.0.1" || host == "::1" ||
        host.startsWith("127.");
}
