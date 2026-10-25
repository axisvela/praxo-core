package io.axisvela.praxo.agent;

import io.axisvela.praxo.context.ContextBudget;
import io.axisvela.praxo.context.ContextCompactor;
import io.axisvela.praxo.context.Offloader;
import io.axisvela.praxo.event.Sink;
import io.axisvela.praxo.middleware.Middleware;
import io.axisvela.praxo.middleware.PiiRedactor;
import io.axisvela.praxo.middleware.StructuredOutput;
import io.axisvela.praxo.middleware.ToolSelector;
import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.ResponseFormat;
import io.axisvela.praxo.policy.Hook;
import io.axisvela.praxo.tool.Registry;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public final class AgentOptions {
    public Model model;
    public Registry tools;
    public Sink events;
    public Hook policy;
    public String systemPrompt = "";
    public List<String> memoryFiles = new ArrayList<>();
    public ContextBudget context;
    public ContextCompactor compactor;
    public Offloader offloader;
    public int offloadThresholdBytes;
    public List<Middleware> middleware = new ArrayList<>();
    public List<Middleware.ModelMiddleware> modelMiddleware = new ArrayList<>();
    public StructuredOutput structuredOutput;
    public List<String> allowedTools = new ArrayList<>();
    public ToolSelector toolSelector;
    public PiiRedactor piiRedactor;
    public int modelCallLimit;
    public int toolCallLimit;
    public Model fallbackModel;
    public String toolChoice;
    public ResponseFormat responseFormat;
    public int maxSteps = 8;
    public long maxTokens;
    public int maxParallelTools = 1;
    public Consumer<String> onDelta;

    public AgentOptions(Model model) {
        this.model = model;
    }
}
