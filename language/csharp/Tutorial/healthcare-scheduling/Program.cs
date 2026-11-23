using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.HealthcareScheduling;

public static class Program
{
    public sealed record ReviewResult(string Output, int Reads, int Drafts);

    private sealed class FixtureModel(string appointmentId) : IModel
    {
        public Response Generate(Request request)
        {
            int tools = request.Messages.Count(message => message.Role == Roles.Tool);
            if (tools == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "schedule-1", Name = "read_schedule",
                            Arguments = new JsonObject { ["appointment_id"] = appointmentId },
                        },
                    }),
                };
            }
            if (tools == 1)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "booking-1", Name = "draft_booking",
                            Arguments = new JsonObject
                            {
                                ["appointment_id"] = appointmentId,
                                ["action"] = "reserve_slot",
                            },
                        },
                    }),
                };
            }
            var schedule = JsonNode.Parse(
                request.Messages.First(message => message.Role == Roles.Tool).Content!)!;
            var booking = JsonNode.Parse(
                request.Messages.Last(message => message.Role == Roles.Tool).Content!)!;
            var report = new JsonObject
            {
                ["stage"] = "booking_drafted",
                ["schedule"] = schedule.DeepClone(),
                ["booking"] = booking.DeepClone(),
                ["booking_writes"] = 0,
            };
            return new Response { Message = Message.Assistant(report.ToJsonString()) };
        }
    }

    public sealed class ReadScheduleTool(int[] reads, bool simulateFailure)
        : ITool, IToolSpecProvider
    {
        public string Name => "read_schedule";
        public string Description => "Read a fixed clinic schedule fixture; no writes.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "read",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["appointment_id"],"properties":{"appointment_id":{"type":"string"}}}
                """)!.AsObject(),
        };

        public JsonNode? Invoke(JsonObject arguments)
        {
            reads[0]++;
            if (simulateFailure)
                throw new InvalidOperationException("simulated scheduling dependency unavailable");
            if (arguments["appointment_id"]?.GetValue<string>() != "appointment-100")
                throw new InvalidOperationException("appointment not found");
            return new JsonObject
            {
                ["appointment_id"] = "appointment-100",
                ["slot_id"] = "slot-100",
                ["clinician"] = "dr-7",
                ["date"] = "2026-12-01",
                ["available"] = true,
                ["existing_bookings"] = 2,
            };
        }
    }

    public sealed class DraftBookingTool(int[] drafts) : ITool, IToolSpecProvider
    {
        public string Name => "draft_booking";
        public string Description => "Draft a booking for human review; never writes the schedule.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "write",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["appointment_id","action"],"properties":{"appointment_id":{"type":"string"},"action":{"type":"string"}}}
                """)!.AsObject(),
        };

        public JsonNode? Invoke(JsonObject arguments)
        {
            drafts[0]++;
            if (arguments["appointment_id"]?.GetValue<string>() != "appointment-100")
                throw new InvalidOperationException("appointment not found");
            if (arguments["action"]?.GetValue<string>() != "reserve_slot")
                throw new InvalidOperationException("invalid booking action");
            return new JsonObject
            {
                ["booking_id"] = "booking-100",
                ["appointment_id"] = "appointment-100",
                ["slot_id"] = "slot-100",
                ["status"] = "draft_only",
                ["review_required"] = true,
                ["booking_writes"] = 0,
            };
        }
    }

    private sealed class SchedulingPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("fixture model");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            string? appointment = action.Arguments?["appointment_id"]?.GetValue<string>();
            if (appointment != "appointment-100")
                return Decision.Deny("appointment outside scheduling scope");
            if (action.ToolName == "read_schedule")
                return Decision.Allow("read-only schedule fixture");
            if (action.ToolName == "draft_booking")
            {
                string? act = action.Arguments?["action"]?.GetValue<string>();
                return act == "reserve_slot"
                    ? Decision.Allow("review-only booking draft")
                    : Decision.Deny("invalid booking action");
            }
            return Decision.Deny("unsupported tool");
        }
    }

    public static ReviewResult Review(string appointmentId, bool simulateFailure)
    {
        int[] reads = [0];
        int[] drafts = [0];
        var tools = new ToolRegistry();
        tools.Register(new ReadScheduleTool(reads, simulateFailure));
        tools.Register(new DraftBookingTool(drafts));
        var options = new AgentOptions(new FixtureModel(appointmentId))
        {
            Tools = tools,
            AllowedTools = new List<string> { "read_schedule", "draft_booking" },
            Policy = new SchedulingPolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 4,
        };
        var result = new Agent(options).Run(new Session("healthcare-scheduling"),
            "Read the fixed schedule and draft a booking only.");
        return new ReviewResult(result.Output, reads[0], drafts[0]);
    }

    private static void Check(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException($"Failed: {name}");
    }

    private static void RunTests()
    {
        var success = Review("appointment-100", false);
        var report = JsonNode.Parse(success.Output)!;
        Check(success.Reads == 1 && success.Drafts == 1, "native call counts");
        Check(report["schedule"]!["available"]!.GetValue<bool>(), "slot available");
        Check(report["booking"]!["status"]!.GetValue<string>() == "draft_only",
            "native draft status");
        Check(report["booking"]!["review_required"]!.GetValue<bool>(), "review required");
        Check(report["booking_writes"]!.GetValue<int>() == 0, "zero booking writes");

        try
        {
            Review("appointment-200", false);
            throw new InvalidOperationException("out-of-scope appointment was accepted");
        }
        catch (PraxoException error) when (error.Code == "AGENT_POLICY_DENIED") { }

        try
        {
            Review("appointment-100", true);
            throw new InvalidOperationException("simulated scheduling failure did not fail");
        }
        catch (Exception error) when (error.Message.Contains("simulated scheduling")) { }

        Console.WriteLine("C# healthcare-scheduling tutorial: all checks passed");
    }

    public static int Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            RunTests();
            return 0;
        }
        string appointment = "appointment-100";
        int index = Array.IndexOf(args, "--appointment");
        if (index >= 0 && index + 1 < args.Length) appointment = args[index + 1];
        bool simulateFailure = args.Contains("--simulate-failure");
        try
        {
            Console.WriteLine(Review(appointment, simulateFailure).Output);
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
