#import "PraxoAnthropic.h"

#import "PraxoJSON.h"

static NSArray *PXRArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSDictionary *PXRObject(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static NSString *PXRString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *PXRTrimSlashes(NSString *text) {
    NSUInteger length = text.length;
    while (length > 0 && [text characterAtIndex:length - 1] == '/') length--;
    return [text substringToIndex:length];
}

static NSArray *PXRMessageContent(NSDictionary *message) {
    NSMutableArray *content = [NSMutableArray array];
    NSString *text = PXRString(message[@"content"]);
    if (text.length > 0) {
        [content addObject:@{@"type": @"text", @"text": text}];
    }
    for (id call in PXRArray(message[@"toolCalls"])) {
        NSDictionary *callObject = PXRObject(call);
        [content addObject:@{
            @"type": @"tool_use",
            @"id": PXRString(callObject[@"id"]),
            @"name": PXRString(callObject[@"name"]),
            @"input": PXRObject(callObject[@"arguments"]),
        }];
    }
    return content;
}

NSDictionary<NSString *, id> *PXRAnthropicRequestPayload(
    NSString *model,
    NSInteger maxTokens,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString *toolChoice) {
    NSMutableString *system = [NSMutableString string];
    NSMutableArray *encoded = [NSMutableArray array];
    NSMutableArray *pending = [NSMutableArray array];
    for (id item in messages) {
        NSDictionary *message = PXRObject(item);
        NSString *role = PXRString(message[@"role"]);
        if ([role isEqualToString:@"system"]) {
            NSString *text = PXRString(message[@"content"]);
            if (text.length > 0) {
                if (system.length > 0) [system appendString:@"\n\n"];
                [system appendString:text];
            }
        } else if ([role isEqualToString:@"tool"]) {
            [pending addObject:@{
                @"type": @"tool_result",
                @"tool_use_id": PXRString(message[@"toolId"]),
                @"content": PXRString(message[@"content"]),
            }];
        } else {
            if (pending.count > 0) {
                [encoded addObject:@{@"role": @"user", @"content": pending}];
                pending = [NSMutableArray array];
            }
            NSArray *content = PXRMessageContent(message);
            if (content.count > 0) {
                [encoded addObject:@{@"role": role, @"content": content}];
            }
        }
    }
    if (pending.count > 0) {
        [encoded addObject:@{@"role": @"user", @"content": pending}];
    }
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"model"] = model ?: @"";
    payload[@"max_tokens"] = @(maxTokens);
    payload[@"messages"] = encoded;
    if (system.length > 0) payload[@"system"] = system;
    if (tools.count > 0) {
        NSMutableArray *encodedTools = [NSMutableArray array];
        for (id item in tools) {
            NSDictionary *tool = PXRObject(item);
            [encodedTools addObject:@{
                @"name": PXRString(tool[@"name"]),
                @"description": PXRString(tool[@"description"]),
                @"input_schema": PXRObject(tool[@"parameters"]).count > 0
                    ? PXRObject(tool[@"parameters"]) : @{@"type": @"object"},
            }];
        }
        payload[@"tools"] = encodedTools;
        if ([toolChoice isEqualToString:@"auto"]) {
            payload[@"tool_choice"] = @{@"type": @"auto"};
        } else if ([toolChoice isEqualToString:@"required"]) {
            payload[@"tool_choice"] = @{@"type": @"any"};
        } else if ([toolChoice isEqualToString:@"none"]) {
            payload[@"tool_choice"] = @{@"type": @"none"};
        }
    }
    return payload;
}

NSDictionary<NSString *, id> *PXRAnthropicParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error) {
    if (PXRObject(data[@"error"]).count > 0) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP", @"anthropic: provider error");
        return nil;
    }
    NSArray *blocks = PXRArray(data[@"content"]);
    if (blocks.count == 0) {
        if (error) *error = PXRCoreError(@"PROVIDER_JSON", @"invalid content");
        return nil;
    }
    NSMutableString *content = [NSMutableString string];
    NSMutableArray *toolCalls = [NSMutableArray array];
    for (id item in blocks) {
        NSDictionary *block = PXRObject(item);
        NSString *type = PXRString(block[@"type"]);
        if ([type isEqualToString:@"text"]) {
            [content appendString:PXRString(block[@"text"])];
        } else if ([type isEqualToString:@"tool_use"]) {
            [toolCalls addObject:PXRToolCallCreate(PXRString(block[@"id"]),
                                                   PXRString(block[@"name"]),
                                                   PXRObject(block[@"input"]))];
        }
    }
    NSDictionary *usage = PXRObject(data[@"usage"]);
    NSInteger inputTokens = [usage[@"input_tokens"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"input_tokens"] integerValue] : 0;
    NSInteger outputTokens = [usage[@"output_tokens"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"output_tokens"] integerValue] : 0;
    NSMutableDictionary *response = [PXRResponseCreate(
        PXRMessageAssistant(content, toolCalls),
        PXRUsageCreate(inputTokens, outputTokens)) mutableCopy];
    NSString *finishReason = PXRString(data[@"stop_reason"]);
    if (finishReason.length > 0) response[@"finishReason"] = finishReason;
    return response;
}

static BOOL PXRAnthropicDefaultTransport(
    NSString *baseURL,
    NSString *apiKey,
    NSString *version,
    NSString *path,
    NSDictionary<NSString *, id> *payload,
    NSInteger *statusCode,
    NSString **responseBody,
    NSError **error) {
    NSURL *url = [NSURL URLWithString:
        [PXRTrimSlashes(baseURL) stringByAppendingString:path]];
    if (url == nil) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP", @"invalid provider URL");
        return NO;
    }
    NSString *raw = PXRJSONText(payload, nil);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 120;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:apiKey ?: @"" forHTTPHeaderField:@"x-api-key"];
    [request setValue:version ?: @"2023-06-01" forHTTPHeaderField:@"anthropic-version"];
    request.HTTPBody = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSURLResponse *urlResponse = nil;
    NSError *connectionError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&urlResponse
                                                     error:&connectionError];
    if (data == nil) {
        if (error) *error = connectionError ?: PXRCoreError(@"PROVIDER_HTTP", @"request failed");
        return NO;
    }
    *statusCode = [urlResponse isKindOfClass:[NSHTTPURLResponse class]]
        ? [(NSHTTPURLResponse *)urlResponse statusCode] : 0;
    *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    return YES;
}

BOOL PXRAnthropicGenerate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSString *version,
    NSInteger maxTokens,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport transport,
    NSDictionary<NSString *, id> **response,
    NSError **error) {
    if (baseURL.length == 0 || model.length == 0 || apiKey.length == 0) {
        if (error) *error = PXRCoreError(@"MODEL_CONFIG", @"anthropic: missing configuration");
        return NO;
    }
    NSDictionary *payload = PXRAnthropicRequestPayload(
        model, maxTokens, PXRArray(request[@"messages"]),
        PXRArray(request[@"tools"]), PXRString(request[@"toolChoice"]));
    NSInteger statusCode = 0;
    NSString *body = nil;
    BOOL sent = transport != nil
        ? transport(@"/v1/messages", payload, &statusCode, &body, error)
        : PXRAnthropicDefaultTransport(baseURL, apiKey, version, @"/v1/messages",
                                       payload, &statusCode, &body, error);
    if (!sent) return NO;
    if (statusCode < 200 || statusCode >= 300) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP", @"provider returned non-2xx");
        return NO;
    }
    id parsed = nil;
    if (!PXRParseJSONText(body, &parsed, error) ||
        ![parsed isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSDictionary *result = PXRAnthropicParseResponse(parsed, error);
    if (result == nil) return NO;
    if (response) *response = result;
    return YES;
}

PXRModelGenerate PXRAnthropicModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSString *version,
    NSInteger maxTokens,
    PXROpenAITransport transport) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        return PXRAnthropicGenerate(baseURL, model, apiKey, version, maxTokens,
                                    request, transport, response, error);
    };
}
