#import <Foundation/Foundation.h>
#import "PraxoCore.h"
#import "PraxoDelegation.h"

static NSDictionary<NSString *, id> *DeniedTask(NSString *status, NSString *code) {
    return PXRSubagentTaskCreate(@"subagent", @"governance-parent",
                                 @"governance-child", @"isolated", status,
                                 @"", code, @"", @"");
}

int main(void) {
    @autoreleasepool {
        __block NSMutableDictionary<NSString *, NSNumber *> *effects = [NSMutableDictionary dictionary];
        __block NSInteger budget = 0;
        __block NSInteger children = 0;

        PXRToolInvoke effectInvoke = ^id(NSDictionary<NSString *, id> *arguments, NSError **error) {
            (void)error;
            NSString *target = [arguments[@"target"] isKindOfClass:[NSString class]]
                ? arguments[@"target"] : @"";
            effects[target] = @([effects[target] integerValue] + 1);
            return @"ok";
        };

        NSArray *tools = @[
            PXRToolCreate(@"record", @"record", effectInvoke),
            PXRToolCreate(@"write", @"write", effectInvoke)
        ];

        PXRModelGenerate (^makeModel)(NSString *, NSString *) =
            ^PXRModelGenerate(NSString *tool, NSString *target) {
            __block NSInteger calls = 0;
            return ^BOOL(NSDictionary<NSString *, id> *request,
                         NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                         NSError **error) {
                (void)request;
                (void)error;
                calls += 1;
                if (calls == 1) {
                    if (response != NULL) {
                        *response = PXRResponseCreate(
                            PXRMessageAssistant(@"", @[PXRToolCallCreate(@"call-1", tool,
                                                                         @{@"target": target})]),
                            PXRUsageCreate(0, 0));
                    }
                } else if (response != NULL) {
                    *response = PXRResponseCreate(PXRMessageAssistant(@"done", @[]),
                                                  PXRUsageCreate(0, 0));
                }
                return YES;
            };
        };

        id (^permissive)(NSDictionary *) = ^id(NSDictionary *action) {
            NSString *kind = action[@"kind"] ?: @"";
            if ([kind isEqualToString:@"model.generate"]) return PXRDecisionCreate(YES, @"");
            if ([kind isEqualToString:@"tool.invoke"] &&
                [action[@"toolName"] isEqualToString:@"record"]) return PXRDecisionCreate(YES, @"");
            return PXRDecisionCreate(NO, @"child may only record");
        };
        id (^parentBlocked)(NSDictionary *) = ^id(NSDictionary *action) {
            NSString *kind = action[@"kind"] ?: @"";
            if ([kind isEqualToString:@"model.generate"]) return PXRDecisionCreate(YES, @"");
            if (![kind isEqualToString:@"tool.invoke"] ||
                ![action[@"toolName"] isEqualToString:@"record"]) {
                return PXRDecisionCreate(NO, @"parent tool is not allowed");
            }
            NSString *target = action[@"arguments"][@"target"] ?: @"";
            return PXRDecisionCreate(![target isEqualToString:@"blocked"], @"blocked target");
        };
        id (^composed)(NSDictionary *) = ^id(NSDictionary *action) {
            NSDictionary *parent = parentBlocked(action);
            if (![parent[@"allowed"] boolValue]) return parent;
            return permissive(action);
        };

        PXRSubagentTask (^runChild)(PXRModelGenerate, NSArray *, id (^)(NSDictionary *),
                                    BOOL, NSInteger, NSInteger, BOOL, BOOL, BOOL) =
            ^PXRSubagentTask(PXRModelGenerate model, NSArray *allowed,
                             id (^policy)(NSDictionary *), BOOL useBudget,
                             NSInteger maxChildren, NSInteger maxDepth,
                             BOOL useChildren, BOOL cancelled, BOOL editToBlocked) {
            if (cancelled) return DeniedTask(@"cancelled", @"CANCELLED");
            if (maxDepth >= 0) return DeniedTask(@"denied", @"DEPTH_LIMIT");
            if (maxChildren >= 0 && children >= maxChildren) return DeniedTask(@"denied", @"CHILD_LIMIT");
            if (useBudget && budget <= 0) return DeniedTask(@"denied", @"BUDGET_EXHAUSTED");
            if (useChildren) children += 1;

            NSMutableDictionary *options = PXRAgentOptionsCreate(model);
            options[@"tools"] = tools;
            options[@"allowedTools"] = allowed;
            options[@"policy"] = policy;
            options[@"requirePolicy"] = @YES;
            options[@"requireToolScope"] = @YES;
            options[@"maxSteps"] = @3;
            if (editToBlocked) {
                options[@"interruptOn"] = @[@"record"];
                options[@"onInterruptDecision"] = ^NSDictionary *(NSDictionary *interrupt) {
                    (void)interrupt;
                    return PXRInterruptDecisionCreate(PXRInterruptEdit,
                                                      @{@"target": @"blocked"}, nil, nil);
                };
            }
            PXRSubagentRequest request = PXRSubagentRequestCreate(
                @"governance-parent", @"governance-child", @"run child", @"isolated");
            NSError *error = nil;
            PXRSubagentTask task = PXRSubagentRun(request, ^NSDictionary *(NSDictionary *subRequest,
                                                                          NSError **runError) {
                (void)subRequest;
                NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(@"governance-child", @[]),
                                                   @"run child", runError);
                return PXRSubagentResultCreate(@"child", @"child", result[@"output"] ?: @"");
            }, nil, &error);
            if (task == nil) return DeniedTask(@"failed", PXRCodeFromError(error));
            if (useBudget && [task[@"status"] isEqualToString:@"completed"]) budget -= 1;
            return task;
        };

        PXRSubagentTask scope = runChild(makeModel(@"write", @"escape"),
                                         @[@"record"], permissive, NO, -1, -1, NO, NO, NO);
        if (![scope[@"status"] isEqualToString:@"failed"] ||
            [effects[@"escape"] integerValue] != 0) return 1;

        PXRSubagentTask composedTask = runChild(makeModel(@"record", @"blocked"),
                                                @[@"record"], composed, NO, -1, -1, NO, NO, NO);
        if (![composedTask[@"status"] isEqualToString:@"failed"] ||
            [effects[@"blocked"] integerValue] != 0) return 1;

        budget = 1;
        PXRSubagentTask first = runChild(makeModel(@"record", @"sibling"),
                                         @[@"record"], permissive, YES, -1, -1, NO, NO, NO);
        PXRSubagentTask second = runChild(makeModel(@"record", @"sibling"),
                                          @[@"record"], permissive, YES, -1, -1, NO, NO, NO);
        if (![first[@"status"] isEqualToString:@"completed"] ||
            ![second[@"status"] isEqualToString:@"denied"] ||
            ![second[@"error"] isEqualToString:@"BUDGET_EXHAUSTED"] ||
            [effects[@"sibling"] integerValue] != 1) return 1;

        children = 0;
        PXRSubagentTask limitFirst = runChild(makeModel(@"record", @"limit"),
                                              @[@"record"], permissive, NO, 1, -1, YES, NO, NO);
        PXRSubagentTask limitSecond = runChild(makeModel(@"record", @"limit"),
                                               @[@"record"], permissive, NO, 1, -1, YES, NO, NO);
        PXRSubagentTask deep = runChild(makeModel(@"record", @"limit"),
                                        @[@"record"], permissive, NO, -1, 1, NO, NO, NO);
        if (![limitFirst[@"status"] isEqualToString:@"completed"] ||
            ![limitSecond[@"error"] isEqualToString:@"CHILD_LIMIT"] ||
            ![deep[@"error"] isEqualToString:@"DEPTH_LIMIT"] ||
            [effects[@"limit"] integerValue] != 1) return 1;

        PXRSubagentTask cancelled = runChild(makeModel(@"record", @"cancel"),
                                             @[@"record"], permissive, NO, -1, -1, NO, YES, NO);
        if (![cancelled[@"status"] isEqualToString:@"cancelled"] ||
            [effects[@"cancel"] integerValue] != 0) return 1;

        PXRSubagentTask edited = runChild(makeModel(@"record", @"edit-me"),
                                          @[@"record"], parentBlocked, NO, -1, -1, NO, NO, YES);
        if (![edited[@"status"] isEqualToString:@"failed"] ||
            [effects[@"edit-me"] integerValue] != 0 ||
            [effects[@"blocked"] integerValue] != 0) return 1;

        printf("Objective-C advanced delegation governance: 6/6 passed\n");
    }
    return 0;
}
