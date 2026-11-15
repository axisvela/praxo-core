#import <Foundation/Foundation.h>

#import "PraxoCore.h"

static PXRModelGenerate SessionCheckpointModel(void) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray *messages = [request[@"messages"] isKindOfClass:[NSArray class]]
            ? request[@"messages"] : @[];
        NSString *content = [NSString stringWithFormat:@"turn %lu",
                             (unsigned long)messages.count];
        if (response != NULL) {
            *response = PXRResponseCreate(PXRMessageAssistant(content, @[]),
                                          PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

static NSDictionary<NSString *, id> *SessionCheckpointRecord(NSString *identifier,
                                                             NSString *sessionId,
                                                             NSString *runId,
                                                             NSArray *messages) {
    NSMutableArray *wire = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *message in messages) {
        [wire addObject:PXRMessageWire(message)];
    }
    return @{@"id": identifier,
             @"sessionId": sessionId,
             @"runId": runId,
             @"status": @"completed",
             @"messages": wire};
}

void runSessionCheckpointTests(void (*check)(BOOL, NSString *)) {
    NSError *error = nil;
    NSMutableSet<NSString *> *allow = PXRCheckpointAllowlistCreate();
    PXRCheckpointRegister(allow, @"session");
    NSMutableDictionary<NSString *, NSString *> *records = [NSMutableDictionary dictionary];

    NSDictionary *session = PXRSessionCreate(@"session-1", @[
        PXRMessageCreate(@"user", @"first"),
        PXRMessageCreate(@"assistant", @"ack"),
    ]);
    NSString *payload = PXRCheckpointMarshal(
        allow,
        @"session",
        SessionCheckpointRecord(@"cp-1", session[@"id"], @"run-1", session[@"messages"]),
        &error);
    check(payload != nil, @"session checkpoint cp-1 marshals");
    records[session[@"id"]] = payload ?: @"";

    NSMutableDictionary<NSString *, id> *options = PXRAgentOptionsCreate(SessionCheckpointModel());
    options[@"maxSteps"] = @2;

    NSDictionary *loaded = PXRCheckpointUnmarshal(allow, records[@"session-1"], &error);
    check([loaded isKindOfClass:[NSDictionary class]], @"session checkpoint cp-1 unmarshals");
    check([loaded[@"id"] isEqualToString:@"cp-1"], @"session checkpoint cp-1 id");
    check([loaded[@"runId"] isEqualToString:@"run-1"], @"session checkpoint cp-1 run id");
    check([loaded[@"messages"] count] == 2, @"session checkpoint cp-1 messages");
    session = PXRSessionCreate(@"session-1", loaded[@"messages"]);
    NSDictionary *second = PXRAgentRun(options, session, @"second", &error);
    check(error == nil, @"session checkpoint second turn succeeds");
    check([second[@"output"] isEqualToString:@"turn 3"], @"session checkpoint second turn output");

    NSMutableArray *messages = [session[@"messages"] mutableCopy];
    [messages addObject:PXRMessageCreate(@"user", @"second")];
    [messages addObject:PXRMessageAssistant(second[@"output"], @[])];
    session = PXRSessionCreate(@"session-1", messages);
    payload = PXRCheckpointMarshal(
        allow,
        @"session",
        SessionCheckpointRecord(@"cp-2", session[@"id"], @"run-2", session[@"messages"]),
        &error);
    check(payload != nil, @"session checkpoint cp-2 marshals");
    records[session[@"id"]] = payload ?: @"";

    loaded = PXRCheckpointUnmarshal(allow, records[@"session-1"], &error);
    check([loaded isKindOfClass:[NSDictionary class]], @"session checkpoint cp-2 unmarshals");
    check([loaded[@"id"] isEqualToString:@"cp-2"], @"session checkpoint cp-2 id");
    check([loaded[@"runId"] isEqualToString:@"run-2"], @"session checkpoint cp-2 run id");
    check([loaded[@"messages"] count] == 4, @"session checkpoint cp-2 messages");
    session = PXRSessionCreate(@"session-1", loaded[@"messages"]);
    NSDictionary *third = PXRAgentRun(options, session, @"third", &error);
    check(error == nil, @"session checkpoint third turn succeeds");
    check([third[@"output"] isEqualToString:@"turn 5"], @"session checkpoint third turn output");
}
