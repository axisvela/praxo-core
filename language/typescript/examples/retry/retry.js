const {
  Agent,
  PraxoError,
  ROLE_ASSISTANT,
} = require("@axisvela/praxo-core");

const RETRYABLE = new Set(["MODEL_UNAVAILABLE"]);

class ModelUnavailableError extends PraxoError {
  constructor(message) {
    super(message, "MODEL_UNAVAILABLE");
    this.name = "ModelUnavailableError";
  }
}

function retryModel(maxAttempts = 3) {
  return (next) => async (request) => {
    let lastError;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        return await next(request);
      } catch (error) {
        lastError = error;
        if (!RETRYABLE.has(error.code) || attempt === maxAttempts) throw error;
      }
    }
    throw lastError ?? new ModelUnavailableError("model unavailable");
  };
}

async function run(model, maxAttempts = 3, prompt = "Check the status.") {
  const agent = new Agent({
    model,
    modelMiddleware: [retryModel(maxAttempts)],
    maxSteps: 2,
  });
  const result = await agent.run({ id: "retry" }, prompt);
  return result.output;
}

class FlakyModel {
  constructor(failures) {
    this.failures = failures;
    this.calls = 0;
  }

  async generate() {
    this.calls += 1;
    if (this.calls <= this.failures) {
      throw new ModelUnavailableError("temporary outage");
    }
    return { message: { role: ROLE_ASSISTANT, content: "status: green" } };
  }
}

module.exports = {
  FlakyModel,
  ModelUnavailableError,
  retryModel,
  run,
};
