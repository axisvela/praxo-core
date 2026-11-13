#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoDelegation.h"

void runDelegationTests(void (*check)(BOOL, NSString *)) {
    PXRSubagentRequest request = PXRSubagentRequestCreate(
        @"parent", @"child", @"look up", @"fork");
    check([request[@"parentSessionId"] isEqualToString:@"parent"],
          @"delegation request parent");
    check([request[@"agentId"] isEqualToString:@"child"], @"delegation request agent");
    check([request[@"prompt"] isEqualToString:@"look up"], @"delegation request prompt");
    check([request[@"mode"] isEqualToString:@"fork"], @"delegation request mode");

    PXRSubagentClock clock = ^NSDate *{
        return [NSDate dateWithTimeIntervalSince1970:1794294000.0];
    };
    __block NSDictionary<NSString *, id> *seen = nil;
    PXRSubagentRunner runner = ^PXRSubagentResult(
        PXRSubagentRequest subagentRequest, NSError **error) {
        (void)error;
        seen = subagentRequest;
        return PXRSubagentResultCreate(@"task-1", @"child", @"done");
    };
    NSError *error = nil;
    PXRSubagentTask task = PXRSubagentRun(request, runner, clock, &error);
    check(task != nil && error == nil, @"delegation success");
    check(seen == request, @"delegation request forwarded");
    check([task[@"id"] isEqualToString:@"subagent"], @"delegation task id");
    check([task[@"parentSessionId"] isEqualToString:@"parent"],
          @"delegation task parent");
    check([task[@"agentId"] isEqualToString:@"child"], @"delegation task agent");
    check([task[@"mode"] isEqualToString:@"fork"], @"delegation task mode");
    check([task[@"status"] isEqualToString:@"completed"], @"delegation completed");
    check([task[@"output"] isEqualToString:@"done"], @"delegation output");
    check([task[@"error"] isEqualToString:@""], @"delegation completed error");
    check([task[@"createdAt"] isEqualToString:@"2026-11-10T07:00:00Z"],
          @"delegation created timestamp");
    check([task[@"updatedAt"] isEqualToString:@"2026-11-10T07:00:00Z"],
          @"delegation updated timestamp");

    PXRSubagentRunner failing = ^PXRSubagentResult(
        PXRSubagentRequest subagentRequest, NSError **runnerError) {
        (void)subagentRequest;
        if (runnerError != NULL) {
            *runnerError = PXRCoreError(@"BOOM", @"boom");
        }
        return nil;
    };
    error = nil;
    task = PXRSubagentRun(request, failing, clock, &error);
    check(task != nil && error == nil, @"delegation failure returns task");
    check([task[@"status"] isEqualToString:@"failed"], @"delegation failed");
    check([task[@"error"] isEqualToString:@"BOOM"], @"delegation error code preserved");
    check([task[@"output"] isEqualToString:@""], @"delegation failure output");
    check([task[@"updatedAt"] isEqualToString:@"2026-11-10T07:00:00Z"],
          @"delegation failure timestamp");

    PXRSubagentRunner empty = ^PXRSubagentResult(
        PXRSubagentRequest subagentRequest, NSError **runnerError) {
        (void)subagentRequest;
        (void)runnerError;
        return nil;
    };
    error = nil;
    task = PXRSubagentRun(request, empty, clock, &error);
    check(task != nil && [task[@"status"] isEqualToString:@"failed"],
          @"delegation empty result fails");
    check([task[@"error"] isEqualToString:@"SUBAGENT_ERROR"],
          @"delegation empty result error");

    error = nil;
    task = PXRSubagentRun(request, nil, clock, &error);
    check(task != nil && [task[@"status"] isEqualToString:@"failed"],
          @"delegation missing runner fails");
    check([task[@"error"] isEqualToString:@"SUBAGENT_ERROR"],
          @"delegation missing runner error");

    error = nil;
    task = PXRSubagentRun(PXRSubagentRequestCreate(@"", @"child", @"look up", nil),
                          runner, clock, &error);
    check(task == nil, @"delegation empty parent fails");
    check([PXRCodeFromError(error) isEqualToString:@"SUBAGENT_INVALID"],
          @"delegation empty parent error");

    error = nil;
    task = PXRSubagentRun(PXRSubagentRequestCreate(@"parent", @"", @"look up", nil),
                          runner, clock, &error);
    check(task == nil, @"delegation empty agent fails");
    check([PXRCodeFromError(error) isEqualToString:@"SUBAGENT_INVALID"],
          @"delegation empty agent error");

    error = nil;
    task = PXRSubagentRun(PXRSubagentRequestCreate(@"parent", @"child", @"look up", @"other"),
                          runner, clock, &error);
    check(task != nil && [task[@"mode"] isEqualToString:@"isolated"],
          @"delegation defaults to isolated");
}
