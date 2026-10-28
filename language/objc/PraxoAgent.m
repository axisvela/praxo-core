#import "PraxoCore.h"

static NSArray *PXRArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSString *PXRString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSInteger PXRInteger(id value) {
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

static NSString *PXRReplaceRegex(NSString *pattern, NSString *text, NSString *replacement) {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:0
                               error:&error];
    if (regex == nil) {
        return text;
    }
    return [regex stringByReplacingMatchesInString:text
                                           options:0
                                             range:NSMakeRange(0, text.length)
                                      withTemplate:replacement];
}

NSString *PXRPIIRedact(NSString *text) {
    NSString *output = PXRReplaceRegex(@"[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
                                       text ?: @"", @"[REDACTED:email]");
    output = PXRReplaceRegex(@"\\b\\d{3}-\\d{2}-\\d{4}\\b", output, @"[REDACTED:ssn]");
    output = PXRReplaceRegex(@"\\b(?:\\d{4}[ -]?){3}\\d{4}\\b", output,
                              @"[REDACTED:credit_card]");
    output = PXRReplaceRegex(@"\\b(?:\\+?1[-. ]?)?\\(?\\d{3}\\)?[-. ]?\\d{3}[-. ]?\\d{4}\\b",
                              output, @"[REDACTED:phone]");
    return output;
}

id PXRRedactValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return PXRPIIRedact(value);
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *output = [NSMutableArray array];
        for (id item in value) {
            [output addObject:PXRRedactValue(item)];
        }
        return output;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *output = [NSMutableDictionary dictionary];
        for (NSString *key in value) {
            output[key] = PXRRedactValue(value[key]);
        }
        return output;
    }
    return value;
}

static id PXRExtractJSON(NSString *text) {
    NSString *value = [text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (value.length == 0) {
        return nil;
    }
    if (PXRStringHasPrefix(value, @"```")) {
        NSRange newline = [value rangeOfString:@"\n"];
        if (newline.location != NSNotFound) {
            value = [value substringFromIndex:NSMaxRange(newline)];
        }
        NSRange close = [value rangeOfString:@"```" options:NSBackwardsSearch];
        if (close.location != NSNotFound) {
            value = [value substringToIndex:close.location];
        }
        value = [value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    NSRange object = [value rangeOfString:@"{"];
    NSRange array = [value rangeOfString:@"["];
    NSUInteger start = NSUIntegerMax;
    if (object.location != NSNotFound) {
        start = object.location;
    }
    if (array.location != NSNotFound && array.location < start) {
        start = array.location;
    }
    if (start == NSUIntegerMax) {
        return nil;
    }
    id parsed = nil;
    if (!PXRParseJSONText([value substringFromIndex:start], &parsed, nil)) {
        return nil;
    }
    return parsed;
}

NSDictionary<NSString *, id> *PXRStructuredOutputCreate(NSDictionary<NSString *, id> *schema,
                                                        NSInteger maxRepairs,
                                                        PXRRepairer repairer) {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    config[@"schema"] = schema ?: @{};
    config[@"maxRepairs"] = @(maxRepairs);
    if (repairer != nil) {
        config[@"repairer"] = [repairer copy];
    }
    return config;
}

NSString *PXRStructuredApply(NSDictionary<NSString *, id> *config,
                             NSString *text,
                             NSError **error) {
    NSString *output = text ?: @"";
    NSInteger maxRepairs = PXRInteger(config[@"maxRepairs"]);
    for (NSInteger attempt = 0; attempt <= maxRepairs; attempt++) {
        id value = PXRExtractJSON(output);
        if (value != nil && PXRValidateSchema(config[@"schema"] ?: @{}, value).count == 0) {
            return output;
        }
        if (attempt == maxRepairs) {
            break;
        }
        PXRRepairer repairer = config[@"repairer"];
        if (repairer == nil) {
            break;
        }
        NSString *repaired = repairer(output);
        if (repaired == nil ||
            [repaired stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
            break;
        }
        output = repaired;
    }
    if (error != NULL) {
        *error = PXRCoreError(@"AGENT_STRUCTURED_OUTPUT", @"structured output failed");
    }
    return nil;
}

NSMutableDictionary<NSString *, id> *PXRCallLimitCreate(NSInteger modelLimit, NSInteger toolLimit) {
    return [@{@"modelLimit": @(modelLimit),
              @"toolLimit": @(toolLimit),
              @"models": @0,
              @"tools": @0} mutableCopy];
}

BOOL PXRCallLimitModel(NSMutableDictionary<NSString *, id> *limit, NSError **error) {
    NSInteger count = PXRInteger(limit[@"models"]) + 1;
    limit[@"models"] = @(count);
    NSInteger maximum = PXRInteger(limit[@"modelLimit"]);
    if (maximum > 0 && count > maximum) {
        if (error != NULL) {
            *error = PXRCoreError(@"AGENT_MODEL_CALL_LIMIT", @"model call limit");
        }
        return NO;
    }
    return YES;
}

BOOL PXRCallLimitTool(NSMutableDictionary<NSString *, id> *limit, NSError **error) {
    NSInteger count = PXRInteger(limit[@"tools"]) + 1;
    limit[@"tools"] = @(count);
    NSInteger maximum = PXRInteger(limit[@"toolLimit"]);
    if (maximum > 0 && count > maximum) {
        if (error != NULL) {
            *error = PXRCoreError(@"AGENT_TOOL_CALL_LIMIT", @"tool call limit");
        }
        return NO;
    }
    return YES;
}

NSMutableSet<NSString *> *PXRToolSelectionCreate(NSArray<NSString *> *selected) {
    return [NSMutableSet setWithArray:selected ?: @[]];
}

NSArray<NSDictionary<NSString *, id> *> *PXRSelectTools(
    NSMutableSet<NSString *> *selection,
    NSArray<NSDictionary<NSString *, id> *> *tools) {
    NSMutableArray *output = [NSMutableArray array];
    for (NSDictionary *tool in tools) {
        if ([selection member:PXRString(tool[@"name"])] != nil) {
            [output addObject:tool];
        }
    }
    return output;
}

BOOL PXRCheckToolSelected(NSMutableSet<NSString *> *selection,
                          NSString *name,
                          NSError **error) {
    if ([selection member:(name ?: @"")] == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"AGENT_TOOL_NOT_SELECTED", @"tool not selected");
        }
        return NO;
    }
    return YES;
}

NSDictionary<NSString *, id> *PXRToolCreate(NSString *name,
                                            NSString *description,
                                            PXRToolInvoke invoke) {
    NSMutableDictionary *tool = [NSMutableDictionary dictionary];
    tool[@"name"] = name ?: @"";
    tool[@"description"] = description ?: @"";
    if (invoke != nil) {
        tool[@"invoke"] = [invoke copy];
    }
    return tool;
}

PXRModelGenerate PXRModelCreateScripted(NSArray<NSDictionary<NSString *, id> *> *steps) {
    NSArray *copy = [steps copy];
    __block NSUInteger index = 0;
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        if (index >= copy.count) {
            if (error != NULL) {
                *error = PXRCoreError(@"MODEL_ERROR", @"script exhausted");
            }
            return NO;
        }
        if (response != NULL) {
            *response = copy[index];
        }
        index++;
        return YES;
    };
}

PXRModelGenerate PXRModelCreateStatic(NSString *content) {
    NSString *value = [content copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        if (response != NULL) {
            *response = PXRResponseCreate(PXRMessageAssistant(value, @[]),
                                          PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

PXRModelGenerate PXRModelCreateFailing(void) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        if (error != NULL) {
            *error = PXRCoreError(@"MODEL_ERROR", @"primary model failed");
        }
        return NO;
    };
}

PXRModelGenerate PXRModelCreateFallback(PXRModelGenerate primary, PXRModelGenerate fallback) {
    PXRModelGenerate first = [primary copy];
    PXRModelGenerate second = [fallback copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        NSError *primaryError = nil;
        if (first != nil && first(request, response, &primaryError)) {
            return YES;
        }
        if (second != nil) {
            return second(request, response, error);
        }
        if (error != NULL) {
            *error = primaryError ?: PXRCoreError(@"MODEL_ERROR", @"model failed");
        }
        return NO;
    };
}

NSMutableDictionary<NSString *, id> *PXRAgentOptionsCreate(PXRModelGenerate model) {
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    if (model != nil) {
        options[@"model"] = [model copy];
    }
    options[@"tools"] = @[];
    options[@"systemPrompt"] = @"";
    options[@"maxSteps"] = @8;
    options[@"maxTokens"] = @0;
    options[@"sessionId"] = @"s1";
    return options;
}

static NSArray *PXRToolSpecs(NSArray<NSDictionary<NSString *, id> *> *tools) {
    NSMutableArray *specs = [NSMutableArray array];
    for (NSDictionary *tool in tools) {
        [specs addObject:PXRToolSpecCreate(PXRString(tool[@"name"]),
                                           PXRString(tool[@"description"]))];
    }
    return specs;
}

static NSDictionary *PXRFindTool(NSArray<NSDictionary<NSString *, id> *> *tools, NSString *name) {
    for (NSDictionary *tool in tools) {
        if ([PXRString(tool[@"name"]) isEqualToString:name]) {
            return tool;
        }
    }
    return nil;
}

static NSDictionary *PXRAgentFail(NSMutableDictionary<NSString *, id> *options,
                                  NSString *sessionId,
                                  NSString *runId,
                                  NSString *code,
                                  NSString *message,
                                  NSError **error) {
    PXREventSink sink = options[@"events"];
    PXREmit(sink, PXREventCreate(@"run.failed", sessionId, runId,
                                 @{@"error": message ?: @""}));
    if (error != NULL) {
        *error = PXRCoreError(code, message ?: code);
    }
    return nil;
}

NSDictionary<NSString *, id> *PXRAgentRun(NSMutableDictionary<NSString *, id> *options,
                                          NSDictionary<NSString *, id> *session,
                                          NSString *prompt,
                                          NSError **error) {
    NSString *sessionId = [PXRString(session[@"id"]) copy];
    PXRModelGenerate model = options[@"model"];
    if (model == nil) {
        return PXRAgentFail(options, sessionId, @"", @"MODEL_ERROR", @"model is not configured", error);
    }
    NSString *runId = [@"run-" stringByAppendingString:[[NSUUID UUID] UUIDString]];
    PXREventSink sink = options[@"events"];
    NSMutableArray *messages = [NSMutableArray arrayWithArray:PXRArray(session[@"messages"])];
    NSString *systemPrompt = PXRString(options[@"systemPrompt"]);
    if (systemPrompt.length > 0) {
        [messages insertObject:PXRMessageCreate(@"system", systemPrompt) atIndex:0];
    }
    [messages addObject:PXRMessageCreate(@"user", prompt ?: @"")];
    NSInteger maxSteps = PXRInteger(options[@"maxSteps"]);
    if (maxSteps <= 0) {
        maxSteps = 8;
    }
    NSInteger maxTokens = PXRInteger(options[@"maxTokens"]);
    NSArray *tools = PXRArray(options[@"tools"]);
    NSMutableSet *selection = options[@"toolSelection"];
    BOOL pii = [options[@"pii"] boolValue];
    NSDictionary *structured = options[@"structuredOutput"];
    NSMutableDictionary *limit = PXRCallLimitCreate(PXRInteger(options[@"modelCallLimit"]),
                                                     PXRInteger(options[@"toolCallLimit"]));
    NSDictionary *total = PXRUsageCreate(0, 0);
    PXREmit(sink, PXREventCreate(@"run.started", sessionId, runId, nil));
    for (NSInteger step = 1; step <= maxSteps; step++) {
        NSDictionary *response = nil;
        NSError *modelError = nil;
        if (!PXRCallLimitModel(limit, &modelError)) {
            return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(modelError),
                                modelError.localizedDescription, error);
        }
        NSMutableArray *modelMessages = [NSMutableArray array];
        for (NSDictionary *item in messages) {
            NSMutableDictionary *copy = [item mutableCopy];
            if (pii && [copy[@"content"] isKindOfClass:[NSString class]]) {
                copy[@"content"] = PXRPIIRedact(copy[@"content"]);
            }
            if (pii && [copy[@"contentBlocks"] isKindOfClass:[NSArray class]]) {
                NSMutableArray *blocks = [NSMutableArray array];
                for (id block in copy[@"contentBlocks"]) {
                    if ([block isKindOfClass:[NSDictionary class]]) {
                        NSMutableDictionary *safeBlock = [block mutableCopy];
                        if ([safeBlock[@"text"] isKindOfClass:[NSString class]]) {
                            safeBlock[@"text"] = PXRPIIRedact(safeBlock[@"text"]);
                        }
                        [blocks addObject:safeBlock];
                    } else {
                        [blocks addObject:block];
                    }
                }
                copy[@"contentBlocks"] = blocks;
            }
            if (pii && [copy[@"toolCalls"] isKindOfClass:[NSArray class]]) {
                NSMutableArray *toolCalls = [NSMutableArray array];
                for (id call in copy[@"toolCalls"]) {
                    if ([call isKindOfClass:[NSDictionary class]]) {
                        NSMutableDictionary *safeCall = [call mutableCopy];
                        safeCall[@"arguments"] = PXRRedactValue(safeCall[@"arguments"]);
                        [toolCalls addObject:safeCall];
                    } else {
                        [toolCalls addObject:call];
                    }
                }
                copy[@"toolCalls"] = toolCalls;
            }
            [modelMessages addObject:copy];
        }
        NSDictionary *request = PXRRequestCreate(modelMessages, PXRToolSpecs(
            selection != nil ? PXRSelectTools(selection, tools) : tools));
        if (!model(request, &response, &modelError)) {
            return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(modelError),
                                modelError.localizedDescription ?: @"model failed", error);
        }
        total = PXRUsageAdd(total, response[@"usage"] ?: PXRUsageCreate(0, 0));
        if (maxTokens > 0 &&
            PXRInteger(total[@"inputTokens"]) + PXRInteger(total[@"outputTokens"]) > maxTokens) {
            return PXRAgentFail(options, sessionId, runId, @"AGENT_MAX_TOKENS", @"token budget exceeded", error);
        }
        NSDictionary *message = response[@"message"] ?: @{};
        [messages addObject:message];
        NSArray *calls = PXRArray(message[@"toolCalls"]);
        if (calls.count == 0) {
            NSString *output = PXRString(message[@"content"]);
            if (structured != nil) {
                NSError *structuredError = nil;
                output = PXRStructuredApply(structured, output, &structuredError);
                if (output == nil) {
                    return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(structuredError),
                                        structuredError.localizedDescription, error);
                }
            }
            PXREmit(sink, PXREventCreate(@"run.completed", sessionId, runId, nil));
            return PXRRunResultCreate(runId, output, step, total);
        }
        for (NSDictionary *call in calls) {
            NSError *selectionError = nil;
            if (selection != nil && !PXRCheckToolSelected(selection, PXRString(call[@"name"]), &selectionError)) {
                return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(selectionError),
                                    selectionError.localizedDescription, error);
            }
            NSDictionary *tool = PXRFindTool(tools, PXRString(call[@"name"]));
            if (tool == nil) {
                return PXRAgentFail(options, sessionId, runId, @"TOOL_NOT_FOUND",
                                    @"tool not found", error);
            }
            NSError *limitError = nil;
            if (!PXRCallLimitTool(limit, &limitError)) {
                return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(limitError),
                                    limitError.localizedDescription, error);
            }
            PXREmit(sink, PXREventCreate(@"tool.call", sessionId, runId,
                                        @{@"name": PXRString(call[@"name"]),
                                          @"arguments": call[@"arguments"] ?: @{}}));
            PXRToolInvoke invoke = tool[@"invoke"];
            NSError *toolError = nil;
            id value = invoke != nil ? invoke(call[@"arguments"] ?: @{}, &toolError) : call[@"arguments"];
            if (toolError != nil) {
                return PXRAgentFail(options, sessionId, runId, PXRCodeFromError(toolError),
                                    toolError.localizedDescription ?: @"tool failed", error);
            }
            id resultValue = value ?: [NSNull null];
            NSString *content = PXRJSONText(pii ? PXRRedactValue(resultValue) : resultValue, NULL) ?: @"null";
            [messages addObject:PXRMessageTool(content, PXRString(call[@"id"]))];
        }
    }
    return PXRAgentFail(options, sessionId, runId, @"AGENT_MAX_STEPS", @"maximum steps exceeded", error);
}
