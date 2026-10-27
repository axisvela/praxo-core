#import <Foundation/Foundation.h>
#import "PraxoCore.h"

void runCorrelationTests(void (*check)(BOOL, NSString *)) {
    NSMutableDictionary *options = PXRAgentOptionsCreate(PXRModelCreateStatic(@"ok"));
    options[@"sessionId"] = @"different-option";
    NSMutableArray *events = [NSMutableArray array];
    options[@"events"] = ^(NSDictionary *event) { [events addObject:event]; };
    NSMutableSet *ids = [NSMutableSet set];
    for (NSUInteger i = 0; i < 100; i++) {
        NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(@"actual-session", @[]), @"hi", nil);
        NSString *runId = result[@"runId"];
        check(runId.length > 0 && ![ids containsObject:runId], @"successive runs have distinct IDs");
        if (runId != nil) [ids addObject:runId];
        NSArray *pair = [events subarrayWithRange:NSMakeRange(events.count - 2, 2)];
        for (NSDictionary *event in pair) {
            check([event[@"sessionId"] isEqualToString:@"actual-session"] &&
                  [event[@"runId"] isEqualToString:runId], @"success event correlation");
        }
    }
    [events removeAllObjects];
    NSDictionary *call = PXRToolCallCreate(@"call", @"echo", @{});
    options[@"model"] = PXRModelCreateScripted(@[
        PXRResponseCreate(PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0)),
        PXRResponseCreate(PXRMessageAssistant(@"ok", @[]), PXRUsageCreate(0, 0))
    ]);
    options[@"tools"] = @[PXRToolCreate(@"echo", @"", ^id(NSDictionary *arguments, NSError **error) {
        return arguments;
    })];
    NSDictionary *toolResult = PXRAgentRun(options, PXRSessionCreate(@"tool-session", @[]), @"hi", nil);
    check(events.count == 3 && [events[1][@"type"] isEqualToString:@"tool.call"] &&
          [events[1][@"sessionId"] isEqualToString:@"tool-session"] &&
          [events[1][@"runId"] isEqualToString:toolResult[@"runId"]], @"tool event correlation");
    [events removeAllObjects];
    options[@"model"] = PXRModelCreateFailing();
    NSError *error = nil;
    check(PXRAgentRun(options, PXRSessionCreate(@"failure-session", @[]), @"hi", &error) == nil,
          @"failing run returns nil");
    check(events.count == 2 && [events[0][@"type"] isEqualToString:@"run.started"] &&
          [events[1][@"type"] isEqualToString:@"run.failed"] &&
          [events[0][@"sessionId"] isEqualToString:@"failure-session"] &&
          [events[1][@"sessionId"] isEqualToString:@"failure-session"] &&
          [events[0][@"runId"] length] > 0 &&
          [events[0][@"runId"] isEqualToString:events[1][@"runId"]], @"failure event correlation");
    [events removeAllObjects];
    [options removeObjectForKey:@"model"];
    check(PXRAgentRun(options, PXRSessionCreate(@"missing-model-session", @[]), @"hi", &error) == nil &&
          events.count == 1 && [events[0][@"type"] isEqualToString:@"run.failed"] &&
          [events[0][@"sessionId"] isEqualToString:@"missing-model-session"] &&
          [events[0][@"runId"] isEqualToString:@""], @"missing model callback behavior");
}
