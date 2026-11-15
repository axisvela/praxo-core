#import <Foundation/Foundation.h>

#import "PraxoCore.h"

static PXRModelGenerate TurnModel(void) {
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

static NSArray<NSDictionary<NSString *, id> *> *WireMessages(NSArray *messages) {
    NSMutableArray<NSDictionary<NSString *, id> *> *wire = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *message in messages) {
        [wire addObject:PXRMessageWire(message)];
    }
    return wire;
}

static NSDictionary<NSString *, id> *Checkpoint(NSString *identifier,
                                                NSString *sessionId,
                                                NSString *runId,
                                                NSArray *messages) {
    return @{@"id": identifier ?: @"",
             @"sessionId": sessionId ?: @"",
             @"runId": runId ?: @"",
             @"status": @"completed",
             @"messages": WireMessages(messages ?: @[])};
}

static NSDictionary<NSString *, id> *LoadCheckpoint(NSMutableSet<NSString *> *allow,
                                                    NSString *data,
                                                    NSError **error) {
    id value = PXRCheckpointUnmarshal(allow, data, error);
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

int main(void) {
    @autoreleasepool {
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
            Checkpoint(@"cp-1", session[@"id"], @"run-1", session[@"messages"]),
            &error);
        if (payload == nil) {
            fprintf(stderr, "checkpoint save failed: %s\n",
                    error.localizedDescription.UTF8String);
            return 1;
        }
        records[session[@"id"]] = payload;

        NSMutableDictionary<NSString *, id> *options = PXRAgentOptionsCreate(TurnModel());
        options[@"maxSteps"] = @2;

        NSDictionary *loaded = LoadCheckpoint(allow, records[@"session-1"], &error);
        if (loaded == nil) {
            fprintf(stderr, "checkpoint load failed\n");
            return 1;
        }
        session = PXRSessionCreate(@"session-1", loaded[@"messages"]);
        NSDictionary *second = PXRAgentRun(options, session, @"second", &error);
        if (error != nil || ![second[@"output"] isEqualToString:@"turn 3"]) {
            fprintf(stderr, "second turn failed: %s\n",
                    error.localizedDescription.UTF8String ?: "unexpected output");
            return 1;
        }

        NSMutableArray *messages = [session[@"messages"] mutableCopy];
        [messages addObject:PXRMessageCreate(@"user", @"second")];
        [messages addObject:PXRMessageAssistant(second[@"output"], @[])];
        session = PXRSessionCreate(@"session-1", messages);
        payload = PXRCheckpointMarshal(
            allow,
            @"session",
            Checkpoint(@"cp-2", session[@"id"], @"run-2", session[@"messages"]),
            &error);
        if (payload == nil) {
            fprintf(stderr, "checkpoint save failed: %s\n",
                    error.localizedDescription.UTF8String);
            return 1;
        }
        records[session[@"id"]] = payload;

        loaded = LoadCheckpoint(allow, records[@"session-1"], &error);
        if (loaded == nil) {
            fprintf(stderr, "checkpoint load failed\n");
            return 1;
        }
        session = PXRSessionCreate(@"session-1", loaded[@"messages"]);
        NSDictionary *third = PXRAgentRun(options, session, @"third", &error);
        if (error != nil || ![third[@"output"] isEqualToString:@"turn 5"]) {
            fprintf(stderr, "third turn failed: %s\n",
                    error.localizedDescription.UTF8String ?: "unexpected output");
            return 1;
        }

        printf("restored messages: %lu\n",
               (unsigned long)[loaded[@"messages"] count]);
        printf("output: %s\n", [third[@"output"] UTF8String]);
    }
    return 0;
}
