#import "PraxoCore.h"

NSString *const PXRInterruptApprove = @"approve";
NSString *const PXRInterruptEdit = @"edit";
NSString *const PXRInterruptReject = @"reject";
NSString *const PXRInterruptRespond = @"respond";

NSDictionary<NSString *, id> *PXRInterruptCreate(
    NSString *runId,
    NSString *sessionId,
    NSDictionary<NSString *, id> *call) {
    return @{
        @"runId": runId ?: @"",
        @"sessionId": sessionId ?: @"",
        @"call": call ?: @{},
    };
}

NSDictionary<NSString *, id> *PXRInterruptDecisionCreate(
    NSString *action,
    NSDictionary<NSString *, id> *arguments,
    NSString *response,
    NSString *reason) {
    NSMutableDictionary *decision = [NSMutableDictionary dictionary];
    decision[@"action"] = action ?: @"";
    if (arguments != nil) {
        decision[@"arguments"] = arguments;
    }
    decision[@"response"] = response ?: @"";
    decision[@"reason"] = reason ?: @"";
    return decision;
}
