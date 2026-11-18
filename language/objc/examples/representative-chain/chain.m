#import <Foundation/Foundation.h>
#import "PraxoCore.h"
#import "PraxoMCP.h"
#import "PraxoOtel.h"
#import "PraxoHarmovela.h"

@interface FakeMcpTransport : NSObject <PXRMcpTransport>
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *effects;
@end

@implementation FakeMcpTransport

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _effects = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                          params:(NSDictionary<NSString *, id> *)params
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError **)error {
    (void)timeout;
    (void)error;
    if ([method isEqualToString:@"initialize"]) {
        return @{@"protocolVersion": @"2024-11-05",
                 @"serverInfo": @{@"name": @"fake-mcp"}};
    }
    if ([method isEqualToString:@"tools/list"]) {
        return @{@"tools": @[
            @{@"name": @"record",
              @"description": @"Record a target",
              @"inputSchema": @{@"type": @"object",
                                @"properties": @{@"target": @{@"type": @"string"}},
                                @"required": @[@"target"]}}
        ]};
    }
    if ([method isEqualToString:@"tools/call"]) {
        NSDictionary *arguments = params[@"arguments"] ?: @{};
        NSString *target = [arguments[@"target"] isKindOfClass:[NSString class]]
            ? arguments[@"target"] : @"";
        self.effects[target] = @([self.effects[target] integerValue] + 1);
        return @{@"content": @[
            @{@"type": @"text", @"text": [@"recorded:" stringByAppendingString:target]}
        ]};
    }
    return @{};
}

- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error {
    (void)method;
    (void)params;
    (void)error;
    return YES;
}

- (void)close {}

@end

static NSDictionary<NSString *, id> *RecordCall(NSString *identifier, NSString *target) {
    return PXRToolCallCreate(identifier, @"record", @{@"target": target});
}

static NSDictionary<NSString *, id> *ToolResponse(NSDictionary<NSString *, id> *call) {
    return PXRResponseCreate(PXRMessageAssistant(@"", @[call]), PXRUsageCreate(0, 0));
}

int main(void) {
    @autoreleasepool {
        FakeMcpTransport *transport = [[FakeMcpTransport alloc] init];
        PXRMcpClient *client = [[PXRMcpClient alloc] initWithTransport:transport
                                                       protocolVersion:@"2024-11-05"
                                                         clientVersion:@"0.0.0"
                                                               timeout:5];
        NSError *error = nil;
        if (![client start:&error]) {
            fprintf(stderr, "mcp start failed\n");
            return 1;
        }
        NSArray *mcpTools = [client listTools:&error];
        if (mcpTools.count != 1) {
            fprintf(stderr, "unexpected mcp tools\n");
            return 1;
        }

        __block NSInteger otelCount = 0;
        __block NSInteger harmCount = 0;
        __block NSInteger childCalls = 0;
        __block NSInteger parentCalls = 0;

        PXROtelTransport otelTransport = ^NSDictionary<NSString *, id> *(NSString *method,
                                                                          NSString *url,
                                                                          NSDictionary<NSString *, NSString *> *headers,
                                                                          NSData *body,
                                                                          NSError **transportError) {
            (void)method;
            (void)url;
            (void)headers;
            (void)transportError;
            NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            id payload = nil;
            if (text != nil) PXRParseJSONText(text, &payload, NULL);
            if ([payload isKindOfClass:[NSDictionary class]]) {
                NSArray *resources = payload[@"resourceSpans"] ?: @[];
                for (NSDictionary *resource in resources) {
                    for (NSDictionary *scope in resource[@"scopeSpans"] ?: @[]) {
                        otelCount += [scope[@"spans"] count];
                    }
                }
            }
            return @{@"status": @200, @"body": @""};
        };
        PXRHarmovelaTransport harmTransport = ^NSDictionary<NSString *, id> *(NSString *method,
                                                                              NSString *url,
                                                                              NSDictionary<NSString *, id> *headers,
                                                                              NSData *body,
                                                                              NSError **transportError) {
            (void)method;
            (void)url;
            (void)headers;
            (void)transportError;
            NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            id payload = nil;
            if (text != nil) PXRParseJSONText(text, &payload, NULL);
            if ([payload isKindOfClass:[NSDictionary class]]) {
                harmCount += 1;
            }
            return @{@"status": @202, @"body": @""};
        };
        PXREventSink events = PXRMultiSink(@[
            PXROtelSink(@"http://otel.local/v1/traces", @"praxo-core", @[],
                        otelTransport, ^long long { return 1794294000000000000LL; }),
            PXRHarmovelaSink(@"http://harmovela.local", @"praxo-core", @"0.2",
                             harmTransport, ^NSDate * { return [NSDate dateWithTimeIntervalSince1970:1794294000]; })
        ]);

        PXRToolInvoke record = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
            return [client callTool:@"record" arguments:arguments error:toolError];
        };

        PXRModelGenerate childModel = ^BOOL(NSDictionary<NSString *, id> *request,
                                            NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                                            NSError **modelError) {
            (void)modelError;
            childCalls += 1;
            if (childCalls == 1) {
                if (response != NULL) *response = ToolResponse(RecordCall(@"child-record", @"child"));
            } else {
                if (response != NULL) {
                    *response = PXRResponseCreate(PXRMessageAssistant(@"DONE", @[]), PXRUsageCreate(0, 0));
                }
            }
            return YES;
        };

        PXRToolInvoke delegate = ^id(NSDictionary<NSString *, id> *arguments, NSError **toolError) {
            (void)arguments;
            NSMutableDictionary *childOptions = PXRAgentOptionsCreate(childModel);
            childOptions[@"tools"] = @[PXRToolCreate(@"record", @"record", record)];
            childOptions[@"allowedTools"] = @[@"record"];
            childOptions[@"requirePolicy"] = @YES;
            childOptions[@"requireToolScope"] = @YES;
            childOptions[@"maxSteps"] = @3;
            childOptions[@"policy"] = ^id(NSDictionary *action) {
                NSString *kind = action[@"kind"] ?: @"";
                if ([kind isEqualToString:@"model.generate"]) return PXRDecisionCreate(YES, @"");
                if ([kind isEqualToString:@"tool.invoke"] &&
                    [action[@"toolName"] isEqualToString:@"record"]) return PXRDecisionCreate(YES, @"");
                return PXRDecisionCreate(NO, @"child may only record");
            };
            NSDictionary *result = PXRAgentRun(childOptions, PXRSessionCreate(@"chain-child", @[]),
                                               @"record child", toolError);
            return result[@"output"] ?: @"";
        };

        PXRModelGenerate parentModel = ^BOOL(NSDictionary<NSString *, id> *request,
                                             NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                                             NSError **modelError) {
            (void)modelError;
            parentCalls += 1;
            if (parentCalls == 1) {
                if (response != NULL) *response = ToolResponse(RecordCall(@"parent-record", @"parent"));
            } else if (parentCalls == 2) {
                NSDictionary *call = PXRToolCallCreate(@"parent-delegate", @"delegate",
                                                       @{@"task": @"record child"});
                if (response != NULL) *response = ToolResponse(call);
            } else if (response != NULL) {
                *response = PXRResponseCreate(PXRMessageAssistant(@"DONE", @[]), PXRUsageCreate(0, 0));
            }
            return YES;
        };

        NSMutableDictionary *parentOptions = PXRAgentOptionsCreate(parentModel);
        parentOptions[@"tools"] = @[
            PXRToolCreate(@"record", @"record", record),
            PXRToolCreate(@"delegate", @"delegate", delegate)
        ];
        parentOptions[@"allowedTools"] = @[@"record", @"delegate"];
        parentOptions[@"requirePolicy"] = @YES;
        parentOptions[@"requireToolScope"] = @YES;
        parentOptions[@"maxSteps"] = @4;
        parentOptions[@"events"] = events;
        parentOptions[@"policy"] = ^id(NSDictionary *action) {
            NSString *kind = action[@"kind"] ?: @"";
            if ([kind isEqualToString:@"model.generate"]) return PXRDecisionCreate(YES, @"");
            if (![kind isEqualToString:@"tool.invoke"]) return PXRDecisionCreate(NO, @"");
            NSString *name = action[@"toolName"] ?: @"";
            if ([name isEqualToString:@"delegate"]) return PXRDecisionCreate(YES, @"");
            if ([name isEqualToString:@"record"]) {
                NSString *target = action[@"arguments"][@"target"] ?: @"";
                return PXRDecisionCreate(![target isEqualToString:@"blocked"], @"blocked target");
            }
            return PXRDecisionCreate(NO, @"parent tool is not allowed");
        };
        NSDictionary *parent = PXRAgentRun(parentOptions, PXRSessionCreate(@"chain-parent", @[]),
                                           @"record parent, then delegate", &error);
        if (parent == nil) {
            fprintf(stderr, "parent run failed: %s\n", [[error localizedDescription] UTF8String]);
            return 1;
        }

        PXRModelGenerate deniedModel = ^BOOL(NSDictionary<NSString *, id> *request,
                                             NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                                             NSError **modelError) {
            (void)request;
            (void)modelError;
            if (response != NULL) *response = ToolResponse(RecordCall(@"denied-record", @"edit-me"));
            return YES;
        };
        NSMutableDictionary *deniedOptions = PXRAgentOptionsCreate(deniedModel);
        deniedOptions[@"tools"] = @[PXRToolCreate(@"record", @"record", record)];
        deniedOptions[@"allowedTools"] = @[@"record"];
        deniedOptions[@"requirePolicy"] = @YES;
        deniedOptions[@"requireToolScope"] = @YES;
        deniedOptions[@"maxSteps"] = @2;
        deniedOptions[@"events"] = events;
        deniedOptions[@"interruptOn"] = @[@"record"];
        deniedOptions[@"onInterruptDecision"] = ^NSDictionary *(NSDictionary *interrupt) {
            (void)interrupt;
            return PXRInterruptDecisionCreate(PXRInterruptEdit, @{@"target": @"blocked"}, nil, nil);
        };
        deniedOptions[@"policy"] = parentOptions[@"policy"];
        NSError *deniedError = nil;
        (void)PXRAgentRun(deniedOptions, PXRSessionCreate(@"chain-denied", @[]),
                          @"attempt a denied edit", &deniedError);

        NSInteger parentEffect = [transport.effects[@"parent"] integerValue];
        NSInteger childEffect = [transport.effects[@"child"] integerValue];
        NSInteger blockedEffect = [transport.effects[@"blocked"] integerValue];
        printf("output: %s\n", [(parent[@"output"] ?: @"") UTF8String]);
        printf("effects: parent=%ld child=%ld\n", (long)parentEffect, (long)childEffect);
        printf("child calls: %ld\n", (long)childCalls);
        printf("otel spans: %ld\n", (long)otelCount);
        printf("harmovela events: %ld\n", (long)harmCount);
        printf("denied effects: %ld\n", (long)blockedEffect);
        if (![parent[@"output"] isEqualToString:@"DONE"]) return 1;
        if (parentEffect != 1 || childEffect != 1) return 1;
        if (childCalls != 2) return 1;
        if (otelCount < 3 || harmCount < 3) return 1;
        if (blockedEffect != 0) return 1;
        if (PXRCodeFromError(deniedError).length == 0) return 1;
    }
    return 0;
}
