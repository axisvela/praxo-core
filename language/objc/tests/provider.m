#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoAnthropic.h"
#import "PraxoGemini.h"

void runProviderAdapterTests(void (*check)(BOOL, NSString *)) {
    __block NSString *capturedPath = nil;
    PXROpenAITransport anthropicTransport = ^BOOL(NSString *path,
                                                  NSDictionary<NSString *, id> *payload,
                                                  NSInteger *statusCode,
                                                  NSString **responseBody,
                                                  NSError **error) {
        capturedPath = path;
        *statusCode = 200;
        *responseBody = @"{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},"
            "{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\","
            "\"input\":{\"text\":\"hi\"}}],\"stop_reason\":\"end_turn\","
            "\"usage\":{\"input_tokens\":3,\"output_tokens\":4}}";
        return YES;
    };
    NSMutableDictionary *request = [PXRRequestCreate(
        @[PXRMessageCreate(@"system", @"be brief"),
          PXRMessageCreate(@"user", @"hi")],
        @[PXRToolSpecCreate(@"echo", @"Echo")]) mutableCopy];
    request[@"toolChoice"] = @"auto";
    NSError *error = nil;
    NSDictionary *response = nil;
    BOOL ok = PXRAnthropicGenerate(@"http://example.test", @"claude-test", @"ak",
                                   @"2023-06-01", 1024, request, anthropicTransport,
                                   &response, &error);
    check(ok, @"anthropic generate");
    check([capturedPath isEqualToString:@"/v1/messages"], @"anthropic path");
    check([response[@"message"][@"content"] isEqualToString:@"hello"], @"anthropic content");
    check([response[@"usage"][@"inputTokens"] integerValue] == 3, @"anthropic usage");
    check([response[@"message"][@"toolCalls"][0][@"id"] isEqualToString:@"tool-1"],
          @"anthropic call id");

    __block NSMutableString *streamDeltas = [NSMutableString string];
    PXROpenAIDelta onDelta = ^(NSString *delta) {
        [streamDeltas appendString:delta];
    };
    PXROpenAITransport streamTransport = ^BOOL(NSString *path,
                                               NSDictionary<NSString *, id> *payload,
                                               NSInteger *statusCode,
                                               NSString **responseBody,
                                               NSError **error) {
        capturedPath = path;
        *statusCode = 200;
        *responseBody =
            @"data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":4,\"cache_read_input_tokens\":1}}}\n\n"
            @"data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n"
            @"data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"he\"}}\n\n"
            @"data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"llo\"}}\n\n"
            @"data: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"call-1\",\"name\":\"echo\",\"input\":{}}}\n\n"
            @"data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"text\\\":\"}}\n\n"
            @"data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"\\\"hi\\\"}\"}}\n\n"
            @"data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":2}}\n\n"
            @"data: {\"type\":\"message_stop\"}";
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXRAnthropicGenerateStream(@"http://example.test", @"claude-test", @"ak",
                                    @"2023-06-01", 1024, request, streamTransport,
                                    onDelta, &response, &error);
    check(ok && error == nil, @"anthropic stream generate");
    check([streamDeltas isEqualToString:@"hello"], @"anthropic stream deltas");
    check([response[@"message"][@"content"] isEqualToString:@"hello"],
          @"anthropic stream content");
    check([response[@"usage"][@"inputTokens"] integerValue] == 4,
          @"anthropic stream input tokens");
    check([response[@"usage"][@"outputTokens"] integerValue] == 2,
          @"anthropic stream output tokens");
    check([response[@"finishReason"] isEqualToString:@"tool_use"],
          @"anthropic stream finish reason");
    check([response[@"message"][@"toolCalls"][0][@"id"] isEqualToString:@"call-1"],
          @"anthropic stream call id");
    check([response[@"message"][@"toolCalls"][0][@"name"] isEqualToString:@"echo"],
          @"anthropic stream call name");
    check([response[@"message"][@"toolCalls"][0][@"arguments"][@"text"] isEqualToString:@"hi"],
          @"anthropic stream arguments");

    capturedPath = nil;
    PXROpenAITransport geminiTransport = ^BOOL(NSString *path,
                                               NSDictionary<NSString *, id> *payload,
                                               NSInteger *statusCode,
                                               NSString **responseBody,
                                               NSError **error) {
        capturedPath = path;
        *statusCode = 200;
        *responseBody = @"{\"candidates\":[{\"content\":{\"parts\":["
            "{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\","
            "\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],"
            "\"usageMetadata\":{\"promptTokenCount\":3,"
            "\"candidatesTokenCount\":4}}";
        return YES;
    };
    response = nil;
    ok = PXRGeminiGenerate(@"http://example.test", @"gemini-test", @"gk", 0,
                           request, geminiTransport, &response, &error);
    check(ok, @"gemini generate");
    check([capturedPath containsString:@":generateContent"], @"gemini path");
    check([response[@"message"][@"content"] isEqualToString:@"hello"], @"gemini content");
    check([response[@"message"][@"toolCalls"][0][@"name"] isEqualToString:@"echo"],
          @"gemini call name");
    check([response[@"usage"][@"inputTokens"] integerValue] == 3, @"gemini usage");

    __block NSMutableString *geminiDeltas = [NSMutableString string];
    PXROpenAIDelta geminiDelta = ^(NSString *delta) {
        [geminiDeltas appendString:delta];
    };
    PXROpenAITransport geminiStreamTransport = ^BOOL(NSString *path,
                                                     NSDictionary<NSString *, id> *payload,
                                                     NSInteger *statusCode,
                                                     NSString **responseBody,
                                                     NSError **error) {
        capturedPath = path;
        *statusCode = 200;
        *responseBody =
            @"data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"he\"}]}}]}\n\n"
            @"data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"llo\"},"
            @"{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},"
            @"\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":4,"
            @"\"candidatesTokenCount\":2}}";
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXRGeminiGenerateStream(@"http://example.test", @"gemini-test", @"gk", 0,
                                 request, geminiStreamTransport, geminiDelta,
                                 &response, &error);
    check(ok && error == nil, @"gemini stream generate");
    check([capturedPath containsString:@":streamGenerateContent?alt=sse"],
          @"gemini stream path");
    check([geminiDeltas isEqualToString:@"hello"], @"gemini stream deltas");
    check([response[@"message"][@"content"] isEqualToString:@"hello"],
          @"gemini stream content");
    check([response[@"usage"][@"inputTokens"] integerValue] == 4,
          @"gemini stream input tokens");
    check([response[@"usage"][@"outputTokens"] integerValue] == 2,
          @"gemini stream output tokens");
    check([response[@"finishReason"] isEqualToString:@"STOP"],
          @"gemini stream finish reason");
    check([response[@"message"][@"toolCalls"][0][@"name"] isEqualToString:@"echo"],
          @"gemini stream call name");
}
