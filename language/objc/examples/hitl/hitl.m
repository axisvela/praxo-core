#import <Foundation/Foundation.h>

#import "PraxoCore.h"

static PXRModelGenerate FixtureModel(void) {
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
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
        NSDictionary *call = PXRToolCallCreate(
            @"write-note-1", @"write_note",
            @{@"text": @"hello", @"visibility": @"public"});
        if (response != NULL) {
            *response = PXRResponseCreate(PXRMessageAssistant(@"", @[call]),
                                          PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

static id AllowPublicPolicy(NSDictionary *action) {
    if ([action[@"kind"] isEqualToString:@"model.generate"]) {
        return PXRDecisionCreate(YES, @"model generation");
    }
    if ([action[@"kind"] isEqualToString:@"tool.invoke"]) {
        BOOL allowed = [action[@"toolName"] isEqualToString:@"write_note"] &&
            [action[@"arguments"][@"visibility"] isEqualToString:@"public"];
        return PXRDecisionCreate(allowed, @"only public notes are permitted");
    }
    return PXRDecisionCreate(NO, @"unsupported action");
}

typedef struct {
    NSDictionary<NSString *, id> *result;
    NSString *code;
    NSInteger effects;
} RunOutcome;

static RunOutcome RunCase(NSDictionary<NSString *, id> *decision) {
    NSMutableDictionary<NSString *, id> *state = [@{@"effects": @0} mutableCopy];
    PXRToolInvoke invoke = ^id(NSDictionary<NSString *, id> *arguments,
                               NSError **error) {
        (void)arguments;
        (void)error;
        state[@"effects"] = @([state[@"effects"] integerValue] + 1);
        return @"written";
    };
    NSMutableDictionary<NSString *, id> *options = PXRAgentOptionsCreate(FixtureModel());
    options[@"tools"] = @[PXRToolCreate(
        @"write_note", @"Write a short note with the requested visibility.", invoke)];
    options[@"allowedTools"] = @[@"write_note"];
    options[@"maxSteps"] = @3;
    options[@"policy"] = ^id(NSDictionary<NSString *, id> *action) {
        return AllowPublicPolicy(action);
    };
    options[@"interruptOn"] = @[@"write_note"];
    options[@"onInterruptDecision"] = ^NSDictionary<NSString *, id> *(
        NSDictionary<NSString *, id> *interrupt) {
        (void)interrupt;
        return decision;
    };
    NSString *suffix = [decision[@"action"] isEqualToString:PXRInterruptEdit]
        ? @"edit" : @"approve";
    NSString *sessionId = [@"hitl-" stringByAppendingString:suffix];
    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(sessionId, @[]),
                                       @"Write a note.", &error);
    RunOutcome outcome;
    outcome.result = result;
    outcome.code = PXRCodeFromError(error);
    outcome.effects = [state[@"effects"] integerValue];
    return outcome;
}

int main(void) {
    @autoreleasepool {
        RunOutcome approved = RunCase(
            PXRInterruptDecisionCreate(PXRInterruptApprove, nil, nil, nil));
        if (approved.result == nil ||
            ![approved.result[@"output"] isEqualToString:@"done"] ||
            approved.effects != 1) {
            fprintf(stderr, "approve scenario failed: effects=%ld\n",
                    (long)approved.effects);
            return 1;
        }
        printf("approve: written; effects=1\n");

        RunOutcome edited = RunCase(PXRInterruptDecisionCreate(
            PXRInterruptEdit,
            @{@"text": @"hello", @"visibility": @"private"}, nil, nil));
        if (edited.result != nil ||
            ![edited.code isEqualToString:@"AGENT_POLICY_DENIED"] ||
            edited.effects != 0) {
            fprintf(stderr, "edit scenario failed: code=%s effects=%ld\n",
                    edited.code.UTF8String ?: "", (long)edited.effects);
            return 1;
        }
        printf("edit: policy rejected; effects=0\n");
    }
    return 0;
}
