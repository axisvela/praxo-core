#import "PraxoDelegation.h"

#import "PraxoCore.h"

static NSString *PXRSubagentString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *PXRSubagentTimestamp(NSDate *date) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return [formatter stringFromDate:date];
}

PXRSubagentRequest PXRSubagentRequestCreate(
    NSString *parentSessionId,
    NSString *agentId,
    NSString *prompt,
    NSString *mode) {
    return @{
        @"parentSessionId": parentSessionId ?: @"",
        @"agentId": agentId ?: @"",
        @"prompt": prompt ?: @"",
        @"mode": mode.length > 0 ? mode : @"isolated",
    };
}

PXRSubagentResult PXRSubagentResultCreate(
    NSString *taskId,
    NSString *agentId,
    NSString *output) {
    return @{
        @"taskId": taskId ?: @"",
        @"agentId": agentId ?: @"",
        @"output": output ?: @"",
    };
}

PXRSubagentTask PXRSubagentTaskCreate(
    NSString *identifier,
    NSString *parentSessionId,
    NSString *agentId,
    NSString *mode,
    NSString *status,
    NSString *output,
    NSString *errorText,
    NSString *createdAt,
    NSString *updatedAt) {
    return @{
        @"id": identifier ?: @"",
        @"parentSessionId": parentSessionId ?: @"",
        @"agentId": agentId ?: @"",
        @"mode": mode ?: @"",
        @"status": status ?: @"",
        @"output": output ?: @"",
        @"error": errorText ?: @"",
        @"createdAt": createdAt ?: @"",
        @"updatedAt": updatedAt ?: @"",
    };
}

PXRSubagentTask PXRSubagentRun(
    PXRSubagentRequest request,
    PXRSubagentRunner runner,
    PXRSubagentClock clock,
    NSError **error) {
    NSString *parentSessionId = PXRSubagentString(request[@"parentSessionId"]);
    NSString *agentId = PXRSubagentString(request[@"agentId"]);
    if (parentSessionId.length == 0 || agentId.length == 0) {
        if (error != NULL) {
            *error = PXRCoreError(
                @"SUBAGENT_INVALID",
                @"agent: subagent parent session and agent id are required");
        }
        return nil;
    }
    NSDate *at = clock != nil ? clock() : nil;
    if (at == nil) {
        at = [NSDate date];
    }
    NSString *timestamp = PXRSubagentTimestamp(at);
    NSString *mode = [PXRSubagentString(request[@"mode"]) isEqualToString:@"fork"]
        ? @"fork" : @"isolated";

    if (runner == nil) {
        return PXRSubagentTaskCreate(@"subagent", parentSessionId, agentId, mode,
                                     @"failed", @"", @"SUBAGENT_ERROR",
                                     timestamp, timestamp);
    }
    NSError *runnerError = nil;
    PXRSubagentResult result = runner(request, &runnerError);
    if (runnerError != nil || result == nil) {
        NSString *code = PXRCodeFromError(runnerError);
        if (code.length == 0) {
            code = @"SUBAGENT_ERROR";
        }
        return PXRSubagentTaskCreate(@"subagent", parentSessionId, agentId, mode,
                                     @"failed", @"", code, timestamp, timestamp);
    }
    return PXRSubagentTaskCreate(@"subagent", parentSessionId, agentId, mode,
                                 @"completed", PXRSubagentString(result[@"output"]),
                                 @"", timestamp, timestamp);
}
