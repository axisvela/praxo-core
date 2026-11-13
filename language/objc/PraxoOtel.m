#import "PraxoOtel.h"

#import "PraxoJSON.h"

static NSString *PXROtelString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *PXROtelBounded(NSString *text, NSUInteger limit) {
    return text.length > limit ? [text substringToIndex:limit] : text;
}

static NSString *PXROtelCanonicalJSON(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *object = value;
        NSArray *keys = [[object allKeys] sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (id key in keys) {
            if (![key isKindOfClass:[NSString class]]) {
                continue;
            }
            NSString *encodedKey = PXRJSONText(key, nil) ?: @"\"\"";
            NSString *encodedValue = PXROtelCanonicalJSON(object[key]);
            [parts addObject:[NSString stringWithFormat:@"%@:%@", encodedKey, encodedValue]];
        }
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            [parts addObject:PXROtelCanonicalJSON(item)];
        }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
    }
    return PXRJSONText(value, nil) ?: @"null";
}

static NSString *PXROtelText(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    if (value == nil || value == [NSNull null]) {
        return @"";
    }
    return PXRJSONText(value, nil) ?: @"";
}

static NSString *PXROtelStableID(NSString *text) {
    uint64_t hash = 0xcbf29ce484222325ULL;
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    const uint8_t *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        hash ^= (uint64_t)bytes[index];
        hash *= 0x100000001b3ULL;
    }
    return [NSString stringWithFormat:@"%016llx", (unsigned long long)hash];
}

static NSDictionary<NSString *, id> *PXROtelAttribute(NSString *key, NSString *value) {
    return @{@"key": key, @"value": @{@"stringValue": value ?: @""}};
}

NSDictionary<NSString *, id> *PXROtelPayload(
    NSDictionary<NSString *, id> *event,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    long long nanoseconds) {
    NSString *stamp = [NSString stringWithFormat:@"%lld", nanoseconds];
    NSString *type = PXROtelString(event[@"type"]);
    NSString *sessionId = PXROtelString(event[@"sessionId"]);
    NSString *runId = PXROtelString(event[@"runId"]);
    id data = event[@"data"];
    NSString *dataText = data != nil ? PXROtelCanonicalJSON(data) : @"";
    NSString *key = [@[sessionId, runId, type, stamp, dataText]
        componentsJoinedByString:@"|"];
    NSString *traceId = [PXROtelStableID([@"trace-a:" stringByAppendingString:key])
        stringByAppendingString:PXROtelStableID([@"trace-b:" stringByAppendingString:key])];
    NSString *spanId = PXROtelStableID([@"span:" stringByAppendingString:key]);

    NSMutableArray<NSDictionary<NSString *, id> *> *attributes = [NSMutableArray array];
    [attributes addObject:PXROtelAttribute(@"praxo.event.type", type)];
    if (sessionId.length > 0) {
        [attributes addObject:PXROtelAttribute(@"praxo.session.id", sessionId)];
    }
    if (runId.length > 0) {
        [attributes addObject:PXROtelAttribute(@"praxo.run.id", runId)];
    }
    [attributes addObject:PXROtelAttribute(@"praxo.event.at", stamp)];
    if ([data isKindOfClass:[NSDictionary class]]) {
        NSDictionary *fields = data;
        for (NSString *name in allowedDataKeys) {
            if (fields[name] == nil) {
                continue;
            }
            [attributes addObject:PXROtelAttribute(
                [@"praxo.event.data." stringByAppendingString:name],
                PXROtelText(fields[name]))];
        }
    }

    NSString *service = serviceName.length > 0 ? serviceName : @"praxo-core";
    NSDictionary<NSString *, id> *span = @{
        @"traceId": traceId,
        @"spanId": spanId,
        @"name": [@"praxo." stringByAppendingString:type],
        @"kind": @1,
        @"startTimeUnixNano": stamp,
        @"endTimeUnixNano": stamp,
        @"attributes": attributes,
    };
    return @{
        @"resourceSpans": @[
            @{
                @"resource": @{
                    @"attributes": @[PXROtelAttribute(@"service.name", service)],
                },
                @"scopeSpans": @[
                    @{
                        @"scope": @{@"name": @"praxo-core"},
                        @"spans": @[span],
                    },
                ],
            },
        ],
    };
}

static NSDictionary<NSString *, id> *PXROtelDefaultTransport(
    NSString *method,
    NSString *url,
    NSDictionary<NSString *, NSString *> *headers,
    NSData *body,
    NSError **error) {
    NSURL *target = [NSURL URLWithString:url];
    if (target == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"OTEL_HTTP", @"otel: invalid URL");
        }
        return nil;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:target];
    request.HTTPMethod = method;
    request.timeoutInterval = 30;
    for (NSString *name in headers) {
        [request setValue:headers[name] forHTTPHeaderField:name];
    }
    request.HTTPBody = body;
    NSURLResponse *urlResponse = nil;
    NSError *connectionError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&urlResponse
                                                     error:&connectionError];
    if (data == nil) {
        if (error != NULL) {
            *error = connectionError ?: PXRCoreError(@"OTEL_HTTP",
                                                     @"otel: request failed");
        }
        return nil;
    }
    NSInteger status = [urlResponse isKindOfClass:[NSHTTPURLResponse class]]
        ? [(NSHTTPURLResponse *)urlResponse statusCode] : 200;
    NSString *text = [[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding] ?: @"";
    return @{@"status": @(status), @"body": text};
}

BOOL PXROtelSend(
    NSString *endpoint,
    NSDictionary<NSString *, id> *event,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    PXROtelTransport transport,
    PXROtelClock clock,
    NSError **error) {
    NSString *target = [endpoint stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (target.length == 0) {
        if (error != NULL) {
            *error = PXRCoreError(@"OTEL_URL", @"otel: endpoint is required");
        }
        return NO;
    }
    long long nanos = 0;
    if (clock != nil) {
        nanos = clock();
    }
    if (nanos <= 0) {
        nanos = (long long)llround([[NSDate date] timeIntervalSince1970] * 1000000000.0);
    }
    NSDictionary *payload = PXROtelPayload(event, serviceName, allowedDataKeys, nanos);
    NSString *raw = PXRJSONText(payload, nil);
    if (raw == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"OTEL_JSON", @"otel: cannot encode payload");
        }
        return NO;
    }
    NSDictionary<NSString *, NSString *> *headers = @{@"content-type": @"application/json"};
    NSData *body = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *response = transport != nil
        ? transport(@"POST", target, headers, body, error)
        : PXROtelDefaultTransport(@"POST", target, headers, body, error);
    if (response == nil) {
        if (error != NULL && *error == nil) {
            *error = PXRCoreError(@"OTEL_HTTP", @"otel: request failed");
        }
        return NO;
    }
    NSInteger status = [response[@"status"] respondsToSelector:@selector(integerValue)]
        ? [response[@"status"] integerValue] : 0;
    if (status >= 200 && status < 300) {
        return YES;
    }
    NSString *text = PXROtelString(response[@"body"]);
    if (error != NULL) {
        *error = PXRCoreError(
            @"OTEL_HTTP",
            [NSString stringWithFormat:@"otel: HTTP %ld: %@",
                                       (long)status,
                                       PXROtelBounded(text, 512)]);
    }
    return NO;
}

PXREventSink PXROtelSink(
    NSString *endpoint,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    PXROtelTransport transport,
    PXROtelClock clock) {
    return ^(NSDictionary<NSString *, id> *event) {
        PXROtelSend(endpoint, event, serviceName, allowedDataKeys, transport, clock, NULL);
    };
}
