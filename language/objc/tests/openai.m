#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoOpenAI.h"

void runOpenAIAdapterTests(void (*check)(BOOL, NSString *)) {
    __block NSString *capturedPath = nil;
    __block NSDictionary *capturedPayload = nil;
    PXROpenAITransport transport = ^BOOL(NSString *path,
                                         NSDictionary<NSString *, id> *payload,
                                         NSInteger *statusCode,
                                         NSString **responseBody,
                                         NSError **error) {
        capturedPath = path;
        capturedPayload = payload;
        *statusCode = 200;
        *responseBody = @"{\"choices\":[{\"message\":{\"content\":\"hello\","
            "\"tool_calls\":[{\"id\":\"c1\",\"type\":\"function\",\"function\":"
            "{\"name\":\"echo\",\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]},"
            "\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":3,"
            "\"completion_tokens\":2}}";
        return YES;
    };
    NSMutableDictionary *request = [PXRRequestCreate(
        @[PXRMessageCreate(@"user", @"hi")],
        @[PXRToolSpecCreate(@"echo", @"Echo")]) mutableCopy];
    request[@"toolChoice"] = @"auto";
    NSError *error = nil;
    NSDictionary *response = nil;
    BOOL ok = PXROpenAIGenerate(@"http://example.test/v1", @"test-model", nil,
                                request, transport, &response, &error);
    check(ok && error == nil, @"openai generate");
    check([capturedPath isEqualToString:@"/chat/completions"], @"openai path");
    check([capturedPayload[@"model"] isEqualToString:@"test-model"], @"openai model");
    check([capturedPayload[@"messages"][0][@"content"] isEqualToString:@"hi"],
          @"openai message");
    check([capturedPayload[@"tools"][0][@"function"][@"name"] isEqualToString:@"echo"],
          @"openai tool");
    check([capturedPayload[@"tool_choice"] isEqualToString:@"auto"],
          @"openai tool choice");
    check([response[@"message"][@"content"] isEqualToString:@"hello"],
          @"openai content");
    check([response[@"message"][@"toolCalls"][0][@"name"] isEqualToString:@"echo"],
          @"openai call name");
    check([response[@"message"][@"toolCalls"][0][@"arguments"][@"text"]
           isEqualToString:@"hi"], @"openai call arguments");
    check([response[@"usage"][@"inputTokens"] integerValue] == 3,
          @"openai input tokens");
    check([response[@"usage"][@"outputTokens"] integerValue] == 2,
          @"openai output tokens");
    check([response[@"finishReason"] isEqualToString:@"tool_calls"],
          @"openai finish reason");

    capturedPayload = nil;
    NSDictionary *assistant = PXRMessageAssistant(
        @"", @[PXRToolCallCreate(@"c1", @"echo", @{ @"text": @"bye" })]);
    NSDictionary *tool = PXRMessageTool(@"{\"ok\":true}", @"c1");
    PXROpenAITransport mapping = ^BOOL(NSString *path,
                                       NSDictionary<NSString *, id> *payload,
                                       NSInteger *statusCode,
                                       NSString **responseBody,
                                       NSError **error) {
        capturedPayload = payload;
        *statusCode = 200;
        *responseBody = @"{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}";
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXROpenAIGenerate(@"http://example.test/v1", @"test-model", nil,
                           PXRRequestCreate(@[assistant, tool], @[]), mapping,
                           &response, &error);
    check(ok && error == nil, @"openai mapping generate");
    check([capturedPayload[@"messages"][0][@"tool_calls"][0][@"id"]
           isEqualToString:@"c1"], @"openai assistant tool id");
    NSDictionary *arguments = [NSJSONSerialization
        JSONObjectWithData:[capturedPayload[@"messages"][0][@"tool_calls"][0]
                             [@"function"][@"arguments"]
                             dataUsingEncoding:NSUTF8StringEncoding]
                   options:0
                     error:nil];
    check([arguments[@"text"] isEqualToString:@"bye"],
          @"openai assistant tool arguments");
    check([capturedPayload[@"messages"][1][@"tool_call_id"] isEqualToString:@"c1"],
          @"openai tool message id");

    PXROpenAITransport failing = ^BOOL(NSString *path,
                                       NSDictionary<NSString *, id> *payload,
                                       NSInteger *statusCode,
                                       NSString **responseBody,
                                       NSError **error) {
        *statusCode = 500;
        *responseBody = @"server error";
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXROpenAIGenerate(@"http://example.test/v1", @"test-model", nil,
                           request, failing, &response, &error);
    check(!ok && [PXRCodeFromError(error) isEqualToString:@"PROVIDER_HTTP"],
          @"openai http error");

    __block NSUInteger calls = 0;
    PXROpenAITransport counting = ^BOOL(NSString *path,
                                        NSDictionary<NSString *, id> *payload,
                                        NSInteger *statusCode,
                                        NSString **responseBody,
                                        NSError **error) {
        calls++;
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXROpenAIGenerate(@"", @"test-model", nil, request, counting,
                           &response, &error);
    check(!ok && calls == 0 &&
          [PXRCodeFromError(error) isEqualToString:@"PROVIDER_HTTP"],
          @"openai missing base url");

    PXROpenAITransport badArguments = ^BOOL(NSString *path,
                                            NSDictionary<NSString *, id> *payload,
                                            NSInteger *statusCode,
                                            NSString **responseBody,
                                            NSError **error) {
        *statusCode = 200;
        *responseBody = @"{\"choices\":[{\"message\":{\"content\":\"\","
            "\"tool_calls\":[{\"id\":\"c1\",\"function\":{\"name\":\"echo\","
            "\"arguments\":\"not json\"}}]}}]}";
        return YES;
    };
    response = nil;
    error = nil;
    ok = PXROpenAIGenerate(@"http://example.test/v1", @"test-model", nil,
                           request, badArguments, &response, &error);
    check(!ok && [PXRCodeFromError(error) isEqualToString:@"PROVIDER_JSON"],
          @"openai invalid arguments");

    PXRModelGenerate model = PXROpenAIModelCreate(
        @"http://example.test/v1", @"test-model", nil, transport);
    response = nil;
    error = nil;
    ok = model(request, &response, &error);
    check(ok && [response[@"message"][@"content"] isEqualToString:@"hello"],
          @"openai model callback");
}
