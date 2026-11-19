#import "PraxoGemini.h"

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

static NSArray *PXRMessageParts(NSDictionary *message) {
    NSMutableArray *parts = [NSMutableArray array];
    NSString *text = PXRString(message[@"content"]);
    if (text.length > 0) [parts addObject:@{@"text": text}];
    for (id call in PXRArray(message[@"toolCalls"])) {
        NSDictionary *callObject = PXRObject(call);
        [parts addObject:@{@"functionCall": @{
            @"name": PXRString(callObject[@"name"]),
            @"args": PXRObject(callObject[@"arguments"]),
        }}];
    }
    return parts;
}

NSDictionary<NSString *, id> *PXRGeminiRequestPayload(
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString *toolChoice,
    NSInteger maxOutputTokens) {
    NSMutableArray *system = [NSMutableArray array];
    NSMutableArray *contents = [NSMutableArray array];
    NSMutableArray *pending = [NSMutableArray array];
    for (id item in messages) {
        NSDictionary *message = PXRObject(item);
        NSString *role = PXRString(message[@"role"]);
        if ([role isEqualToString:@"system"]) {
            NSString *text = PXRString(message[@"content"]);
            if (text.length > 0) [system addObject:@{@"text": text}];
        } else if ([role isEqualToString:@"tool"]) {
            [pending addObject:@{@"functionResponse": @{
                @"name": PXRString(message[@"toolId"]).length > 0
                    ? PXRString(message[@"toolId"]) : @"tool",
                @"response": @{@"result": PXRString(message[@"content"])},
            }}];
        } else {
            if (pending.count > 0) {
                [contents addObject:@{@"role": @"user", @"parts": pending}];
                pending = [NSMutableArray array];
            }
            NSArray *parts = PXRMessageParts(message);
            if (parts.count > 0) {
                [contents addObject:@{
                    @"role": [role isEqualToString:@"assistant"] ? @"model" : @"user",
                    @"parts": parts,
                }];
            }
        }
    }
    if (pending.count > 0) [contents addObject:@{@"role": @"user", @"parts": pending}];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"contents"] = contents;
    if (system.count > 0) payload[@"system_instruction"] = @{@"parts": system};
    if (tools.count > 0) {
        NSMutableArray *declarations = [NSMutableArray array];
        for (id item in tools) {
            NSDictionary *tool = PXRObject(item);
            [declarations addObject:@{
                @"name": PXRString(tool[@"name"]),
                @"description": PXRString(tool[@"description"]),
                @"parameters": PXRObject(tool[@"parameters"]).count > 0
                    ? PXRObject(tool[@"parameters"]) : @{@"type": @"object"},
            }];
        }
        payload[@"tools"] = @[@{@"functionDeclarations": declarations}];
        NSString *mode = [toolChoice isEqualToString:@"required"] ? @"ANY"
            : [toolChoice isEqualToString:@"none"] ? @"NONE" : @"AUTO";
        payload[@"toolConfig"] = @{@"functionCallingConfig": @{@"mode": mode}};
    }
    if (maxOutputTokens > 0) {
        payload[@"generationConfig"] = @{@"maxOutputTokens": @(maxOutputTokens)};
    }
    return payload;
}

NSDictionary<NSString *, id> *PXRGeminiParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error) {
    if (PXRObject(data[@"error"]).count > 0) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP", @"gemini: provider error");
        return nil;
    }
    NSArray *candidates = PXRArray(data[@"candidates"]);
    if (candidates.count == 0) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP", @"gemini: empty response");
        return nil;
    }
    NSDictionary *candidate = PXRObject(candidates[0]);
    NSDictionary *content = PXRObject(candidate[@"content"]);
    NSMutableString *text = [NSMutableString string];
    NSMutableArray *toolCalls = [NSMutableArray array];
    for (id item in PXRArray(content[@"parts"])) {
        NSDictionary *part = PXRObject(item);
        [text appendString:PXRString(part[@"text"])];
        NSDictionary *call = PXRObject(part[@"functionCall"]);
        if (call.count > 0) {
            [toolCalls addObject:PXRToolCallCreate(
                [NSString stringWithFormat:@"call-%lu", (unsigned long)toolCalls.count + 1],
                PXRString(call[@"name"]), PXRObject(call[@"args"]))];
        }
    }
    NSDictionary *usage = PXRObject(data[@"usageMetadata"]);
    NSInteger inputTokens = [usage[@"promptTokenCount"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"promptTokenCount"] integerValue] : 0;
    NSInteger outputTokens = [usage[@"candidatesTokenCount"] respondsToSelector:@selector(integerValue)]
        ? [usage[@"candidatesTokenCount"] integerValue] : 0;
    NSMutableDictionary *response = [PXRResponseCreate(
        PXRMessageAssistant(text, toolCalls),
        PXRUsageCreate(inputTokens, outputTokens)) mutableCopy];
    NSString *finishReason = PXRString(candidate[@"finishReason"]);
    if (finishReason.length > 0) response[@"finishReason"] = finishReason;
    return response;
}

static BOOL PXRGeminiDefaultTransport(
    NSString *baseURL,
    NSString *apiKey,
    NSString *path,
    NSDictionary<NSString *, id> *payload,
    NSInteger *statusCode,
    NSString **responseBody,
    NSError **error) {
    NSURL *url = [NSURL URLWithString:
        [PXRTrimSlashes(baseURL) stringByAppendingString:path]];
    NSString *raw = PXRJSONText(payload, nil);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 120;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:apiKey ?: @"" forHTTPHeaderField:@"x-goog-api-key"];
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

NSDictionary<NSString *, id> *PXRGeminiParseStream(
    NSString *text,
    PXROpenAIDelta onDelta,
    NSError **error) {
    NSMutableString *content = [NSMutableString string];
    NSMutableArray *calls = [NSMutableArray array];
    NSInteger inputTokens = 0;
    NSInteger outputTokens = 0;
    NSInteger cachedTokens = 0;
    NSString *finishReason = nil;
    NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *raw in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:spaces];
        if (line.length < 5 || ![line hasPrefix:@"data:"]) continue;
        NSString *chunk = [[line substringFromIndex:5]
            stringByTrimmingCharactersInSet:spaces];
        if (chunk.length == 0 || [chunk isEqualToString:@"[DONE]"]) continue;
        id decoded = nil;
        NSError *parseError = nil;
        if (!PXRParseJSONText(chunk, &decoded, &parseError) ||
            ![decoded isKindOfClass:[NSDictionary class]]) {
            if (error) *error = PXRCoreError(@"MODEL_STREAM",
                                             @"gemini: invalid stream chunk");
            return nil;
        }
        NSDictionary *event = decoded;
        if (PXRObject(event[@"error"]).count > 0) {
            if (error) *error = PXRCoreError(@"MODEL_STREAM",
                                             @"gemini: provider stream error");
            return nil;
        }
        NSDictionary *usage = PXRObject(event[@"usageMetadata"]);
        if (usage.count > 0) {
            inputTokens = [usage[@"promptTokenCount"] respondsToSelector:@selector(integerValue)]
                ? [usage[@"promptTokenCount"] integerValue] : inputTokens;
            outputTokens = [usage[@"candidatesTokenCount"] respondsToSelector:@selector(integerValue)]
                ? [usage[@"candidatesTokenCount"] integerValue] : outputTokens;
            cachedTokens = [usage[@"cachedContentTokenCount"] respondsToSelector:@selector(integerValue)]
                ? [usage[@"cachedContentTokenCount"] integerValue] : cachedTokens;
        }
        NSArray *candidates = PXRArray(event[@"candidates"]);
        if (candidates.count == 0) continue;
        NSDictionary *candidate = PXRObject(candidates[0]);
        NSString *reason = PXRString(candidate[@"finishReason"]);
        if (reason.length > 0) finishReason = reason;
        NSDictionary *candidateContent = PXRObject(candidate[@"content"]);
        for (id item in PXRArray(candidateContent[@"parts"])) {
            NSDictionary *part = PXRObject(item);
            NSString *piece = PXRString(part[@"text"]);
            if (piece.length > 0) {
                [content appendString:piece];
                if (onDelta) onDelta(piece);
            }
            NSDictionary *call = PXRObject(part[@"functionCall"]);
            if (call.count > 0) {
                [calls addObject:PXRToolCallCreate(
                    [NSString stringWithFormat:@"call-%lu", (unsigned long)calls.count + 1],
                    PXRString(call[@"name"]),
                    PXRObject(call[@"args"]))];
            }
        }
    }
    NSMutableDictionary *response = [PXRResponseCreate(
        PXRMessageAssistant(content, calls),
        PXRUsageCreate(inputTokens, outputTokens)) mutableCopy];
    if (finishReason.length > 0) response[@"finishReason"] = finishReason;
    return response;
}

BOOL PXRGeminiGenerateStream(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSInteger maxOutputTokens,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport transport,
    PXROpenAIDelta onDelta,
    NSDictionary<NSString *, id> **response,
    NSError **error) {
    if (baseURL.length == 0) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP",
                                         @"provider base URL is required");
        return NO;
    }
    if (apiKey.length == 0 || model.length == 0) {
        if (error) *error = PXRCoreError(@"MODEL_CONFIG",
                                         @"gemini: missing configuration");
        return NO;
    }
    NSDictionary *payload = PXRGeminiRequestPayload(
        PXRArray(request[@"messages"]), PXRArray(request[@"tools"]),
        PXRString(request[@"toolChoice"]), maxOutputTokens);
    NSString *path = [NSString stringWithFormat:
        @"/v1beta/models/%@:streamGenerateContent?alt=sse", model];
    NSInteger statusCode = 0;
    NSString *body = nil;
    BOOL sent = transport != nil
        ? transport(path, payload, &statusCode, &body, error)
        : PXRGeminiDefaultTransport(baseURL, apiKey, path, payload,
                                    &statusCode, &body, error);
    if (!sent) return NO;
    if (statusCode < 200 || statusCode >= 300) {
        if (error) *error = PXRCoreError(@"PROVIDER_HTTP",
                                         @"provider returned non-2xx");
        return NO;
    }
    NSDictionary *parsed = PXRGeminiParseStream(body ?: @"", onDelta, error);
    if (parsed == nil) return NO;
    if (response) *response = parsed;
    return YES;
}

BOOL PXRGeminiGenerate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSInteger maxOutputTokens,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport transport,
    NSDictionary<NSString *, id> **response,
    NSError **error) {
    if (baseURL.length == 0 || model.length == 0 || apiKey.length == 0) {
        if (error) *error = PXRCoreError(@"MODEL_CONFIG", @"gemini: missing configuration");
        return NO;
    }
    NSDictionary *payload = PXRGeminiRequestPayload(
        PXRArray(request[@"messages"]), PXRArray(request[@"tools"]),
        PXRString(request[@"toolChoice"]), maxOutputTokens);
    NSString *path = [NSString stringWithFormat:@"/v1beta/models/%@:generateContent", model];
    NSInteger statusCode = 0;
    NSString *body = nil;
    BOOL sent = transport != nil
        ? transport(path, payload, &statusCode, &body, error)
        : PXRGeminiDefaultTransport(baseURL, apiKey, path, payload,
                                    &statusCode, &body, error);
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
    NSDictionary *result = PXRGeminiParseResponse(parsed, error);
    if (result == nil) return NO;
    if (response) *response = result;
    return YES;
}

PXRModelGenerate PXRGeminiModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString *apiKey,
    NSInteger maxOutputTokens,
    PXROpenAITransport transport) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> **response,
                 NSError **error) {
        PXROpenAIDelta onDelta = request[@"onDelta"];
        if (onDelta != nil) {
            return PXRGeminiGenerateStream(baseURL, model, apiKey,
                                           maxOutputTokens, request, transport,
                                           onDelta, response, error);
        }
        return PXRGeminiGenerate(baseURL, model, apiKey, maxOutputTokens,
                                 request, transport, response, error);
    };
}
