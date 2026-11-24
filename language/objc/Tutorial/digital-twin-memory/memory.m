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

static PXRModelGenerate FixtureModel(NSString *owner) {
    NSString *scope = [owner copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray<NSDictionary *> *tools = ToolMessages(request);
        if (tools.count == 0) {
            NSDictionary *call = PXRToolCallCreate(
                @"recall-1", @"recall_memory", @{@"owner": scope});
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
                @"delete-1", @"delete_memory",
                @{@"owner": scope, @"action": @"delete_scope",
                  @"memory": @"memory-100"});
            if (response != NULL) {
                *response = PXRResponseCreate(
                    PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
            }
            return YES;
        }
        id last = ParseContent(StringValue(tools.lastObject[@"content"]));
        NSDictionary *report = @{
            @"stage": @"memory_scope_deleted",
            @"recall": first ?: [NSNull null],
            @"deletion": last ?: [NSNull null],
            @"remaining": @1,
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
    if (![StringValue(arguments[@"owner"]) isEqualToString:@"owner-100"]) {
        return @{@"allowed": @NO, @"reason": @"only owner-100 is in scope"};
    }
    NSString *tool = StringValue(action[@"toolName"]);
    if ([tool isEqualToString:@"recall_memory"]) {
        return @{@"allowed": @YES};
    }
    if ([tool isEqualToString:@"delete_memory"]) {
        BOOL allowed = [StringValue(arguments[@"action"]) isEqualToString:@"delete_scope"] &&
                       [StringValue(arguments[@"memory"]) isEqualToString:@"memory-100"];
        return @{@"allowed": allowed ? @YES : @NO,
                 @"reason": @"only memory-100 delete_scope is allowed"};
    }
    return @{@"allowed": @NO, @"reason": @"unknown tool"};
}

typedef struct {
    NSString *output;
    NSInteger reads;
    NSInteger drafts;
    NSString *code;
} Outcome;

static Outcome RunCase(NSString *owner, BOOL simulateFailure) {
    __block NSInteger reads = 0;
    __block NSInteger drafts = 0;
    PXRToolInvoke recall = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        if (![StringValue(arguments[@"owner"]) isEqualToString:@"owner-100"]) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"AGENT_POLICY_DENIED",
                                          @"only owner-100 is in scope");
            }
            return nil;
        }
        reads += 1;
        if (simulateFailure) {
            if (toolError != NULL) {
                *toolError = PXRCoreError(@"MEMORY_UNAVAILABLE",
                                          @"synthetic memory store unavailable");
            }
            return nil;
        }
        return @{
            @"owner": @"owner-100",
            @"entries": @2,
            @"consent_scoped": @YES,
            @"provenance": @YES,
            @"memories": @[
                @{@"id": @"memory-100", @"scope": @"health", @"consent": @"granted"},
                @{@"id": @"memory-200", @"scope": @"calendar", @"consent": @"granted"},
            ],
            @"source": @"memory_fixture",
        };
    };
    PXRToolInvoke deleteMemory = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
        (void)toolError;
        drafts += 1;
        return @{
            @"memory": StringValue(arguments[@"memory"]),
            @"owner": StringValue(arguments[@"owner"]),
            @"action": StringValue(arguments[@"action"]),
            @"status": @"deleted",
            @"deleted": @1,
            @"remaining": @1,
            @"irreversible": @YES,
        };
    };

    NSMutableDictionary *options = PXRAgentOptionsCreate(FixtureModel(owner));
    options[@"tools"] = @[
        PXRToolCreate(@"recall_memory",
                      @"Recall fixed consent-scoped memories with provenance.",
                      recall),
        PXRToolCreate(@"delete_memory",
                      @"Delete one fixed consent scope; no other memory access.",
                      deleteMemory),
    ];
    options[@"maxSteps"] = @4;
    options[@"allowedTools"] = @[@"recall_memory", @"delete_memory"];
    options[@"policy"] = ^id(NSDictionary *action) { return Policy(action); };
    options[@"requirePolicy"] = @YES;
    options[@"requireToolScope"] = @YES;

    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(
        options,
        PXRSessionCreate(@"digital-twin-memory", @[]),
        @"Recall fixed scoped memories, then delete the health scope.",
        &error);
    Outcome outcome;
    outcome.output = StringValue(result[@"output"]);
    outcome.reads = reads;
    outcome.drafts = drafts;
    outcome.code = error != nil ? PXRCodeFromError(error) : @"";
    return outcome;
}

static void RunTests(void) {
    Outcome success = RunCase(@"owner-100", NO);
    id report = ParseContent(success.output);
    id memory = [report isKindOfClass:[NSDictionary class]] ? report[@"recall"] : nil;
    id deletion = [report isKindOfClass:[NSDictionary class]] ? report[@"deletion"] : nil;
    BOOL ok = success.code.length == 0 && success.reads == 1 && success.drafts == 1 &&
              [report isKindOfClass:[NSDictionary class]] &&
              [report[@"stage"] isEqualToString:@"memory_scope_deleted"] &&
              [memory[@"entries"] integerValue] == 2 &&
              [memory[@"provenance"] boolValue] == YES &&
              [deletion[@"deleted"] integerValue] == 1 &&
              [report[@"remaining"] integerValue] == 1;
    if (!ok) {
        fprintf(stderr, "success verification failed: %s\n", success.output.UTF8String ?: "");
        exit(1);
    }
    printf("success: owner-100 entries=2 deleted=1 remaining=1 reads=1\n");

    Outcome denied = RunCase(@"owner-200", NO);
    if (![denied.code isEqualToString:@"AGENT_POLICY_DENIED"] ||
        denied.reads != 0 || denied.drafts != 0) {
        fprintf(stderr, "deny verification failed\n");
        exit(1);
    }
    printf("deny: AGENT_POLICY_DENIED reads=0\n");

    Outcome failure = RunCase(@"owner-100", YES);
    if (![failure.code isEqualToString:@"MEMORY_UNAVAILABLE"] ||
        failure.reads != 1 || failure.drafts != 0) {
        fprintf(stderr, "failure verification failed\n");
        exit(1);
    }
    printf("failure: MEMORY_UNAVAILABLE reads=1\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL testMode = NO;
        BOOL simulateFailure = NO;
        NSString *owner = @"owner-100";
        for (int index = 1; index < argc; index++) {
            NSString *argument = @(argv[index]);
            if ([argument isEqualToString:@"--test"]) {
                testMode = YES;
            } else if ([argument isEqualToString:@"--simulate-failure"]) {
                simulateFailure = YES;
            } else if ([argument isEqualToString:@"--owner"] && index + 1 < argc) {
                owner = @(argv[index + 1]);
            }
        }
        if (testMode) {
            RunTests();
            return 0;
        }
        Outcome outcome = RunCase(owner, simulateFailure);
        if (outcome.code.length > 0) {
            fprintf(stderr, "digital twin memory failed: reads=%ld deletes=%ld; %s\n",
                    (long)outcome.reads, (long)outcome.drafts, outcome.code.UTF8String);
            return 1;
        }
        printf("%s\n", outcome.output.UTF8String ?: "");
    }
    return 0;
}
