#import "PraxoCore.h"

NSString *const PXRCoreErrorDomain = @"io.axisvela.praxo.core";
NSString *const PXRCodeKey = @"io.axisvela.praxo.code";

NSError *PXRCoreError(NSString *code, NSString *message) {
    return [NSError errorWithDomain:PXRCoreErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message,
                                      PXRCodeKey: code}];
}

NSString *PXRCodeFromError(NSError *error) {
    if (error == nil) {
        return @"";
    }
    id code = error.userInfo[PXRCodeKey];
    return [code isKindOfClass:[NSString class]] ? code : @"";
}

static NSArray *PXRArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSDictionary *PXRObject(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static NSString *PXRString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSInteger PXRInteger(id value) {
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

static NSInteger PXRByteLength(NSString *text) {
    return (NSInteger)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

NSDictionary<NSString *, id> *PXRMessageCreate(NSString *role, NSString *content) {
    return [@{@"role": role ?: @"",
              @"content": content ?: @""} mutableCopy];
}

NSDictionary<NSString *, id> *PXRMessageAssistant(
    NSString *content, NSArray<NSDictionary<NSString *, id> *> *toolCalls) {
    NSMutableDictionary *message = [PXRMessageCreate(@"assistant", content) mutableCopy];
    if (toolCalls.count > 0) {
        message[@"toolCalls"] = toolCalls;
    }
    return message;
}

NSDictionary<NSString *, id> *PXRMessageTool(NSString *content, NSString *toolId) {
    NSMutableDictionary *message = [PXRMessageCreate(@"tool", content) mutableCopy];
    if (toolId != nil) {
        message[@"toolId"] = toolId;
    }
    return message;
}

NSDictionary<NSString *, id> *PXRToolCallCreate(NSString *identifier,
                                                NSString *name,
                                                NSDictionary<NSString *, id> *arguments) {
    return @{@"id": identifier ?: @"",
             @"name": name ?: @"",
             @"arguments": arguments ?: @{}};
}

NSDictionary<NSString *, id> *PXRToolSpecCreate(NSString *name, NSString *description) {
    return @{@"name": name ?: @"",
             @"description": description ?: @""};
}

NSDictionary<NSString *, id> *PXRUsageCreate(NSInteger inputTokens, NSInteger outputTokens) {
    return @{@"inputTokens": @(inputTokens),
             @"outputTokens": @(outputTokens)};
}

NSDictionary<NSString *, id> *PXRUsageAdd(NSDictionary<NSString *, id> *left,
                                          NSDictionary<NSString *, id> *right) {
    return PXRUsageCreate(PXRInteger(left[@"inputTokens"]) + PXRInteger(right[@"inputTokens"]),
                          PXRInteger(left[@"outputTokens"]) + PXRInteger(right[@"outputTokens"]));
}

NSDictionary<NSString *, id> *PXRRequestCreate(
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools) {
    return @{@"messages": messages ?: @[],
             @"tools": tools ?: @[]};
}

NSDictionary<NSString *, id> *PXRResponseCreate(NSDictionary<NSString *, id> *message,
                                                NSDictionary<NSString *, id> *usage) {
    return @{@"message": message ?: @{},
             @"usage": usage ?: PXRUsageCreate(0, 0)};
}

NSDictionary<NSString *, id> *PXRSessionCreate(
    NSString *identifier, NSArray<NSDictionary<NSString *, id> *> *messages) {
    return @{@"id": identifier ?: @"",
             @"messages": messages ?: @[]};
}

NSDictionary<NSString *, id> *PXRRunResultCreate(NSString *runId,
                                                 NSString *output,
                                                 NSInteger steps,
                                                 NSDictionary<NSString *, id> *usage) {
    return @{@"runId": runId ?: @"",
             @"output": output ?: @"",
             @"steps": @(steps),
             @"usage": usage ?: PXRUsageCreate(0, 0)};
}

NSDictionary<NSString *, id> *PXRMemoryRecordCreate(NSString *identifier,
                                                    NSString *frame,
                                                    NSString *content,
                                                    NSString *createdAt) {
    return @{@"id": identifier ?: @"",
             @"frame": frame ?: @"",
             @"content": content ?: @"",
             @"createdAt": createdAt ?: @""};
}

NSDictionary<NSString *, id> *PXRPathGrantCreate(NSString *root, NSString *access) {
    return @{@"root": root ?: @"",
             @"access": access ?: @"read"};
}

NSDictionary<NSString *, id> *PXRDecisionCreate(BOOL allowed, NSString *reason) {
    return @{@"allowed": @(allowed),
             @"reason": reason ?: @""};
}

NSDictionary<NSString *, id> *PXREventCreate(NSString *type,
                                             NSString *sessionId,
                                             NSString *runId,
                                             id data) {
    NSMutableDictionary *event = [@{@"type": type ?: @"",
                                    @"sessionId": sessionId ?: @""} mutableCopy];
    if (runId != nil) {
        event[@"runId"] = runId;
    }
    if (data != nil) {
        event[@"data"] = data;
    }
    return event;
}

NSDictionary<NSString *, id> *PXRContextBudgetCreate(NSInteger maxTokens, NSInteger keepRecent) {
    return @{@"maxTokens": @(maxTokens),
             @"keepRecent": @(keepRecent)};
}

NSDictionary<NSString *, id> *PXRMessageWire(NSDictionary<NSString *, id> *message) {
    NSMutableDictionary *output = [NSMutableDictionary dictionary];
    output[@"role"] = PXRString(message[@"role"]);
    NSString *content = PXRString(message[@"content"]);
    NSArray *blocks = PXRArray(message[@"contentBlocks"]);
    NSArray *calls = PXRArray(message[@"toolCalls"]);
    NSString *toolId = message[@"toolId"];
    if (content.length > 0 || (blocks.count == 0 && calls.count == 0 && toolId == nil)) {
        output[@"content"] = content;
    }
    if (blocks.count > 0) {
        NSMutableArray *wireBlocks = [NSMutableArray array];
        for (NSDictionary *block in blocks) {
            NSMutableDictionary *wire = [NSMutableDictionary dictionary];
            wire[@"type"] = PXRString(block[@"type"]);
            if ([block[@"text"] isKindOfClass:[NSString class]]) {
                wire[@"text"] = block[@"text"];
            }
            if ([block[@"image_url"] isKindOfClass:[NSString class]]) {
                wire[@"image_url"] = block[@"image_url"];
            }
            if ([block[@"data"] isKindOfClass:[NSString class]]) {
                wire[@"data"] = block[@"data"];
            }
            [wireBlocks addObject:wire];
        }
        output[@"contentBlocks"] = wireBlocks;
    }
    if (calls.count > 0) {
        NSMutableArray *wireCalls = [NSMutableArray array];
        for (NSDictionary *call in calls) {
            [wireCalls addObject:@{@"id": PXRString(call[@"id"]),
                                   @"name": PXRString(call[@"name"]),
                                   @"arguments": call[@"arguments"] ?: @{}}];
        }
        output[@"toolCalls"] = wireCalls;
    }
    if ([toolId isKindOfClass:[NSString class]]) {
        output[@"toolId"] = toolId;
    }
    return output;
}

NSArray<NSString *> *PXRStreamKinds(void) {
    return @[@"values", @"updates", @"messages", @"tasks", @"debug", @"checkpoint"];
}

PXREventSink PXRMultiSink(NSArray<PXREventSink> *sinks) {
    NSArray<PXREventSink> *copy = [sinks copy];
    return ^(NSDictionary<NSString *, id> *event) {
        for (PXREventSink sink in copy) {
            sink(event);
        }
    };
}

PXREventSink PXRFilterSink(PXREventSink target, NSArray<NSString *> *predicateTypes) {
    NSArray<NSString *> *types = [predicateTypes copy];
    return ^(NSDictionary<NSString *, id> *event) {
        if (types.count == 0 ||
            [types indexOfObject:PXRString(event[@"type"])] != NSNotFound) {
            target(event);
        }
    };
}

void PXREmit(PXREventSink sink, NSDictionary<NSString *, id> *event) {
    if (sink != nil) {
        sink(event);
    }
}

NSMutableDictionary<NSString *, id> *PXRMemoryStoreCreate(void) {
    return [@{@"records": [NSMutableDictionary dictionary],
              @"sequence": @0} mutableCopy];
}

void PXRMemoryPut(NSMutableDictionary<NSString *, id> *store,
                  NSString *sessionId,
                  NSDictionary<NSString *, id> *record) {
    NSMutableDictionary *recordValue = [record mutableCopy];
    if (PXRString(recordValue[@"id"]).length == 0) {
        NSInteger sequence = PXRInteger(store[@"sequence"]);
        recordValue[@"id"] = [NSString stringWithFormat:@"mem-%lld-%ld",
                              (long long)[NSDate date].timeIntervalSince1970,
                              (long)sequence];
        store[@"sequence"] = @(sequence + 1);
    }
    if (PXRString(recordValue[@"createdAt"]).length == 0) {
        recordValue[@"createdAt"] = [NSString stringWithFormat:@"%lld",
                                     (long long)[NSDate date].timeIntervalSince1970];
    }
    NSMutableDictionary *records = store[@"records"];
    NSMutableArray *session = records[sessionId ?: @""];
    if (session == nil) {
        session = [NSMutableArray array];
        records[sessionId ?: @""] = session;
    }
    [session addObject:recordValue];
}

NSArray<NSDictionary<NSString *, id> *> *PXRMemorySearch(NSMutableDictionary<NSString *, id> *store,
                                                         NSString *sessionId,
                                                         NSString *query,
                                                         NSInteger limit) {
    NSMutableDictionary *records = store[@"records"];
    NSArray *session = records[sessionId ?: @""];
    if (session == nil) {
        return @[];
    }
    NSString *needle = [[query ?: @"" stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSMutableArray *matches = [NSMutableArray array];
    for (NSDictionary *record in session) {
        NSString *content = PXRString(record[@"content"]);
        if (needle.length == 0 ||
            [[content lowercaseString] rangeOfString:needle].location != NSNotFound) {
            [matches addObject:record];
        }
    }
    [matches sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [PXRString(b[@"createdAt"]) compare:PXRString(a[@"createdAt"])];
    }];
    if (limit > 0 && (NSUInteger)limit < matches.count) {
        return [matches subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)];
    }
    return matches;
}

NSMutableSet<NSString *> *PXRCheckpointAllowlistCreate(void) {
    return [NSMutableSet set];
}

void PXRCheckpointRegister(NSMutableSet<NSString *> *allowlist, NSString *type) {
    if (type.length > 0) {
        [allowlist addObject:type];
    }
}

NSString *PXRCheckpointMarshal(NSMutableSet<NSString *> *allowlist,
                               NSString *type,
                               id value,
                               NSError **error) {
    if ([allowlist member:(type ?: @"")] == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"CHECKPOINT_TYPE_NOT_ALLOWED",
                                  @"checkpoint: payload type not allowed");
        }
        return nil;
    }
    return PXRJSONText(@{@"type": type ?: @"",
                         @"data": value ?: [NSNull null]}, error);
}

id PXRCheckpointUnmarshal(NSMutableSet<NSString *> *allowlist,
                          NSString *data,
                          NSError **error) {
    id envelope = nil;
    if (!PXRParseJSONText(data, &envelope, error) ||
        ![envelope isKindOfClass:[NSDictionary class]]) {
        if (error != NULL && *error == nil) {
            *error = PXRCoreError(@"CHECKPOINT_ERROR", @"checkpoint: invalid envelope");
        }
        return nil;
    }
    NSString *type = PXRString(envelope[@"type"]);
    if ([allowlist member:type] == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"CHECKPOINT_TYPE_NOT_ALLOWED",
                                  @"checkpoint: payload type not allowed");
        }
        return nil;
    }
    id value = envelope[@"data"];
    return value ?: [NSNull null];
}

static NSString *PXRNormalizePath(NSString *value) {
    NSString *path = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    NSString *prefix = @"";
    if (path.length >= 2 && [path characterAtIndex:1] == ':') {
        prefix = [path substringToIndex:2];
        path = [path substringFromIndex:2];
    } else if (PXRStringHasPrefix(path, @"/")) {
        prefix = @"/";
    }
    BOOL absolute = PXRStringHasPrefix(path, @"/");
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if (part.length == 0 || [part isEqualToString:@"."]) {
            continue;
        }
        if ([part isEqualToString:@".."]) {
            if (parts.count > 0 && ![[parts lastObject] isEqualToString:@".."]) {
                [parts removeLastObject];
            } else if (!absolute) {
                [parts addObject:part];
            }
            continue;
        }
        [parts addObject:part];
    }
    NSString *result = [prefix stringByAppendingString:[parts componentsJoinedByString:@"/"]];

#if defined(_WIN32)
    result = [result lowercaseString];
#endif
    return result;
}

static BOOL PXRPathWithin(NSString *root, NSString *target) {
    if ([root isEqualToString:target]) {
        return YES;
    }
    return PXRStringHasPrefix(target, [root stringByAppendingString:@"/"]);
}

static BOOL PXRAccessAllows(NSString *grant, NSString *need) {
    if ([need isEqualToString:@"read"]) {
        return [grant isEqualToString:@"read"] || [grant isEqualToString:@"readwrite"];
    }
    if ([need isEqualToString:@"write"]) {
        return [grant isEqualToString:@"write"] || [grant isEqualToString:@"readwrite"];
    }
    return [grant isEqualToString:@"readwrite"];
}

NSArray<NSDictionary<NSString *, id> *> *PXRPathCheckerCreate(
    NSArray<NSDictionary<NSString *, id> *> *grants, NSError **error) {
    NSMutableArray *normalized = [NSMutableArray array];
    for (NSDictionary *grant in grants) {
        NSString *root = PXRString(grant[@"root"]);
        NSString *access = PXRString(grant[@"access"]);
        if (root.length == 0) {
            if (error != NULL) {
                *error = PXRCoreError(@"POLICY_ERROR", @"policy: path grant root is required");
            }
            return nil;
        }
        if ([@[@"read", @"write", @"readwrite"] indexOfObject:access] == NSNotFound) {
            if (error != NULL) {
                *error = PXRCoreError(@"POLICY_ERROR", @"policy: invalid grant access");
            }
            return nil;
        }
        [normalized addObject:PXRPathGrantCreate(PXRNormalizePath(root), access)];
    }
    return normalized;
}

NSDictionary<NSString *, id> *PXRPathCheck(
    NSArray<NSDictionary<NSString *, id> *> *checker,
    NSString *target,
    NSString *need,
    NSError **error) {
    if ([@[@"read", @"write", @"readwrite"] indexOfObject:(need ?: @"")] == NSNotFound) {
        if (error != NULL) {
            *error = PXRCoreError(@"POLICY_ERROR", @"policy: invalid requested access");
        }
        return nil;
    }
    if (checker.count == 0) {
        return PXRDecisionCreate(NO, @"no allowed roots");
    }
    NSString *resolved = PXRNormalizePath(target);
    BOOL matched = NO;
    for (NSDictionary *grant in checker) {
        NSString *root = PXRString(grant[@"root"]);
        if (PXRPathWithin(root, resolved)) {
            matched = YES;
            if (PXRAccessAllows(PXRString(grant[@"access"]), need)) {
                return PXRDecisionCreate(YES, @"allowed");
            }
        }
    }
    return PXRDecisionCreate(NO, matched ? @"insufficient grant" : @"outside roots");
}

BOOL PXRPathAllowed(NSArray<NSDictionary<NSString *, id> *> *checker,
                    NSString *target,
                    NSString *need) {
    NSError *error = nil;
    NSDictionary *decision = PXRPathCheck(checker, target, need, &error);
    return decision != nil && [decision[@"allowed"] boolValue];
}

NSInteger PXREstimateTokens(NSArray<NSDictionary<NSString *, id> *> *messages) {
    NSInteger total = 0;
    for (NSDictionary *message in messages) {
        total += 4 + PXRByteLength(PXRString(message[@"content"])) / 4;
        total += PXRByteLength(PXRString(message[@"toolId"])) / 4;
        for (NSDictionary *block in PXRArray(message[@"contentBlocks"])) {
            total += 4 + PXRByteLength(PXRString(block[@"text"])) / 4;
        }
        for (NSDictionary *call in PXRArray(message[@"toolCalls"])) {
            NSString *arguments = PXRJSONText(call[@"arguments"] ?: @{}, NULL) ?: @"";
            total += 4 + PXRByteLength(PXRString(call[@"name"])) / 4;
            total += PXRByteLength(arguments) / 4;
        }
    }
    return total;
}

static NSString *PXRTruncateToTokens(NSString *value, NSInteger tokens) {
    if (tokens <= 0) {
        return @"";
    }
    NSInteger limit = tokens * 4;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if ((NSInteger)data.length <= limit) {
        return value;
    }
    NSString *prefix = [[NSString alloc] initWithData:[data subdataWithRange:
        NSMakeRange(0, (NSUInteger)limit)] encoding:NSUTF8StringEncoding];
    if (prefix == nil) {
        prefix = [value substringToIndex:MIN(value.length, (NSUInteger)limit)];
    }
    if (limit <= 16) {
        return prefix;
    }
    return [prefix stringByAppendingString:@"\n[truncated]"];
}

static NSArray *PXRBuildContext(NSArray *system, NSArray *kept,
                                NSDictionary *marker, NSInteger start) {
    NSMutableArray *output = [NSMutableArray arrayWithArray:system];
    if (start > 0) {
        [output addObject:marker];
    }
    [output addObjectsFromArray:kept];
    return output;
}

NSArray<NSDictionary<NSString *, id> *> *PXRCompactContext(
    NSDictionary<NSString *, id> *budget,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    BOOL *ok) {
    NSInteger maxTokens = PXRInteger(budget[@"maxTokens"]);
    if (maxTokens <= 0 || PXREstimateTokens(messages) <= maxTokens) {
        if (ok != NULL) {
            *ok = YES;
        }
        return messages;
    }
    NSMutableArray *system = [NSMutableArray array];
    NSMutableArray *rest = [NSMutableArray array];
    for (NSDictionary *message in messages) {
        if ([PXRString(message[@"role"]) isEqualToString:@"system"]) {
            if (!PXRStringHasPrefix(PXRString(message[@"content"]), @"[context compacted:")) {
                [system addObject:message];
            }
        } else {
            [rest addObject:message];
        }
    }
    if (PXREstimateTokens(system) > maxTokens) {
        if (system.count == 0) {
            if (ok != NULL) {
                *ok = NO;
            }
            return @[];
        }
        NSMutableDictionary *first = [system[0] mutableCopy];
        first[@"content"] = PXRTruncateToTokens(PXRString(first[@"content"]), maxTokens - 4);
        system = [@[first] mutableCopy];
        if (PXREstimateTokens(system) > maxTokens) {
            if (ok != NULL) {
                *ok = NO;
            }
            return @[];
        }
    }
    NSInteger keep = PXRInteger(budget[@"keepRecent"]);
    if (keep <= 0) {
        keep = 4;
    }
    NSInteger start = MAX(0, (NSInteger)rest.count - keep);
    while (start > 0 && [PXRString(rest[(NSUInteger)start][@"role"]) isEqualToString:@"tool"]) {
        start--;
    }
    NSDictionary *marker = PXRMessageCreate(@"system",
        [NSString stringWithFormat:@"[context compacted: %ld older messages omitted]", (long)start]);
    NSArray *kept = start >= (NSInteger)rest.count
        ? @[]
        : [rest subarrayWithRange:NSMakeRange((NSUInteger)start, rest.count - (NSUInteger)start)];
    NSArray *output = PXRBuildContext(system, kept, marker, start);
    while (PXREstimateTokens(output) > maxTokens && kept.count > 1) {
        if ([PXRString(kept[1][@"role"]) isEqualToString:@"tool"]) {
            break;
        }
        kept = [kept subarrayWithRange:NSMakeRange(1, kept.count - 1)];
        output = PXRBuildContext(system, kept, marker, start);
    }
    if (ok != NULL) {
        *ok = PXREstimateTokens(output) <= maxTokens;
    }
    return output;
}
