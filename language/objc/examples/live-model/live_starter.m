#import <Foundation/Foundation.h>
#import "PraxoCore.h"
#import "PraxoOpenAI.h"

static NSString *EnvOr(NSString *name, NSString *fallback) {
    NSString *value = [[NSProcessInfo processInfo] environment][name];
    return value.length == 0 ? fallback : value;
}

static NSDictionary *GetTimeSchema(void) {
    return @{
        @"type": @"object",
        @"properties": @{
            @"zone": @{
                @"type": @"string",
                @"enum": @[@"utc", @"local"],
                @"description": @"utc or local; defaults to utc",
            },
        },
    };
}

static id GetTime(NSDictionary<NSString *, id> *arguments, NSError **error) {
    (void)error;
    NSString *zone = [arguments[@"zone"] isKindOfClass:[NSString class]]
        ? arguments[@"zone"] : @"utc";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [zone isEqualToString:@"local"]
        ? [NSTimeZone localTimeZone]
        : [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = [zone isEqualToString:@"local"]
        ? @"yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        : @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    return [formatter stringFromDate:[NSDate date]];
}

int main(void) {
    @autoreleasepool {
        NSString *baseURL = EnvOr(@"PRAXO_BASE_URL", @"http://localhost:11434/v1");
        NSString *modelName = EnvOr(@"PRAXO_MODEL", @"qwen3.5:4b");
        NSString *apiKey = EnvOr(@"PRAXO_API_KEY", @"");
        NSString *prompt = EnvOr(@"PRAXO_PROMPT",
            @"What time is it? Use get_time with zone set to utc and reply with the time.");

        PXRModelGenerate adapter = PXROpenAIModelCreate(baseURL, modelName, apiKey, nil);
        PXRModelGenerate model = ^BOOL(
            NSDictionary<NSString *, id> *request,
            NSDictionary<NSString *, id> * _Nullable * _Nullable response,
            NSError **error) {
            NSDictionary *augmented = @{
                @"messages": request[@"messages"] ?: @[],
                @"tools": @[ @{
                    @"name": @"get_time",
                    @"description": @"Return the current time in ISO 8601 format for the requested zone.",
                    @"parameters": GetTimeSchema(),
                } ],
            };
            return adapter(augmented, response, error);
        };
        PXRToolInvoke getTime = ^id(NSDictionary<NSString *, id> *arguments,
                                    NSError **error) {
            return GetTime(arguments, error);
        };
        NSDictionary *tool = PXRToolCreate(
            @"get_time",
            @"Return the current time in ISO 8601 format for the requested zone.",
            getTime);
        NSMutableDictionary *options = PXRAgentOptionsCreate(model);
        options[@"tools"] = @[tool];
        options[@"systemPrompt"] =
            @"You are a concise assistant. Use the provided tools when they help.";
        options[@"maxSteps"] = @4;
        options[@"toolSelection"] = PXRToolSelectionCreate(@[@"get_time"]);
        options[@"allowedTools"] = @[@"get_time"];
        options[@"requireToolScope"] = @YES;

        NSError *runError = nil;
        NSDictionary *result = PXRAgentRun(
            options, PXRSessionCreate(@"live-model", @[]), prompt, &runError);
        if (runError != nil || result == nil) {
            fprintf(stderr,
                    "live model run failed: %s\n\n"
                    "Check PRAXO_BASE_URL (%s), PRAXO_MODEL (%s), and PRAXO_API_KEY\n",
                    [[runError localizedDescription] UTF8String] ?: "unknown error",
                    [baseURL UTF8String],
                    [modelName UTF8String]);
            return 1;
        }
        printf("%s\n", [result[@"output"] UTF8String] ?: "");
    }
    return 0;
}
