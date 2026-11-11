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
}
