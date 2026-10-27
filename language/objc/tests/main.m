#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoJSON.h"
#import "PraxoWire.h"

static NSUInteger failures = 0;
static NSUInteger checks = 0;

void runCorrelationTests(void (*check)(BOOL, NSString *));
void runMiddlewareIntegrationTests(void (*check)(BOOL, NSString *));

static void check(BOOL condition, NSString *message) {
    checks++;
    if (!condition) {
        failures++;
        fprintf(stderr, "FAIL %s\n", message.UTF8String);
    }
}

static NSString *stringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSInteger integerValue(id value) {
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

static NSArray *arrayValue(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSDictionary *objectValue(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static NSDictionary<NSString *, id> *loadJSON(NSString *path) {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:&error];
    if (text == nil) {
        fprintf(stderr, "cannot read %s: %s\n", path.UTF8String,
                error.description.UTF8String);
        return nil;
    }
    id value = nil;
    if (!PXRParseJSONText(text, &value, &error) ||
        ![value isKindOfClass:[NSDictionary class]]) {
        fprintf(stderr, "cannot parse %s: %s\n", path.UTF8String,
                error.description.UTF8String);
        return nil;
    }
    return value;
}

static NSArray<NSDictionary<NSString *, id> *> *vectors(NSDictionary *group) {
    id value = group[@"vectors"];
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static void runToolCall(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSString *operation = stringValue(input[@"operation"]);
    NSString *content = stringValue(input[@"content"]);
    if ([operation isEqualToString:@"strip"]) {
        check([PXRStripToolCallMarkup(content) isEqualToString:stringValue(expect[@"text"])],
              [identifier stringByAppendingString:@" strip result"]);
        return;
    }
    NSError *error = nil;
    NSDictionary *call = PXRParseToolCall(content, &error);
    if ([expect[@"nil"] boolValue]) {
        check(call == nil, [identifier stringByAppendingString:@" expected nil"]);
        return;
    }
    check(call != nil, [identifier stringByAppendingString:@" expected call"]);
    if (call == nil) {
        return;
    }
    check([call[@"name"] isEqual:expect[@"name"]],
          [identifier stringByAppendingString:@" name"]);
    check(PXRJSONEqual(call[@"input"], expect[@"input"]),
          [identifier stringByAppendingString:@" input"]);
}

static void runSchema(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSArray<NSString *> *paths = PXRValidateSchema(objectValue(input[@"schema"]), input[@"data"]);
    check((paths.count == 0) == [expect[@"valid"] boolValue],
          [identifier stringByAppendingString:@" validity"]);
    NSArray *expectedPaths = expect[@"errorPaths"];
    if ([expectedPaths isKindOfClass:[NSArray class]]) {
        check(PXRJSONEqual([paths sortedArrayUsingSelector:@selector(compare:)],
                           [expectedPaths sortedArrayUsingSelector:@selector(compare:)]),
              [identifier stringByAppendingString:@" error paths"]);
    }
}

static void runPlugin(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSString *raw = input[@"raw"];
    if (raw == nil) {
        raw = PXRJSONText(input[@"manifest"] ?: @{}, nil);
    }
    NSError *error = nil;
    NSDictionary *manifest = PXRParseManifest(raw, &error);
    BOOL valid = manifest != nil;
    check(valid == [expect[@"valid"] boolValue],
          [NSString stringWithFormat:@"%@ validity (%@)", identifier,
           error.description ?: @"no error"]);
    if (!valid) {
        return;
    }
    if (expect[@"id"] != nil) {
        check([manifest[@"id"] isEqual:expect[@"id"]],
              [identifier stringByAppendingString:@" id"]);
    }
    if (expect[@"kind"] != nil) {
        check([manifest[@"kind"] isEqual:expect[@"kind"]],
              [identifier stringByAppendingString:@" kind"]);
    }
}

static void runMemory(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSMutableDictionary *store = PXRMemoryStoreCreate();
    for (NSDictionary *put in arrayValue(input[@"puts"])) {
        NSDictionary *record = objectValue(put[@"record"]);
        PXRMemoryPut(store, stringValue(put[@"session"]),
                     PXRMemoryRecordCreate(stringValue(record[@"id"]),
                                           stringValue(record[@"frame"]),
                                           stringValue(record[@"content"]),
                                           record[@"createdAt"]));
    }
    NSArray *records = PXRMemorySearch(store, stringValue(input[@"session"]),
                                       stringValue(input[@"query"]),
                                       integerValue(input[@"limit"]));
    id ids = records.count > 0 ? [records valueForKey:@"id"] : [NSNull null];
    id contents = records.count > 0 ? [records valueForKey:@"content"] : [NSNull null];
    check(PXRJSONEqual(ids, expect[@"ids"]),
          [identifier stringByAppendingString:@" ids"]);
    check(PXRJSONEqual(contents, expect[@"contents"]),
          [identifier stringByAppendingString:@" contents"]);
}

static void runEvent(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSMutableArray<NSDictionary *> *events = [NSMutableArray array];
    for (NSString *type in arrayValue(input[@"events"])) {
        [events addObject:PXREventCreate(type, @"s1", nil, nil)];
    }
    if ([stringValue(input[@"sink"]) isEqualToString:@"multi"]) {
        NSInteger count = MAX(1, integerValue(input[@"sinkCount"]));
        NSMutableArray<PXREventSink> *sinks = [NSMutableArray array];
        NSMutableArray<NSMutableArray<NSString *> *> *types = [NSMutableArray array];
        for (NSInteger index = 0; index < count; index++) {
            NSMutableArray<NSString *> *sinkTypes = [NSMutableArray array];
            [types addObject:sinkTypes];
            [sinks addObject:^(NSDictionary *event) {
                [sinkTypes addObject:stringValue(event[@"type"])];
            }];
        }
        PXREventSink multi = PXRMultiSink(sinks);
        for (NSDictionary *event in events) {
            multi(event);
        }
        check(PXRJSONEqual(types, expect[@"perSink"]),
              [identifier stringByAppendingString:@" perSink"]);
        return;
    }
    NSMutableArray<NSString *> *delivered = [NSMutableArray array];
    PXREventSink sink = ^(NSDictionary *event) {
        [delivered addObject:stringValue(event[@"type"])];
    };
    PXREventSink filter = PXRFilterSink(sink, arrayValue(input[@"predicateTypes"]));
    for (NSDictionary *event in events) {
        filter(event);
    }
    id output = delivered.count > 0 ? delivered : [NSNull null];
    check(PXRJSONEqual(output, expect[@"delivered"]),
          [identifier stringByAppendingString:@" delivered"]);
}

static void runStream(NSDictionary<NSString *, id> *vector) {
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSArray *kinds = PXRStreamKinds();
    check(PXRJSONEqual(kinds, expect[@"kinds"]),
          [identifier stringByAppendingString:@" kinds"]);
}

static void runCheckpoint(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSMutableSet<NSString *> *allowlist = PXRCheckpointAllowlistCreate();
    for (NSString *type in arrayValue(input[@"registered"])) {
        PXRCheckpointRegister(allowlist, type);
    }
    NSString *operation = stringValue(input[@"operation"]);
    if (operation.length == 0) {
        operation = @"roundtrip";
    }
    NSString *type = stringValue(input[@"type"]);
    id value = input[@"value"] ?: [NSNull null];
    NSError *error = nil;
    if ([operation isEqualToString:@"roundtrip"]) {
        NSString *data = PXRCheckpointMarshal(allowlist, type, value, &error);
        id decoded = PXRCheckpointUnmarshal(allowlist, data, &error);
        check(PXRJSONEqual(decoded, expect[@"value"]),
              [identifier stringByAppendingString:@" value"]);
        return;
    }
    if ([operation isEqualToString:@"marshal"]) {
        PXRCheckpointMarshal(allowlist, type, value, &error);
    } else {
        NSString *envelope = PXRJSONText(@{@"type": type, @"data": value}, nil);
        PXRCheckpointUnmarshal(allowlist, envelope, &error);
    }
    check([PXRCodeFromError(error) isEqualToString:stringValue(expect[@"errorCode"])],
          [identifier stringByAppendingString:@" errorCode"]);
}

static void runPolicy(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSMutableArray<NSDictionary *> *grants = [NSMutableArray array];
    for (NSDictionary *item in arrayValue(input[@"grants"])) {
        [grants addObject:PXRPathGrantCreate(stringValue(item[@"root"]),
                                             stringValue(item[@"access"]))];
    }
    NSError *error = nil;
    NSArray *checker = PXRPathCheckerCreate(grants, &error);
    NSDictionary *decision = PXRPathCheck(checker, stringValue(input[@"target"]),
                                          stringValue(input[@"need"]), &error);
    if ([expect[@"error"] boolValue]) {
        check(decision == nil, [identifier stringByAppendingString:@" expected error"]);
        return;
    }
    check(decision != nil && [decision[@"allowed"] boolValue] == [expect[@"allowed"] boolValue],
          [identifier stringByAppendingString:@" allowed"]);
}

static void runContext(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSMutableArray<NSDictionary *> *messages = [NSMutableArray array];
    for (NSDictionary *item in arrayValue(input[@"messages"])) {
        [messages addObject:PXRMessageCreate(stringValue(item[@"role"]),
                                             stringValue(item[@"content"]))];
    }
    if ([stringValue(input[@"operation"]) isEqualToString:@"estimate"]) {
        check(PXREstimateTokens(messages) == integerValue(expect[@"tokens"]),
              [identifier stringByAppendingString:@" tokens"]);
        return;
    }
    BOOL ok = NO;
    NSArray *output = PXRCompactContext(objectValue(input[@"budget"]), messages, &ok);
    check(ok == [expect[@"ok"] boolValue],
          [identifier stringByAppendingString:@" ok"]);
    if (!ok) {
        return;
    }
    check(PXREstimateTokens(output) == integerValue(expect[@"tokens"]),
          [identifier stringByAppendingString:@" tokens"]);
    NSMutableArray *wire = [NSMutableArray array];
    for (NSDictionary *message in output) {
        [wire addObject:PXRMessageWire(message)];
    }
    check(PXRJSONEqual(wire, expect[@"messages"]),
          [identifier stringByAppendingString:@" messages"]);
}

static void runMiddleware(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    NSString *operation = stringValue(input[@"operation"]);
    if ([operation isEqualToString:@"pii"]) {
        check([PXRPIIRedact(stringValue(input[@"text"])) isEqualToString:stringValue(expect[@"text"])],
              [identifier stringByAppendingString:@" text"]);
    } else if ([operation isEqualToString:@"pii-value"]) {
        check(PXRJSONEqual(PXRRedactValue(input[@"value"]), expect[@"value"]),
              [identifier stringByAppendingString:@" value"]);
    } else if ([operation isEqualToString:@"structured"]) {
        NSString *repair = stringValue(input[@"repairOutput"]);
        PXRRepairer repairer = repair.length > 0
            ? ^NSString *(NSString *text) { return repair; }
            : nil;
        NSDictionary *config = PXRStructuredOutputCreate(objectValue(input[@"schema"]),
                                                         integerValue(input[@"maxRepairs"]),
                                                         repairer);
        NSError *error = nil;
        NSString *output = PXRStructuredApply(config, stringValue(input[@"output"]), &error);
        if ([expect[@"ok"] boolValue]) {
            check(output != nil && [output isEqualToString:stringValue(expect[@"output"])],
                  [identifier stringByAppendingString:@" output"]);
        } else {
            check([PXRCodeFromError(error) isEqualToString:stringValue(expect[@"errorCode"])],
                  [identifier stringByAppendingString:@" errorCode"]);
        }
    } else if ([operation isEqualToString:@"call-limit"]) {
        NSMutableDictionary *limit = PXRCallLimitCreate(integerValue(input[@"modelLimit"]),
                                                        integerValue(input[@"toolLimit"]));
        NSMutableArray<NSString *> *outcomes = [NSMutableArray array];
        for (NSString *kind in arrayValue(input[@"calls"])) {
            NSError *error = nil;
            BOOL ok = [kind isEqualToString:@"model"]
                ? PXRCallLimitModel(limit, &error)
                : PXRCallLimitTool(limit, &error);
            [outcomes addObject:ok ? @"ok" : PXRCodeFromError(error)];
        }
        check(PXRJSONEqual(outcomes, expect[@"outcomes"]),
              [identifier stringByAppendingString:@" outcomes"]);
    } else if ([operation isEqualToString:@"tool-selection"]) {
        NSMutableSet *selection = PXRToolSelectionCreate(arrayValue(input[@"selected"]));
        NSMutableArray *tools = [NSMutableArray array];
        for (NSString *name in arrayValue(input[@"tools"])) {
            [tools addObject:PXRToolSpecCreate(name, @"")];
        }
        NSArray *advertised = PXRSelectTools(selection, tools);
        NSMutableArray *names = [NSMutableArray array];
        for (NSDictionary *tool in advertised) {
            [names addObject:stringValue(tool[@"name"])];
        }
        check(PXRJSONEqual(names, expect[@"advertised"]),
              [identifier stringByAppendingString:@" advertised"]);
        NSError *error = nil;
        BOOL ok = PXRCheckToolSelected(selection, stringValue(input[@"requested"]), &error);
        check([(ok ? @"ok" : PXRCodeFromError(error)) isEqualToString:stringValue(expect[@"reject"])],
              [identifier stringByAppendingString:@" reject"]);
    } else if ([operation isEqualToString:@"fallback"]) {
        NSString *content = stringValue(input[@"fallbackContent"]);
        PXRModelGenerate model = PXRModelCreateFallback(PXRModelCreateFailing(),
                                                        PXRModelCreateStatic(content));
        NSDictionary *response = nil;
        model(PXRRequestCreate(@[], @[]), &response, nil);
        check([stringValue(response[@"message"][@"content"]) isEqualToString:content],
              [identifier stringByAppendingString:@" output"]);
    }
}

static void runAgentLoop(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = objectValue(vector[@"input"]);
    NSDictionary *expect = objectValue(vector[@"expect"]);
    NSString *identifier = stringValue(vector[@"id"]);
    __block NSUInteger invocations = 0;
    NSMutableArray<NSDictionary *> *tools = [NSMutableArray array];
    for (NSDictionary *item in arrayValue(input[@"tools"])) {
        [tools addObject:PXRToolCreate(stringValue(item[@"name"]),
                                       stringValue(item[@"description"]),
                                       ^id(NSDictionary *arguments, NSError **error) {
            invocations++;
            return arguments;
        })];
    }
    NSMutableArray<NSDictionary *> *script = [NSMutableArray array];
    for (NSDictionary *item in arrayValue(input[@"script"])) {
        NSMutableArray<NSDictionary *> *calls = [NSMutableArray array];
        for (NSDictionary *call in arrayValue(item[@"toolCalls"])) {
            [calls addObject:PXRToolCallCreate(stringValue(call[@"id"]),
                                               stringValue(call[@"name"]),
                                               objectValue(call[@"arguments"]))];
        }
        [script addObject:PXRResponseCreate(
            PXRMessageAssistant(stringValue(item[@"content"]), calls),
            PXRUsageCreate(integerValue(item[@"inputTokens"]),
                           integerValue(item[@"outputTokens"])))];
    }
    PXRModelGenerate model = PXRModelCreateScripted(script);
    NSMutableDictionary *options = PXRAgentOptionsCreate(model);
    options[@"tools"] = tools;
    options[@"maxSteps"] = input[@"maxSteps"] ?: @0;
    options[@"maxTokens"] = input[@"maxTokens"] ?: @0;
    NSMutableArray<NSString *> *eventTypes = [NSMutableArray array];
    options[@"events"] = ^(NSDictionary *event) {
        [eventTypes addObject:stringValue(event[@"type"])];
    };
    NSError *error = nil;
    NSDictionary *result = PXRAgentRun(options, PXRSessionCreate(@"s1", @[]),
                                       stringValue(input[@"prompt"]), &error);
    if ([expect[@"error"] boolValue]) {
        check(result == nil, [identifier stringByAppendingString:@" expected error"]);
        if (expect[@"errorCode"] != nil) {
            check([PXRCodeFromError(error) isEqualToString:stringValue(expect[@"errorCode"])],
                  [identifier stringByAppendingString:@" errorCode"]);
        }
    } else {
        check(result != nil, [identifier stringByAppendingString:@" expected success"]);
        check([stringValue(result[@"output"]) isEqualToString:stringValue(expect[@"output"])],
              [identifier stringByAppendingString:@" output"]);
        check(integerValue(result[@"steps"]) == integerValue(expect[@"steps"]),
              [identifier stringByAppendingString:@" steps"]);
    }
    check((NSInteger)invocations == integerValue(expect[@"toolInvocations"]),
          [identifier stringByAppendingString:@" tool invocations"]);
    id events = eventTypes.count > 0 ? eventTypes : [NSNull null];
    check(PXRJSONEqual(events, expect[@"events"]),
          [identifier stringByAppendingString:@" events"]);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *spec = argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"../../spec";
        NSArray<NSString *> *groups = @[
            @"toolcall", @"jsonschema", @"plugin", @"memory", @"event",
            @"stream", @"checkpoint", @"policy", @"context", @"middleware",
            @"agent-loop"
        ];
        for (NSString *group in groups) {
            NSDictionary *file = loadJSON([spec stringByAppendingPathComponent:
                [NSString stringWithFormat:@"vectors/%@.json", group]]);
            if (file == nil) {
                return 1;
            }
            for (NSDictionary *vector in vectors(file)) {
                if ([group isEqualToString:@"toolcall"]) {
                    runToolCall(vector);
                } else if ([group isEqualToString:@"jsonschema"]) {
                    runSchema(vector);
                } else if ([group isEqualToString:@"plugin"]) {
                    runPlugin(vector);
                } else if ([group isEqualToString:@"memory"]) {
                    runMemory(vector);
                } else if ([group isEqualToString:@"event"]) {
                    runEvent(vector);
                } else if ([group isEqualToString:@"stream"]) {
                    runStream(vector);
                } else if ([group isEqualToString:@"checkpoint"]) {
                    runCheckpoint(vector);
                } else if ([group isEqualToString:@"policy"]) {
                    runPolicy(vector);
                } else if ([group isEqualToString:@"context"]) {
                    runContext(vector);
                } else if ([group isEqualToString:@"middleware"]) {
                    runMiddleware(vector);
                } else if ([group isEqualToString:@"agent-loop"]) {
                    runAgentLoop(vector);
                }
            }
        }
        runCorrelationTests(check);
        runMiddlewareIntegrationTests(check);
        NSArray *relativeChecker = PXRPathCheckerCreate(@[PXRPathGrantCreate(@"allowed", @"read")], nil);
        check(!PXRPathAllowed(relativeChecker, @"../allowed/secret", @"read"),
              @"relative target outside root");
        check(!PXRPathAllowed(relativeChecker, @"a/../../allowed/secret", @"read"),
              @"relative target with unmatched parent outside root");
        check(PXRPathAllowed(relativeChecker, @"a/../allowed/secret", @"read"),
              @"relative target with canceled component inside root");
        NSArray *parentChecker = PXRPathCheckerCreate(@[PXRPathGrantCreate(@"../../allowed", @"read")], nil);
        check(PXRPathAllowed(parentChecker, @"../../allowed/secret", @"read"),
              @"relative root retains consecutive parents");
        check(!PXRPathAllowed(parentChecker, @"../allowed/secret", @"read"),
              @"relative root distinguishes parent depth");
        NSArray *absoluteChecker = PXRPathCheckerCreate(@[PXRPathGrantCreate(@"/allowed", @"read")], nil);
        check(PXRPathAllowed(absoluteChecker, @"/../../allowed/secret", @"read"),
              @"absolute target clamps parents at root");
        id value = nil;
        NSError *error = nil;
        check(!PXRParseJSONText(@"{\"a\":1}\n{}", &value, &error),
              @"trailing JSON must be rejected");
        check(!PXRParseJSONText(@"{\"a\":1,\"a\":2}", &value, &error),
              @"duplicate JSON keys must be rejected");
        printf("%s: %lu checks, %lu failures\n",
               failures == 0 ? "ok" : "failed",
               (unsigned long)checks, (unsigned long)failures);
    }
    return failures == 0 ? 0 : 1;
}
