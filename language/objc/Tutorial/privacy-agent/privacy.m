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

static PXRModelGenerate FixtureModel(NSString *subject) {
    NSString *scope = [subject copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray<NSDictionary *> *tools = ToolMessages(request);
        if (tools.count == 0) {
            NSDictionary *call = PXRToolCallCreate(
                @"classify-1", @"classify_messages", @{@"subject": scope});
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
                @"request-1", @"draft_privacy_request",
                @{@"subject": scope, @"action": @"request_deletion"});
            if (response != NULL) {
                *response = PXRResponseCreate(
                    PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
            }
            return YES;
        }
        id last = ParseContent(StringValue(tools.lastObject[@"content"]));
        NSDictionary *report = @{
            @"stage": @"privacy_request_drafted",
            @"classification": first ?: [NSNull null],
            @"request": last ?: [NSNull null],
            @"actions": @0,
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
    if (![StringValue(arguments[@"subject"]) isEqualToString:@"subject-100"]) {
        return @{@"allowed": @NO, @"reason": @"only subject-100 is in scope"};
    }
    NSString *tool = StringValue(action[@"toolName"]);
    if ([tool isEqualToString:@"classify_messages"]) {
        return @{@"allowed": @YES};
    }
    if ([tool isEqualToString:@"draft_privacy_request"]) {
        BOOL allowed = [StringValue(arguments[@"action"]) isEqualToString:@"request_deletion"];
        return @{@"allowed": allowed ? @YES : @NO,
                 @"reason": @"only request_deletion is allowed"};
    }
    return @{@"allowed": @NO, @"reason": @"unknown tool"};
}

typedef struct {
    NSString *output;
    NSInteger reads;
    NSInteger drafts;
    NSString *code;
} Outcome;

static Outcome RunCase(NSString *subject, BOOL simulateFailure) {
    __block NSInteger reads = 0;
    __block NSInteger drafts = 0;
    PXRToolInvoke classify = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        if (![StringValue(arguments[@"subject"]) isEqualToString:@"subject-100"]) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"AGENT_POLICY_DENIED",
                                          @"only subject-100 is in scope");
            }
            return nil;
        }
        reads += 1;
        if (simulateFailure) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"MESSAGE_SOURCE_UNAVAILABLE",
                                          @"synthetic message source unavailable");
            }
            return nil;
        }
        return @{
            @"subject": @"subject-100",
            @"messages": @2,
            @"exposures": @[
                @{@"type": @"email", @"count": @2},
                @{@"type": @"phone", @"count": @1},
            ],
            @"source": @"message_fixture",
        };
    };
    PXRToolInvoke draft = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        (void)toolError;
        drafts += 1;
        return @{
            @"request_id": @"privacy-100",
            @"subject": StringValue(arguments[@"subject"]),
            @"action": StringValue(arguments[@"action"]),
            @"status": @"draft_only",
            @"review_required": @YES,
            @"actions": @0,
        };
    };

    NSMutableDictionary *options = PXRAgentOptionsCreate(FixtureModel(subject));
    options[@"tools"] = @[
        PXRToolCreate(@"classify_messages",
                      @"Classify fixed messages for sensitive exposure; read-only.",
                      classify),
        PXRToolCreate(@"draft_privacy_request",
                      @"Draft a review-only deletion request; never submits it.",
                      draft),
    ];
    options[@"maxSteps"] = @4;
    options[@"allowedTools"] = @[@"classify_messages", @"draft_privacy_request"];
    options[@"policy"] = ^id(NSDictionary *action) { return Policy(action); };
    options[@"requirePolicy"] = @YES;
    options[@"requireToolScope"] = @YES;

    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(
        options,
        PXRSessionCreate(@"privacy-agent", @[]),
        @"Classify the fixed messages and draft a review-only deletion request.",
        &error);
    Outcome outcome;
    outcome.output = StringValue(result[@"output"]);
    outcome.reads = reads;
    outcome.drafts = drafts;
    outcome.code = error != nil ? PXRCodeFromError(error) : @"";
    return outcome;
}

static void RunTests(void) {
    Outcome success = RunCase(@"subject-100", NO);
    id report = ParseContent(success.output);
    NSArray *exposures = nil;
    if ([report isKindOfClass:[NSDictionary class]]) {
        id classification = report[@"classification"];
        if ([classification isKindOfClass:[NSDictionary class]]) {
            exposures = classification[@"exposures"];
        }
    }
    id request = [report isKindOfClass:[NSDictionary class]] ? report[@"request"] : nil;
    BOOL ok = success.code.length == 0 && success.reads == 1 && success.drafts == 1 &&
              [report isKindOfClass:[NSDictionary class]] &&
              [report[@"stage"] isEqualToString:@"privacy_request_drafted"] &&
              exposures.count == 2 &&
              [request[@"status"] isEqualToString:@"draft_only"] &&
              [report[@"actions"] integerValue] == 0;
    if (!ok) {
        fprintf(stderr, "success verification failed: %s\n", success.output.UTF8String ?: "");
        exit(1);
    }
    printf("success: subject-100 exposures=2 status=draft_only actions=0 reads=1\n");

    Outcome denied = RunCase(@"subject-200", NO);
    if (![denied.code isEqualToString:@"AGENT_POLICY_DENIED"] ||
        denied.reads != 0 || denied.drafts != 0) {
        fprintf(stderr, "deny verification failed: code=%s reads=%ld drafts=%ld\n",
                denied.code.UTF8String ?: "", (long)denied.reads, (long)denied.drafts);
        exit(1);
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    Outcome failure = RunCase(@"subject-100", YES);
    if (![failure.code isEqualToString:@"MESSAGE_SOURCE_UNAVAILABLE"] ||
        failure.reads != 1 || failure.drafts != 0) {
        fprintf(stderr, "failure verification failed: code=%s reads=%ld drafts=%ld\n",
                failure.code.UTF8String ?: "", (long)failure.reads, (long)failure.drafts);
        exit(1);
    }
    printf("failure: MESSAGE_SOURCE_UNAVAILABLE reads=1\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL testMode = NO;
        BOOL simulateFailure = NO;
        NSString *subject = @"subject-100";
        for (int index = 1; index < argc; index++) {
            NSString *argument = @(argv[index]);
            if ([argument isEqualToString:@"--test"]) {
                testMode = YES;
            } else if ([argument isEqualToString:@"--simulate-failure"]) {
                simulateFailure = YES;
            } else if ([argument isEqualToString:@"--subject"] && index + 1 < argc) {
                subject = @(argv[index + 1]);
            }
        }
        if (testMode) {
            RunTests();
            return 0;
        }
        Outcome outcome = RunCase(subject, simulateFailure);
        if (outcome.code.length > 0) {
            fprintf(stderr, "privacy agent failed: reads=%ld drafts=%ld; %s\n",
                    (long)outcome.reads, (long)outcome.drafts, outcome.code.UTF8String);
            return 1;
        }
        if ([outcome.output isEqualToString:@"MESSAGE_SOURCE_UNAVAILABLE"]) {
            printf("%s\n", outcome.output.UTF8String);
            return 1;
        }
        printf("%s\n", outcome.output.UTF8String ?: "");
    }
    return 0;
}
