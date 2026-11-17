const { Agent, Registry } = require("@axisvela/praxo-core");

class BudgetExhausted extends Error {
  constructor(message = "delegation budget exhausted") {
    super(message);
    this.name = "BudgetExhausted";
  }
}

class DelegationError extends Error {
  constructor(message) {
    super(message);
    this.name = "DelegationError";
  }
}

class SharedBudget {
  constructor(remaining) {
    this.remaining = remaining;
  }

  available() {
    return this.remaining > 0;
  }

  take() {
    if (this.remaining <= 0) return false;
    this.remaining -= 1;
    return true;
  }
}

class ComposedPolicy {
  constructor(hooks) {
    this.hooks = hooks.filter((hook) => hook !== null && hook !== undefined);
  }

  async authorize(action) {
    for (const hook of this.hooks) {
      const decision = await hook.authorize(action);
      if (!decision.allowed) return decision;
    }
    return { allowed: true, reason: "delegation policy chain allowed" };
  }
}

class BudgetedTool {
  constructor(inner, budget) {
    this.inner = inner;
    this.budget = budget;
    this.name = inner.name;
    this.description = inner.description;
    this.risk = inner.risk;
    this.parameters = inner.parameters;
  }

  async invoke(args) {
    if (!this.budget.take()) throw new BudgetExhausted();
    return this.inner.invoke(args);
  }
}

class ChildScope {
  constructor(authority, release) {
    this.authority = authority;
    this.release = release;
  }

  async run(model, tools, prompt, options = {}) {
    const names = [...this.authority.allowed].sort();
    const scoped = new Registry();
    for (const name of names) {
      scoped.register(new BudgetedTool(tools.get(name), this.authority.budget));
    }
    const agent = new Agent({
      model,
      tools: scoped,
      maxSteps: 3,
      allowedTools: names,
      policy: this.authority.policy,
      middleware: options.middleware || [],
      signal: options.signal,
      requirePolicy: true,
      requireToolScope: true,
    });
    return agent.run({ id: "governed-delegation-child" }, prompt);
  }
}

class Governor {
  constructor(authority) {
    this.authority = authority;
    this.active = 0;
  }

  delegate({ allowed = [], delegable = [], policy = null } = {}) {
    const depth = (this.authority.depth ?? 0) + 1;
    if (depth > this.authority.maxDepth) {
      throw new DelegationError("delegation depth exceeded");
    }
    if (allowed.length === 0) {
      throw new DelegationError("delegation tool scope is empty");
    }
    const allowedSet = new Set(allowed);
    for (const name of allowedSet) {
      if (
        !this.authority.delegable.has(name) ||
        !this.authority.allowed.has(name)
      ) {
        throw new DelegationError("delegation scope exceeds parent");
      }
    }
    const delegableSet = new Set(delegable);
    for (const name of delegableSet) {
      if (!this.authority.delegable.has(name)) {
        throw new DelegationError("child delegable scope exceeds parent");
      }
    }
    if (!this.authority.budget.available()) {
      throw new BudgetExhausted();
    }
    if (this.active >= this.authority.maxChildren) {
      throw new DelegationError("delegation child limit exceeded");
    }
    this.active += 1;
    const release = () => {
      this.active -= 1;
    };
    return new ChildScope(
      {
        allowed: allowedSet,
        delegable: delegableSet,
        maxDepth: this.authority.maxDepth,
        maxChildren: this.authority.maxChildren,
        depth,
        budget: this.authority.budget,
        policy: new ComposedPolicy([this.authority.policy, policy]),
      },
      release
    );
  }
}

function allowAll() {
  return { allowed: true };
}

function recordPolicy(action) {
  if (action.kind !== "tool.invoke") return { allowed: true };
  if (action.toolName !== "record") {
    return { allowed: false, reason: "child may only record" };
  }
  if (action.arguments && action.arguments.target === "blocked") {
    return { allowed: false, reason: "blocked target" };
  }
  return { allowed: true };
}

module.exports = {
  BudgetExhausted,
  BudgetedTool,
  ChildScope,
  ComposedPolicy,
  DelegationError,
  Governor,
  SharedBudget,
  allowAll,
  recordPolicy,
};
