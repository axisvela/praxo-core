#import <Foundation/Foundation.h>

#import "PraxoCore.h"

typedef id (^HitlPolicyBlock)(NSDictionary *action);

static NSDictionary *HitlArguments(NSString *visibility) {
    return @{@"text": @"hello", @"visibility": visibility};
}

static NSDictionary *HitlCall(NSString *visibility) {
    return PXRToolCallCreate(@"write-note-1", @"write_note",
                             HitlArguments(visibility));
}

static PXRModelGenerate HitlModel(NSDictionary *call,
                                  NSMutableArray *requests) {
    NSDictionary *toolCall = [call copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        [requests addObject:request];
        NSArray *messages = [request[@"messages"] isKindOfClass:[NSArray class]]
            ? request[@"messages"] : @[];
        NSDictionary *last = messages.count > 0 ? messages.lastObject : @{};
        if ([last[@"role"] isEqualToString:@"tool"]) {
            if (response != NULL) {
                *response = PXRResponseCreate(PXRMessageAssistant(@"done", @[]),
                                              PXRUsageCreate(0, 0));
            }
            return YES;
        }
        if (response != NULL) {
            *response = PXRResponseCreate(PXRMessageAssistant(@"", @[toolCall]),
                                          PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

static HitlPolicyBlock HitlPolicy(NSMutableArray *actions) {
    return [^id(NSDictionary *action) {
        [actions addObject:action];
        if ([action[@"kind"] isEqualToString:@"model.generate"]) {
            return PXRDecisionCreate(YES, @"model generation");
        }
        if ([action[@"kind"] isEqualToString:@"tool.invoke"]) {
            BOOL allowed = [action[@"toolName"] isEqualToString:@"write_note"] &&
                [action[@"arguments"][@"visibility"] isEqualToString:@"public"];
            return PXRDecisionCreate(allowed, @"only public notes are permitted");
        }
        return PXRDecisionCreate(NO, @"unsupported action");
    } copy];
}

static NSMutableDictionary *HitlOptions(NSDictionary *call,
                                        NSMutableArray *requests,
                                        NSMutableArray *actions,
                                        NSMutableArray *events,
                                        NSMutableArray *received,
                                        NSMutableDictionary *state) {
    PXRToolInvoke invoke = ^id(NSDictionary<NSString *, id> *arguments,
                               NSError **error) {
        (void)error;
        [received addObject:arguments ?: @{}];
        state[@"effects"] = @([state[@"effects"] integerValue] + 1);
        return @"written";
    };
    NSMutableDictionary *options = PXRAgentOptionsCreate(HitlModel(call, requests));
    options[@"tools"] = @[PXRToolCreate(@"write_note",
                                        @"Write a short note with the requested visibility.",
                                        invoke)];
    options[@"allowedTools"] = @[@"write_note"];
    options[@"maxSteps"] = @3;
    options[@"interruptOn"] = @[@"write_note"];
    options[@"policy"] = HitlPolicy(actions);
    options[@"events"] = ^(NSDictionary<NSString *, id> *event) {
        [events addObject:event];
    };
    return options;
}

static NSArray *HitlTypes(NSMutableArray *events) {
    NSMutableArray *types = [NSMutableArray array];
    for (NSDictionary *event in events) {
        [types addObject:event[@"type"] ?: @""];
    }
    return types;
}

static NSArray *HitlToolActions(NSMutableArray *actions) {
    NSMutableArray *tools = [NSMutableArray array];
    for (NSDictionary *action in actions) {
        if ([action[@"kind"] isEqualToString:@"tool.invoke"]) {
            [tools addObject:action];
        }
    }
    return tools;
}

static BOOL HitlHasEvent(NSMutableArray *events, NSString *type) {
    for (NSDictionary *event in events) {
        if ([event[@"type"] isEqualToString:type]) {
            return YES;
        }
    }
    return NO;
}

void runHitlTests(void (*check)(BOOL, NSString *)) {
    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        __block NSDictionary *observed = nil;
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            observed = interrupt;
            return PXRInterruptDecisionCreate(PXRInterruptApprove, nil, nil, nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-approve", @[]),
                                           @"Write a note.", &error);
        check(error == nil && [result[@"output"] isEqualToString:@"done"],
              @"hitl approve completes");
        check([state[@"effects"] integerValue] == 1, @"hitl approve effects");
        check([observed[@"runId"] length] > 0 &&
              [observed[@"sessionId"] isEqualToString:@"hitl-approve"],
              @"hitl interrupt run and session");
        check([observed[@"call"][@"name"] isEqualToString:@"write_note"] &&
              [observed[@"call"][@"arguments"][@"visibility"] isEqualToString:@"public"],
              @"hitl interrupt call payload");
        check(PXRJSONEqual(HitlTypes(events),
                           @[@"run.started", @"tool.interrupt", @"tool.call",
                             @"run.completed"]),
              @"hitl approve event order");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            return PXRInterruptDecisionCreate(PXRInterruptEdit,
                                              HitlArguments(@"private"), nil, nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-edit", @[]),
                                           @"Write a note.", &error);
        NSArray *toolActions = HitlToolActions(actions);
        check(result == nil &&
              [PXRCodeFromError(error) isEqualToString:@"AGENT_POLICY_DENIED"],
              @"hitl edit is reauthorized and denied");
        check([state[@"effects"] integerValue] == 0, @"hitl edit has no effects");
        check(toolActions.count == 2, @"hitl edit reauthorizes once");
        check([toolActions.firstObject[@"arguments"][@"visibility"]
                  isEqualToString:@"public"] &&
              [toolActions.lastObject[@"arguments"][@"visibility"]
                  isEqualToString:@"private"],
              @"hitl edit preserves original and edited arguments");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            return PXRInterruptDecisionCreate(PXRInterruptReject, nil, nil,
                                              @"not allowed");
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-reject", @[]),
                                           @"Write a note.", &error);
        check(result == nil &&
              [PXRCodeFromError(error) isEqualToString:@"AGENT_APPROVAL_DENIED"] &&
              [error.localizedDescription containsString:@"not allowed"],
              @"hitl reject denies with reason");
        check([state[@"effects"] integerValue] == 0, @"hitl reject has no effects");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterrupt"] = ^BOOL(NSDictionary<NSString *, id> *interrupt) {
            (void)interrupt;
            return NO;
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-approval", @[]),
                                           @"Write a note.", &error);
        check(result == nil &&
              [PXRCodeFromError(error) isEqualToString:@"AGENT_APPROVAL_DENIED"],
              @"hitl approval callback can deny");
        check([state[@"effects"] integerValue] == 0,
              @"hitl approval denial has no effects");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            return PXRInterruptDecisionCreate(PXRInterruptRespond, nil,
                                              @"use cached result", nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-respond", @[]),
                                           @"Write a note.", &error);
        check(error == nil && [result[@"output"] isEqualToString:@"done"] &&
              [state[@"effects"] integerValue] == 0,
              @"hitl respond skips the tool");
        check(requests.count == 2 && received.count == 0,
              @"hitl respond continues the loop");
        NSArray *messages = requests[1][@"messages"];
        NSDictionary *last = messages.lastObject;
        id parsed = nil;
        PXRParseJSONText(last[@"content"], &parsed, NULL);
        check([last[@"role"] isEqualToString:@"tool"] &&
              [last[@"toolId"] isEqualToString:@"write-note-1"] &&
              [parsed isEqualToString:@"use cached result"],
              @"hitl respond supplies the tool result");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-unhandled", @[]),
                                           @"Write a note.", &error);
        check(result == nil &&
              [PXRCodeFromError(error) isEqualToString:@"AGENT_INTERRUPT_UNHANDLED"],
              @"hitl unhandled requires a handler");
        check([state[@"effects"] integerValue] == 0 &&
              !HitlHasEvent(events, @"tool.interrupt"),
              @"hitl unhandled has no interrupt event or effects");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            return PXRInterruptDecisionCreate(@"unknown", nil, nil, nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-invalid", @[]),
                                           @"Write a note.", &error);
        check(result == nil &&
              [PXRCodeFromError(error)
                  isEqualToString:@"AGENT_INTERRUPT_DECISION_INVALID"],
              @"hitl rejects unknown decisions");
        check([state[@"effects"] integerValue] == 0,
              @"hitl invalid decision has no effects");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            return PXRInterruptDecisionCreate(PXRInterruptEdit, nil, nil, nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-invalid-edit", @[]),
                                           @"Write a note.", &error);
        check(result == nil &&
              [PXRCodeFromError(error)
                  isEqualToString:@"AGENT_INTERRUPT_DECISION_INVALID"],
              @"hitl edit requires arguments");
        check([state[@"effects"] integerValue] == 0,
              @"hitl invalid edit has no effects");
    }

    {
        NSMutableArray *requests = [NSMutableArray array];
        NSMutableArray *actions = [NSMutableArray array];
        NSMutableArray *events = [NSMutableArray array];
        NSMutableArray *received = [NSMutableArray array];
        NSMutableDictionary *state = [@{@"effects": @0} mutableCopy];
        NSMutableDictionary *options = HitlOptions(HitlCall(@"public"), requests,
                                                   actions, events, received, state);
        __block NSString *observedText = nil;
        options[@"middleware"] = @[ (PXRToolMiddleware)^(
            NSString *runId, NSString *sessionId,
            NSMutableDictionary<NSString *, id> *call) {
            call[@"arguments"][@"text"] = @"from-middleware";
        } ];
        options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
            NSDictionary<NSString *, id> *interrupt) {
            observedText = interrupt[@"call"][@"arguments"][@"text"];
            return PXRInterruptDecisionCreate(PXRInterruptApprove, nil, nil, nil);
        };
        NSError *error = nil;
        NSDictionary *result = PXRAgentRun(options,
                                           PXRSessionCreate(@"hitl-middleware", @[]),
                                           @"Write a note.", &error);
        check(error == nil && [result[@"output"] isEqualToString:@"done"],
              @"hitl runs after middleware");
        check([observedText isEqualToString:@"from-middleware"] &&
              [received.firstObject[@"text"] isEqualToString:@"from-middleware"],
              @"hitl observes middleware arguments");
    }
}
