#import <Foundation/Foundation.h>
#import "PraxoCore.h"

static NSString *StringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static id ParseContent(NSString *content) {
    id parsed = nil;
    if (!PXRParseJSONText(content, &parsed, NULL)) {
        return nil;
    }
    return parsed;
}

static NSArray<NSDictionary *> *ToolMessages(NSDictionary *request) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *message in request[@"messages"] ?: @[]) {
        if ([StringValue(message[@"role"]) isEqualToString:@"tool"]) {
            [out addObject:message];
        }
    }
    return out;
}

static PXRModelGenerate FixtureModel(NSString *patient) {
    NSString *scope = [patient copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray<NSDictionary *> *tools = ToolMessages(request);
        if (tools.count == 0) {
            NSDictionary *call = PXRToolCallCreate(
                @"trends-1", @"read_trends", @{@"patient": scope});
            if (response != NULL) {
                *response = PXRResponseCreate(
                    PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
            }
            return YES;
        }
        id first = ParseContent(StringValue(tools.firstObject[@"content"]));
        if (tools.count == 1) {
            if ([first isKindOfClass:[NSDictionary class]] && first[@"error"] != nil) {
                if (response != NULL) {
                    *response = PXRResponseCreate(
                        PXRMessageAssistant(StringValue(first[@"error"]), @[]),
                        PXRUsageCreate(0, 0));
                }
                return YES;
            }
            NSDictionary *call = PXRToolCallCreate(
                @"alert-1", @"draft_alert",
                @{@"patient": scope, @"action": @"route_review"});
            if (response != NULL) {
                *response = PXRResponseCreate(
                    PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
            }
            return YES;
        }
        id last = ParseContent(StringValue(tools.lastObject[@"content"]));
        NSDictionary *report = @{
            @"stage": @"care_alert_drafted",
            @"trends": first ?: [NSNull null],
            @"alert": last ?: [NSNull null],
            @"dosage_changes": @0,
        };
        NSString *text = PXRJSONText(report, NULL) ?: @"{}";
        if (response != NULL) {
            *response = PXRResponseCreate(
                PXRMessageAssistant(text, @[]), PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

static id Policy(NSDictionary<NSString *, id> *action) {
    NSString *kind = StringValue(action[@"kind"]);
    if ([kind isEqualToString:@"model.generate"]) {
        return @{@"allowed": @YES};
    }
    if (![kind isEqualToString:@"tool.invoke"]) {
        return @{@"allowed": @NO, @"reason": @"unsupported action"};
    }
    NSDictionary *arguments = action[@"arguments"] ?: @{};
    if (![StringValue(arguments[@"patient"]) isEqualToString:@"patient-100"]) {
        return @{@"allowed": @NO, @"reason": @"only patient-100 is in scope"};
    }
    NSString *tool = StringValue(action[@"toolName"]);
    if ([tool isEqualToString:@"read_trends"]) {
        return @{@"allowed": @YES};
    }
    if ([tool isEqualToString:@"draft_alert"]) {
        BOOL allowed = [StringValue(arguments[@"action"]) isEqualToString:@"route_review"];
        return @{@"allowed": allowed ? @YES : @NO,
                 @"reason": @"only route_review is allowed"};
    }
    return @{@"allowed": @NO, @"reason": @"unknown tool"};
}

typedef struct {
    NSString *output;
    NSInteger reads;
    NSInteger drafts;
    NSString *code;
} Outcome;

static Outcome RunCase(NSString *patient, BOOL simulateFailure) {
    __block NSInteger reads = 0;
    __block NSInteger drafts = 0;
    PXRToolInvoke readTrends = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        if (![StringValue(arguments[@"patient"]) isEqualToString:@"patient-100"]) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"AGENT_POLICY_DENIED",
                                          @"only patient-100 is in scope");
            }
            return nil;
        }
        reads += 1;
        if (simulateFailure) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"TREND_SOURCE_UNAVAILABLE",
                                          @"synthetic trend source unavailable");
            }
            return nil;
        }
        return @{
            @"patient": @"patient-100",
            @"days": @7,
            @"resting_hr": @88,
            @"baseline_hr": @72,
            @"adherence": @0.4,
            @"source": @"wearable_fixture",
        };
    };
    PXRToolInvoke draftAlert = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        (void)toolError;
        drafts += 1;
        return @{
            @"alert_id": @"alert-100",
            @"patient": StringValue(arguments[@"patient"]),
            @"action": StringValue(arguments[@"action"]),
            @"status": @"draft_only",
            @"review_required": @YES,
            @"dosage_changes": @0,
        };
    };

    NSMutableDictionary *options = PXRAgentOptionsCreate(FixtureModel(patient));
    options[@"tools"] = @[
        PXRToolCreate(@"read_trends",
                      @"Summarize fixed wearable trends; read-only.",
                      readTrends),
        PXRToolCreate(@"draft_alert",
                      @"Draft a review-only care alert; never changes dosage.",
                      draftAlert),
    ];
    options[@"maxSteps"] = @4;
    options[@"allowedTools"] = @[@"read_trends", @"draft_alert"];
    options[@"policy"] = ^id(NSDictionary *action) { return Policy(action); };
    options[@"requirePolicy"] = @YES;
    options[@"requireToolScope"] = @YES;

    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(
        options,
        PXRSessionCreate(@"chronic-care", @[]),
        @"Summarize fixed wearable trends and draft a review-only alert.",
        &error);
    Outcome outcome;
    outcome.output = StringValue(result[@"output"]);
    outcome.reads = reads;
    outcome.drafts = drafts;
    outcome.code = error != nil ? PXRCodeFromError(error) : @"";
    return outcome;
}

static void RunTests(void) {
    Outcome success = RunCase(@"patient-100", NO);
    id report = ParseContent(success.output);
    id trends = [report isKindOfClass:[NSDictionary class]] ? report[@"trends"] : nil;
    id alert = [report isKindOfClass:[NSDictionary class]] ? report[@"alert"] : nil;
    BOOL ok = success.code.length == 0 && success.reads == 1 && success.drafts == 1 &&
              [report isKindOfClass:[NSDictionary class]] &&
              [report[@"stage"] isEqualToString:@"care_alert_drafted"] &&
              [trends[@"resting_hr"] integerValue] == 88 &&
              [alert[@"status"] isEqualToString:@"draft_only"] &&
              [report[@"dosage_changes"] integerValue] == 0;
    if (!ok) {
        fprintf(stderr, "success verification failed: %s\n", success.output.UTF8String ?: "");
        exit(1);
    }
    printf("success: patient-100 resting_hr=88 status=draft_only dosage_changes=0 reads=1\n");

    Outcome denied = RunCase(@"patient-200", NO);
    if (![denied.code isEqualToString:@"AGENT_POLICY_DENIED"] ||
        denied.reads != 0 || denied.drafts != 0) {
        fprintf(stderr, "deny verification failed\n");
        exit(1);
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    Outcome failure = RunCase(@"patient-100", YES);
    if (![failure.code isEqualToString:@"TREND_SOURCE_UNAVAILABLE"] ||
        failure.reads != 1 || failure.drafts != 0) {
        fprintf(stderr, "failure verification failed\n");
        exit(1);
    }
    printf("failure: TREND_SOURCE_UNAVAILABLE reads=1\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL testMode = NO;
        BOOL simulateFailure = NO;
        NSString *patient = @"patient-100";
        for (int index = 1; index < argc; index++) {
            NSString *argument = @(argv[index]);
            if ([argument isEqualToString:@"--test"]) {
                testMode = YES;
            } else if ([argument isEqualToString:@"--simulate-failure"]) {
                simulateFailure = YES;
            } else if ([argument isEqualToString:@"--patient"] && index + 1 < argc) {
                patient = @(argv[index + 1]);
            }
        }
        if (testMode) {
            RunTests();
            return 0;
        }
        Outcome outcome = RunCase(patient, simulateFailure);
        if (outcome.code.length > 0) {
            fprintf(stderr, "chronic care failed: reads=%ld drafts=%ld; %s\n",
                    (long)outcome.reads, (long)outcome.drafts, outcome.code.UTF8String);
            return 1;
        }
        printf("%s\n", outcome.output.UTF8String ?: "");
    }
    return 0;
}
