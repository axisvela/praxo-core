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

static PXRModelGenerate FixtureModel(NSString *exportId) {
    NSString *scope = [exportId copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray<NSDictionary *> *tools = ToolMessages(request);
        if (tools.count == 0) {
            NSDictionary *call = PXRToolCallCreate(
                @"inspect-1", @"inspect_export", @{@"export": scope});
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
                @"redact-1", @"draft_redaction",
                @{@"export": scope, @"action": @"redact"});
            if (response != NULL) {
                *response = PXRResponseCreate(
                    PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
            }
            return YES;
        }
        id last = ParseContent(StringValue(tools.lastObject[@"content"]));
        NSDictionary *report = @{
            @"stage": @"redaction_drafted",
            @"inspection": first ?: [NSNull null],
            @"redaction": last ?: [NSNull null],
            @"shared": @NO,
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
    if (![StringValue(arguments[@"export"]) isEqualToString:@"export-100"]) {
        return @{@"allowed": @NO, @"reason": @"only export-100 is in scope"};
    }
    NSString *tool = StringValue(action[@"toolName"]);
    if ([tool isEqualToString:@"inspect_export"]) {
        return @{@"allowed": @YES};
    }
    if ([tool isEqualToString:@"draft_redaction"]) {
        BOOL allowed = [StringValue(arguments[@"action"]) isEqualToString:@"redact"];
        return @{@"allowed": allowed ? @YES : @NO,
                 @"reason": @"only redact is allowed"};
    }
    return @{@"allowed": @NO, @"reason": @"unknown tool"};
}

typedef struct {
    NSString *output;
    NSInteger reads;
    NSInteger drafts;
    NSString *code;
} Outcome;

static Outcome RunCase(NSString *exportId, BOOL simulateFailure) {
    __block NSInteger reads = 0;
    __block NSInteger drafts = 0;
    PXRToolInvoke inspect = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        if (![StringValue(arguments[@"export"]) isEqualToString:@"export-100"]) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"AGENT_POLICY_DENIED",
                                          @"only export-100 is in scope");
            }
            return nil;
        }
        reads += 1;
        if (simulateFailure) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"EXPORT_UNAVAILABLE",
                                          @"synthetic export unavailable");
            }
            return nil;
        }
        return @{
            @"export": @"export-100",
            @"rows": @3,
            @"sensitive_fields": @[
                @{@"name": @"email", @"count": @3},
                @{@"name": @"phone", @"count": @2},
            ],
            @"redactable": @2,
            @"source": @"export_fixture",
        };
    };
    PXRToolInvoke draft = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        (void)toolError;
        drafts += 1;
        return @{
            @"redaction_id": @"redaction-100",
            @"export": StringValue(arguments[@"export"]),
            @"action": StringValue(arguments[@"action"]),
            @"status": @"draft_only",
            @"review_required": @YES,
            @"redacted_fields": @2,
            @"shared": @NO,
        };
    };

    NSMutableDictionary *options = PXRAgentOptionsCreate(FixtureModel(exportId));
    options[@"tools"] = @[
        PXRToolCreate(@"inspect_export",
                      @"Inspect fixed export fields; no DLP completeness claim.",
                      inspect),
        PXRToolCreate(@"draft_redaction",
                      @"Draft a review-only redaction; never shares the export.",
                      draft),
    ];
    options[@"maxSteps"] = @4;
    options[@"allowedTools"] = @[@"inspect_export", @"draft_redaction"];
    options[@"policy"] = ^id(NSDictionary *action) { return Policy(action); };
    options[@"requirePolicy"] = @YES;
    options[@"requireToolScope"] = @YES;

    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(
        options,
        PXRSessionCreate(@"dlp-redaction", @[]),
        @"Inspect the fixed export and draft a review-only redaction.",
        &error);
    Outcome outcome;
    outcome.output = StringValue(result[@"output"]);
    outcome.reads = reads;
    outcome.drafts = drafts;
    outcome.code = error != nil ? PXRCodeFromError(error) : @"";
    return outcome;
}

static void RunTests(void) {
    Outcome success = RunCase(@"export-100", NO);
    id report = ParseContent(success.output);
    id inspection = [report isKindOfClass:[NSDictionary class]] ? report[@"inspection"] : nil;
    id redaction = [report isKindOfClass:[NSDictionary class]] ? report[@"redaction"] : nil;
    BOOL ok = success.code.length == 0 && success.reads == 1 && success.drafts == 1 &&
              [report isKindOfClass:[NSDictionary class]] &&
              [report[@"stage"] isEqualToString:@"redaction_drafted"] &&
              [inspection[@"redactable"] integerValue] == 2 &&
              [redaction[@"status"] isEqualToString:@"draft_only"] &&
              [report[@"shared"] boolValue] == NO;
    if (!ok) {
        fprintf(stderr, "success verification failed: %s\n", success.output.UTF8String ?: "");
        exit(1);
    }
    printf("success: export-100 redactable=2 status=draft_only shared=0 reads=1\n");

    Outcome denied = RunCase(@"export-200", NO);
    if (![denied.code isEqualToString:@"AGENT_POLICY_DENIED"] ||
        denied.reads != 0 || denied.drafts != 0) {
        fprintf(stderr, "deny verification failed\n");
        exit(1);
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    Outcome failure = RunCase(@"export-100", YES);
    if (![failure.code isEqualToString:@"EXPORT_UNAVAILABLE"] ||
        failure.reads != 1 || failure.drafts != 0) {
        fprintf(stderr, "failure verification failed\n");
        exit(1);
    }
    printf("failure: EXPORT_UNAVAILABLE reads=1\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL testMode = NO;
        BOOL simulateFailure = NO;
        NSString *exportId = @"export-100";
        for (int index = 1; index < argc; index++) {
            NSString *argument = @(argv[index]);
            if ([argument isEqualToString:@"--test"]) {
                testMode = YES;
            } else if ([argument isEqualToString:@"--simulate-failure"]) {
                simulateFailure = YES;
            } else if ([argument isEqualToString:@"--export"] && index + 1 < argc) {
                exportId = @(argv[index + 1]);
            }
        }
        if (testMode) {
            RunTests();
            return 0;
        }
        Outcome outcome = RunCase(exportId, simulateFailure);
        if (outcome.code.length > 0) {
            fprintf(stderr, "dlp redaction failed: reads=%ld drafts=%ld; %s\n",
                    (long)outcome.reads, (long)outcome.drafts, outcome.code.UTF8String);
            return 1;
        }
        printf("%s\n", outcome.output.UTF8String ?: "");
    }
    return 0;
}
