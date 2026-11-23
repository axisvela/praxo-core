const {
  Agent,
  FuncHook,
  PolicyDeniedError,
  Registry,
  ROLE_ASSISTANT,
  ROLE_TOOL,
} = require("@axisvela/praxo-core");

const TRIP = {
  id: "trip-100",
  fare_id: "fare-100",
  route: "AMS-SIN",
  seats_left: 4,
  price: 640,
  refundable: true,
};

class BookingModel {
  constructor(tripId) {
    this.tripId = tripId;
  }

  async generate(request) {
    const toolMessages = request.messages.filter((message) => message.role === ROLE_TOOL);
    if (toolMessages.length === 0) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "inventory-1", name: "check_inventory",
            arguments: { trip_id: this.tripId },
          }],
        },
      };
    }
    if (toolMessages.length === 1) {
      return {
        message: {
          role: ROLE_ASSISTANT,
          toolCalls: [{
            id: "booking-1", name: "draft_booking",
            arguments: { trip_id: this.tripId, action: "hold_fare" },
          }],
        },
      };
    }
    const inventory = JSON.parse(toolMessages[0].content);
    const booking = JSON.parse(toolMessages[1].content);
    return {
      message: {
        role: ROLE_ASSISTANT,
        content: JSON.stringify({
          stage: "booking_drafted",
          inventory,
          booking,
          bookings_writes: 0,
        }),
      },
    };
  }
}

function buildPolicy() {
  return new FuncHook((action) => {
    if (action.kind === "model.generate") return { allowed: true };
    if (action.kind !== "tool.invoke") return { allowed: false, reason: "unsupported action" };
    if (action.toolName === "check_inventory") {
      return {
        allowed: action.arguments?.trip_id === "trip-100",
        reason: "only trip-100 is in booking scope",
      };
    }
    if (action.toolName === "draft_booking") {
      return {
        allowed: action.arguments?.trip_id === "trip-100" &&
          action.arguments?.action === "hold_fare",
        reason: "only a trip-100 hold_fare draft is allowed",
      };
    }
    return { allowed: false, reason: "unsupported tool" };
  });
}

async function runBooking(tripId, { simulateFailure = false } = {}) {
  let inventoryCalls = 0;
  let bookingCalls = 0;
  const tools = new Registry();
  tools.register({
    name: "check_inventory",
    description: "Read the fixed flight inventory fixture; no writes.",
    risk: "read",
    parameters: {
      type: "object", required: ["trip_id"],
      properties: { trip_id: { type: "string" } },
    },
    async invoke(args) {
      inventoryCalls += 1;
      if (simulateFailure) throw new Error("simulated inventory unavailable");
      if (args.trip_id !== TRIP.id) throw new Error("trip not found");
      return TRIP;
    },
  });
  tools.register({
    name: "draft_booking",
    description: "Draft a fare hold for human review; never pays or books.",
    risk: "write",
    parameters: {
      type: "object", required: ["trip_id", "action"],
      properties: { trip_id: { type: "string" }, action: { type: "string" } },
    },
    async invoke(args) {
      bookingCalls += 1;
      if (args.trip_id !== TRIP.id) throw new Error("trip not found");
      if (args.action !== "hold_fare") throw new Error("invalid booking action");
      return {
        booking_id: "booking-100",
        trip_id: TRIP.id,
        status: "draft_only",
        review_required: true,
        payment_executed: false,
        bookings_writes: 0,
      };
    },
  });
  const agent = new Agent({
    model: new BookingModel(tripId),
    tools,
    maxSteps: 4,
    allowedTools: ["check_inventory", "draft_booking"],
    policy: buildPolicy(),
    systemPrompt: "Check fixed inventory and draft a review-only booking.",
  });
  const result = await agent.run(
    { id: "travel-booking" },
    "Check the fixed trip inventory and draft a booking.",
  );
  return { output: result.output, inventoryCalls, bookingCalls };
}

async function test() {
  const assert = require("node:assert/strict");
  const success = await runBooking("trip-100");
  const report = JSON.parse(success.output);
  assert.equal(success.inventoryCalls, 1);
  assert.equal(success.bookingCalls, 1);
  assert.equal(report.inventory.seats_left, 4);
  assert.equal(report.booking.status, "draft_only");
  assert.equal(report.booking.payment_executed, false);
  assert.equal(report.bookings_writes, 0);

  await assert.rejects(
    () => runBooking("trip-200"),
    (error) => error instanceof PolicyDeniedError,
  );
  await assert.rejects(
    () => runBooking("trip-100", { simulateFailure: true }),
    (error) => /simulated inventory/.test(error.message),
  );

  console.log("TypeScript travel-booking tutorial: all checks passed");
}

if (require.main === module) {
  if (process.argv.includes("--test")) {
    test().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
  } else {
    const index = process.argv.indexOf("--trip");
    const trip = index >= 0 ? process.argv[index + 1] : "trip-100";
    const simulateFailure = process.argv.includes("--simulate-failure");
    runBooking(trip, { simulateFailure })
      .then((result) => console.log(result.output))
      .catch((error) => {
        console.error(error.message);
        process.exitCode = 1;
      });
  }
}

module.exports = { runBooking, BookingModel };
