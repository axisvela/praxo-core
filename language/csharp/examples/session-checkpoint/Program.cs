using System.Text.Json;
using System.Text.Json.Nodes;

using Praxo.Core;

namespace Praxo.SessionCheckpoint;

public static class Program
{
    private sealed class TurnModel : IModel
    {
        public Response Generate(Request request) => new()
        {
            Message = Message.Assistant($"turn {request.Messages.Count}"),
        };
    }

    private sealed class MemoryStore
    {
        private readonly Dictionary<string, string> _records = new();

        public void Save(string sessionId, string payload)
        {
            _records[sessionId] = payload;
        }

        public string? Load(string sessionId)
            => _records.GetValueOrDefault(sessionId);
    }

    private static string Marshal(CheckpointAllowlist allowlist, Session session)
    {
        var messages = JsonSerializer.Serialize(session.Messages);
        return allowlist.Marshal("session", JsonValue.Create(messages));
    }

    private static List<Message> Unmarshal(CheckpointAllowlist allowlist, string payload)
    {
        var raw = allowlist.Unmarshal(payload)?.GetValue<string>()
            ?? throw new InvalidOperationException("checkpoint payload is empty");
        return JsonSerializer.Deserialize<List<Message>>(raw)
            ?? throw new InvalidOperationException("checkpoint messages are invalid");
    }

    public static int Main()
    {
        var allowlist = new CheckpointAllowlist();
        allowlist.Register("session");
        var store = new MemoryStore();
        var session = new Session("session-1")
        {
            Messages =
            {
                new Message { Role = Roles.User, Content = "first" },
                Message.Assistant("ack"),
            },
        };
        store.Save(session.Id, Marshal(allowlist, session));

        var agent = new Agent(new AgentOptions(new TurnModel()) { MaxSteps = 2 });

        var stored = store.Load(session.Id)
            ?? throw new InvalidOperationException("checkpoint not found");
        session.Messages = Unmarshal(allowlist, stored);
        var result = agent.Run(session, "second");
        if (result.Output != "turn 3")
        {
            Console.Error.WriteLine($"unexpected second turn: {result.Output}");
            return 1;
        }

        session.Messages.Add(new Message { Role = Roles.User, Content = "second" });
        session.Messages.Add(Message.Assistant(result.Output));
        store.Save(session.Id, Marshal(allowlist, session));

        stored = store.Load(session.Id)
            ?? throw new InvalidOperationException("checkpoint not found");
        session.Messages = Unmarshal(allowlist, stored);
        result = agent.Run(session, "third");
        if (result.Output != "turn 5")
        {
            Console.Error.WriteLine($"unexpected third turn: {result.Output}");
            return 1;
        }

        Console.WriteLine($"restored messages: {session.Messages.Count}");
        Console.WriteLine($"output: {result.Output}");
        return 0;
    }
}
