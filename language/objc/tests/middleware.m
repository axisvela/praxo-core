#import <Foundation/Foundation.h>
#import "PraxoCore.h"

void runMiddlewareIntegrationTests(void (*check)(BOOL, NSString *)) {
    NSString *email = @"person@example.com";
    __block NSUInteger models = 0;
    __block NSUInteger tools = 0;
    NSMutableArray *requests = [NSMutableArray array];
    NSMutableArray *events = [NSMutableArray array];
    NSDictionary *call = PXRToolCallCreate(@"id", @"echo", @{ @"nested": @[email] });
    PXRModelGenerate model = ^BOOL(NSDictionary *request, NSDictionary **response, NSError **error) {
        [requests addObject:request];
        models++;
        *response = PXRResponseCreate(PXRMessageAssistant(models % 2 ? @"" : @"ok",
                                                           models % 2 ? @[call] : @[]), PXRUsageCreate(0, 0));
        return YES;
    };
    NSMutableDictionary *options = PXRAgentOptionsCreate(model);
    options[@"tools"] = @[PXRToolCreate(@"echo", @"", ^id(NSDictionary *arguments, NSError **error) {
        tools++;
        check([arguments[@"nested"][0] isEqualToString:email], @"tool receives original arguments");
        return @{ @"nested": @[email] };
    })];
    options[@"events"] = ^(NSDictionary *event) { [events addObject:event[@"type"]]; };
    options[@"pii"] = @YES;
    options[@"systemPrompt"] = email;
    options[@"modelCallLimit"] = @2;
    options[@"toolCallLimit"] = @1;
    NSDictionary *block = @{ @"type": @"image_url", @"text": email,
                              @"image_url": @{ @"url": email }, @"data": email };
    NSMutableDictionary *history = [PXRMessageCreate(@"user", email) mutableCopy];
    history[@"contentBlocks"] = @[@{ @"type": @"text", @"text": email }, block];
    history[@"toolCalls"] = @[call];
    NSDictionary *session = PXRSessionCreate(@"s", @[history]);
    for (int i = 0; i < 2; i++) {
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options, session, email, &error);
        check([result[@"output"] isEqualToString:@"ok"] && error == nil, @"budgets reset per run");
    }
    NSArray *first = requests[0][@"messages"];
    NSArray *second = requests[1][@"messages"];
    check([first[0][@"content"] isEqualToString:@"[REDACTED:email]"] &&
          [first[1][@"content"] isEqualToString:@"[REDACTED:email]"] &&
          [first[2][@"content"] isEqualToString:@"[REDACTED:email]"], @"model input redacted");
    check([first[1][@"contentBlocks"][0][@"text"] isEqualToString:@"[REDACTED:email]"] &&
          [first[1][@"contentBlocks"][1][@"text"] isEqualToString:@"[REDACTED:email]"] &&
          [first[1][@"contentBlocks"][1][@"image_url"][@"url"] isEqualToString:email] &&
          [first[1][@"contentBlocks"][1][@"data"] isEqualToString:email], @"only block text redacted");
    check([first[1][@"toolCalls"][0][@"arguments"][@"nested"][0] isEqualToString:email] &&
          [second[3][@"toolCalls"][0][@"arguments"][@"nested"][0] isEqualToString:email],
          @"historical tool arguments unchanged");
    NSDictionary *toolResult = [NSJSONSerialization JSONObjectWithData:
        [second[4][@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    check([toolResult[@"nested"][0] isEqualToString:@"[REDACTED:email]"], @"nested tool result redacted");
    check([session[@"messages"][0][@"content"] isEqualToString:email] &&
          [block[@"text"] isEqualToString:email] &&
          [call[@"arguments"][@"nested"][0] isEqualToString:email], @"redaction does not mutate inputs");
    check(models == 4 && tools == 2, @"per-run model and tool counts");

    [requests removeAllObjects];
    [options removeObjectForKey:@"pii"];
    PXRAgentRun(options, session, email, nil);
    check([requests[0][@"messages"][0][@"content"] isEqualToString:email] &&
          [requests[1][@"messages"][4][@"content"] containsString:email], @"default leaves PII unchanged");

    options[@"modelCallLimit"] = @1;
    [events removeAllObjects];
    NSUInteger beforeModels = models;
    NSError *error = nil;
    check(PXRAgentRun(options, session, email, &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"AGENT_MODEL_CALL_LIMIT"] &&
          models == beforeModels + 1 && [events.lastObject isEqualToString:@"run.failed"], @"model limit prevents invocation");

    options[@"modelCallLimit"] = @0;
    options[@"model"] = ^BOOL(NSDictionary *request, NSDictionary **response, NSError **modelError) {
        *response = PXRResponseCreate(PXRMessageAssistant(@"", @[call, call]), PXRUsageCreate(0, 0));
        return YES;
    };
    NSUInteger beforeTools = tools;
    [events removeAllObjects];
    error = nil;
    check(PXRAgentRun(options, session, email, &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"AGENT_TOOL_CALL_LIMIT"] &&
          tools == beforeTools + 1 && events.count == 3 && [events.lastObject isEqualToString:@"run.failed"],
          @"tool limit prevents invocation and event");

    NSDictionary *schema = @{ @"type": @"object", @"required": @[@"answer"] };
    options[@"model"] = PXRModelCreateStatic(@"invalid");
    options[@"structuredOutput"] = PXRStructuredOutputCreate(schema, 1, ^NSString *(NSString *text) {
        return @"{\"answer\":1}";
    });
    error = nil;
    check([PXRAgentRun(options, session, @"", &error)[@"output"] isEqualToString:@"{\"answer\":1}"],
          @"structured repair returned");
    options[@"structuredOutput"] = PXRStructuredOutputCreate(schema, 0, nil);
    [events removeAllObjects];
    error = nil;
    check(PXRAgentRun(options, session, @"", &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"AGENT_STRUCTURED_OUTPUT"] &&
          [events.lastObject isEqualToString:@"run.failed"], @"invalid structured output fails closed");
    options[@"structuredOutput"] = PXRStructuredOutputCreate(schema, 1, ^NSString *(NSString *text) {
        return @"{}";
    });
    error = nil;
    check(PXRAgentRun(options, session, @"", &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"AGENT_STRUCTURED_OUTPUT"], @"invalid repair fails closed");
    options[@"structuredOutput"] = PXRStructuredOutputCreate(schema, 0, nil);
    options[@"model"] = PXRModelCreateStatic(@"{\"answer\":2}");
    check([PXRAgentRun(options, session, @"", nil)[@"output"] isEqualToString:@"{\"answer\":2}"],
          @"valid structured output succeeds");
    [options removeObjectForKey:@"structuredOutput"];
    options[@"model"] = PXRModelCreateStatic(@"invalid");
    check([PXRAgentRun(options, session, @"", nil)[@"output"] isEqualToString:@"invalid"],
          @"default permits unstructured output");
    options[@"structuredOutput"] = PXRStructuredOutputCreate(schema, 0, nil);
    options[@"model"] = PXRModelCreateFailing();
    error = nil;
    check(PXRAgentRun(options, session, @"", &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"MODEL_ERROR"], @"model failure is preserved");
    options[@"model"] = ^BOOL(NSDictionary *request, NSDictionary **response, NSError **modelError) {
        *response = PXRResponseCreate(PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
        return YES;
    };
    options[@"tools"] = @[PXRToolCreate(@"echo", @"", ^id(NSDictionary *arguments, NSError **toolError) {
        *toolError = PXRCoreError(@"TOOL_ERROR", @"tool failed");
        return nil;
    })];
    error = nil;
    check(PXRAgentRun(options, session, @"", &error) == nil &&
          [PXRCodeFromError(error) isEqualToString:@"TOOL_ERROR"], @"tool failure is preserved");
}
