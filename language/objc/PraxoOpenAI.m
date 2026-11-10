#import "PraxoOpenAI.h"

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

static NSString *PXRBounded(NSString *text, NSUInteger limit) {
    return text.length > limit ? [text substringToIndex:limit] : text;
}

static NSString *PXRTrimSlashes(NSString *text) {
    NSUInteger length = text.length;
    while (length > 0 && [text characterAtIndex:length - 1] == '/') {
        length--;
    }
    return [text substringToIndex:length];
}

static NSDictionary *PXRMessagePayload(NSDictionary *message) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSString *role = PXRString(message[@"role"]);
    NSString *content = PXRString(message[@"content"]);
    NSArray *blocks = PXRArray(message[@"contentBlocks"]);
    if (content.length == 0 && blocks.count > 0) {
        NSMutableString *joined = [NSMutableString string];
        for (id item in blocks) {
            NSDictionary *block = PXRObject(item);
            if ([PXRString(block[@"type"]) isEqualToString:@"text"]) {
                [joined appendString:PXRString(block[@"text"])];
            }
        }
        content = joined;
    }
    out[@"role"] = role;
    out[@"content"] = content;
    NSArray *calls = PXRArray(message[@"toolCalls"]);
    if ([role isEqualToString:@"assistant"] && calls.count > 0) {
        NSMutableArray *encoded = [NSMutableArray array];
        for (id item in calls) {
            NSDictionary *call = PXRObject(item);
            NSError *jsonError = nil;
            NSString *arguments = PXRJSONText(PXRObject(call[@"arguments"]), &jsonError);
            [encoded addObject:@{
                @"id": PXRString(call[@"id"]),
                @"type": @"function",
                @"function": @{
                    @"name": PXRString(call[@"name"]),
                    @"arguments": arguments ?: @"{}",
                },
            }];
        }
        out[@"tool_calls"] = encoded;
    }
    if ([role isEqualToString:@"tool"]) {
        NSString *toolId = PXRString(message[@"toolId"]);
        if (toolId.length > 0) {
            out[@"tool_call_id"] = toolId;
        }
    }
    return out;
}

static NSArray *PXRToolsPayload(NSArray *tools) {
    NSMutableArray *out = [NSMutableArray array];
    for (id item in tools) {
        NSDictionary *tool = PXRObject(item);
        NSDictionary *parameters = PXRObject(tool[@"parameters"]);
        if (parameters.count == 0) {
            parameters = @{ @"type": @"object" };
        }
        [out addObject:@{
            @"type": @"function",
            @"function": @{
                @"name": PXRString(tool[@"name"]),
                @"description": PXRString(tool[@"description"]),
                @"parameters": parameters,
            },
        }];
    }
    return out;
}

NSDictionary<NSString *, id> *PXROpenAIRequestPayload(
    NSString *model,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString *toolChoice) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"model"] = model ?: @"";
    NSMutableArray *encodedMessages = [NSMutableArray array];
    for (id item in messages) {
        [encodedMessages addObject:PXRMessagePayload(PXRObject(item))];
    }
    payload[@"messages"] = encodedMessages;
    NSArray *encodedTools = PXRToolsPayload(tools);
    if (encodedTools.count > 0) {
        payload[@"tools"] = encodedTools;
    }
    if (toolChoice.length > 0) {
        payload[@"tool_choice"] = toolChoice;
    }
    return payload;
}

NSDictionary<NSString *, id> *PXROpenAIParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error) {
    NSDictionary *providerError = PXRObject(data[@"error"]);
    if (providerError.count > 0) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_HTTP",
                                  PXRString(providerError[@"message"]));
        }
        return nil;
    }
    NSArray *choices = PXRArray(data[@"choices"]);
    if (choices.count == 0) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_JSON", @"provider returned no choices");
        }
        return nil;
    }
    NSDictionary *choice = PXRObject(choices[0]);
    NSDictionary *message = PXRObject(choice[@"message"]);
    NSMutableArray *toolCalls = [NSMutableArray array];
    for (id item in PXRArray(message[@"tool_calls"])) {
        NSDictionary *call = PXRObject(item);
        NSDictionary *function = PXRObject(call[@"function"]);
        id rawArguments = function[@"arguments"];
        NSDictionary *arguments = @{};
        if ([rawArguments isKindOfClass:[NSString class]] &&
            [(NSString *)rawArguments length] > 0) {
            id parsed = nil;
            NSError *parseError = nil;
            if (!PXRParseJSONText(rawArguments, &parsed, &parseError) ||
                ![parsed isKindOfClass:[NSDictionary class]]) {
                if (error) {
                    *error = PXRCoreError(@"PROVIDER_JSON",
                                          @"invalid tool call arguments");
                }
                return nil;
            }
            arguments = parsed;
        } else if ([rawArguments isKindOfClass:[NSDictionary class]]) {
            arguments = rawArguments;
        }
        [toolCalls addObject:PXRToolCallCreate(PXRString(call[@"id"]),
                                               PXRString(function[@"name"]),
                                               arguments)];
    }
    NSDictionary *usage = PXRObject(data[@"usage"]);
    NSInteger inputTokens = [usage[@"prompt_tokens"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"prompt_tokens"] integerValue] : 0;
    NSInteger outputTokens = [usage[@"completion_tokens"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"completion_tokens"] integerValue] : 0;
    NSMutableDictionary *response = [PXRResponseCreate(
        PXRMessageAssistant(PXRString(message[@"content"]), toolCalls),
        PXRUsageCreate(inputTokens, outputTokens)) mutableCopy];
    NSString *finishReason = PXRString(choice[@"finish_reason"]);
    if (finishReason.length > 0) {
        response[@"finishReason"] = finishReason;
    }
    return response;
}

static BOOL PXROpenAIDefaultTransport(
    NSString *baseURL,
    NSString *apiKey,
    NSString *path,
    NSDictionary<NSString *, id> *payload,
    NSInteger *statusCode,
    NSString **responseBody,
    NSError **error) {
    NSURL *url = [NSURL URLWithString:
        [PXRTrimSlashes(baseURL) stringByAppendingString:path]];
    if (url == nil) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_HTTP", @"invalid provider URL");
        }
        return NO;
    }
    NSError *jsonError = nil;
    NSString *raw = PXRJSONText(payload, &jsonError);
    if (raw == nil) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_JSON", @"cannot encode request payload");
        }
        return NO;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 120;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (apiKey.length > 0) {
        [request setValue:[@"Bearer " stringByAppendingString:apiKey]
       forHTTPHeaderField:@"Authorization"];
    }
    request.HTTPBody = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSURLResponse *urlResponse = nil;
    NSError *connectionError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&urlResponse
                                                     error:&connectionError];
    if (data == nil) {
        if (error) {
            *error = connectionError ?: PXRCoreError(@"PROVIDER_HTTP",
                                                     @"provider request failed");
        }
        return NO;
    }
    *statusCode = [urlResponse isKindOfClass:[NSHTTPURLResponse class]]
        ? [(NSHTTPURLResponse *)urlResponse statusCode] : 200;
    *responseBody = [[NSString alloc] initWithData:data
                                          encoding:NSUTF8StringEncoding] ?: @"";
    return YES;
}

BOOL PXROpenAIGenerate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport transport,
    NSDictionary<NSString *, id> **response,
    NSError **error) {
    if (baseURL.length == 0) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_HTTP",
                                  @"provider base URL is required");
        }
        return NO;
    }
    NSDictionary *payload = PXROpenAIRequestPayload(
        model,
        PXRArray(request[@"messages"]),
        PXRArray(request[@"tools"]),
        PXRString(request[@"toolChoice"]));
    NSInteger statusCode = 200;
    NSString *body = nil;
    if (transport != nil) {
        if (!transport(@"/chat/completions", payload, &statusCode, &body, error)) {
            return NO;
        }
    } else if (!PXROpenAIDefaultTransport(baseURL, apiKey, @"/chat/completions",
                                         payload, &statusCode, &body, error)) {
        return NO;
    }
    if (statusCode < 200 || statusCode >= 300) {
        if (error) {
            *error = PXRCoreError(
                @"PROVIDER_HTTP",
                [NSString stringWithFormat:@"provider returned HTTP %ld: %@",
                                           (long)statusCode,
                                           PXRBounded(body ?: @"", 4096)]);
        }
        return NO;
    }
    id decoded = nil;
    NSError *parseError = nil;
    if (!PXRParseJSONText(body ?: @"", &decoded, &parseError) ||
        ![decoded isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = PXRCoreError(@"PROVIDER_JSON",
                                  @"provider returned invalid JSON");
        }
        return NO;
    }
    NSDictionary *parsed = PXROpenAIParseResponse(decoded, error);
    if (parsed == nil) {
        return NO;
    }
    if (response != NULL) {
        *response = parsed;
    }
    return YES;
}

PXRModelGenerate PXROpenAIModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    PXROpenAITransport transport) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        return PXROpenAIGenerate(baseURL, model, apiKey, request, transport,
                                 response, error);
    };
}
