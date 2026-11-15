#import <Foundation/Foundation.h>
#import "PraxoCore.h"

static PXRModelGenerate FixtureModel(NSString *target) {
    NSString *value = [target copy];
    return ^BOOL(NSDictionary<NSString *, id> *request,
                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                 NSError **error) {
        (void)error;
        NSArray *messages = request[@"messages"] ?: @[];
        NSDictionary *last = messages.count > 0 ? messages.lastObject : @{};
        if ([last[@"role"] isEqualToString:@"tool"]) {
            if (response != NULL) {
                *response = PXRResponseCreate(PXRMessageAssistant(@"recorded", @[]),
                                              PXRUsageCreate(0, 0));
            }
            return YES;
        }
        NSDictionary *call = PXRToolCallCreate(@"record-1", @"record",
                                               @{@"target": value});
        if (response != NULL) {
            *response = PXRResponseCreate(PXRMessageAssistant(@"", @[call]),
                                          PXRUsageCreate(0, 0));
        }
        return YES;
    };
}

typedef struct {
    NSDictionary<NSString *, id> *result;
    NSInteger effects;
    NSError *error;
} RunOutcome;

static RunOutcome RunCase(NSString *target) {
    NSMutableDictionary<NSString *, id> *state = [@{@"effects": @0} mutableCopy];
    PXRToolInvoke invoke = ^id(NSDictionary<NSString *, id> *arguments, NSError **error) {
        NSString *value = [arguments[@"target"] isKindOfClass:[NSString class]]
            ? arguments[@"target"] : @"";
        if (![value isEqualToString:@"public"]) {
            if (error != NULL) {
                *error = PXRCoreError(@"AGENT_POLICY_DENIED",
                                      @"only the public target is permitted");
            }
            return nil;
        }
        state[@"effects"] = @([state[@"effects"] integerValue] + 1);
        return @"recorded";
    };
    NSMutableDictionary *options = PXRAgentOptionsCreate(FixtureModel(target));
    options[@"tools"] = @[PXRToolCreate(@"record",
                                        @"Record a target in an in-memory counter.",
                                        invoke)];
    options[@"maxSteps"] = @3;
    options[@"toolSelection"] = PXRToolSelectionCreate(@[@"record"]);
    options[@"allowedTools"] = @[@"record"];
    options[@"requireToolScope"] = @YES;
    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(
        options,
        PXRSessionCreate([@"consumer-" stringByAppendingString:target], @[]),
        @"Record the requested target.",
        &error);
    RunOutcome outcome;
    outcome.result = result;
    outcome.effects = [state[@"effects"] integerValue];
    outcome.error = error;
    return outcome;
}

int main(void) {
    @autoreleasepool {
        RunOutcome allowed = RunCase(@"public");
        NSString *output = allowed.result[@"output"];
        if (allowed.error != nil || ![output isEqualToString:@"recorded"] ||
            allowed.effects != 1) {
            fprintf(stderr, "allow verification failed: output=%s effects=%ld\n",
                    [output UTF8String] ?: "", (long)allowed.effects);
            return 1;
        }
        printf("allow: recorded; effects=1\n");

        RunOutcome denied = RunCase(@"private");
        NSString *code = PXRCodeFromError(denied.error);
        if (denied.error == nil || ![code isEqualToString:@"AGENT_POLICY_DENIED"] ||
            denied.effects != 0) {
            fprintf(stderr, "deny verification failed: code=%s effects=%ld\n",
                    [code UTF8String] ?: "", (long)denied.effects);
            return 1;
        }
        printf("deny: policy rejected; effects=0\n");
    }
    return 0;
}
