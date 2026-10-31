package com.axisvela.praxo.agent;

import com.axisvela.praxo.context.ContextBudget;
import com.axisvela.praxo.context.ContextCompactor;
import com.axisvela.praxo.context.Offloader;
import com.axisvela.praxo.event.Sink;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.middleware.PiiRedactor;
import com.axisvela.praxo.middleware.StructuredOutput;
import com.axisvela.praxo.middleware.ToolSelector;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.ResponseFormat;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;

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
    public CancellationToken cancellation;

    public AgentOptions(Model model) {
        this.model = model;
    }
}
