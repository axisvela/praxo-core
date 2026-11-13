#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoJSON.h"
#import "PraxoOtel.h"

static NSDictionary *PXROtelTestObject(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static NSArray *PXROtelTestArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static NSDictionary *PXROtelTestDecode(NSString *body) {
    id value = nil;
    NSError *error = nil;
    if (!PXRParseJSONText(body ?: @"", &value, &error)) {
        return nil;
    }
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static BOOL PXROtelTestHex(NSString *text, NSUInteger length) {
    if (text.length != length) {
        return NO;
    }
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:
        @"0123456789abcdef"] invertedSet];
    return [text rangeOfCharacterFromSet:nonHex].location == NSNotFound;
}

static NSDictionary *PXROtelTestSpan(NSDictionary *payload) {
    NSArray *resourceSpans = PXROtelTestArray(payload[@"resourceSpans"]);
    NSDictionary *resourceSpan = resourceSpans.count > 0 ? resourceSpans[0] : @{};
    NSArray *scopeSpans = PXROtelTestArray(resourceSpan[@"scopeSpans"]);
    NSDictionary *scopeSpan = scopeSpans.count > 0 ? scopeSpans[0] : @{};
    NSArray *spans = PXROtelTestArray(scopeSpan[@"spans"]);
    return spans.count > 0 ? spans[0] : @{};
}

static NSDictionary *PXROtelTestAttributes(NSDictionary *span) {
    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
    for (NSDictionary *attribute in PXROtelTestArray(span[@"attributes"])) {
        NSString *key = attribute[@"key"];
        NSString *value = PXROtelTestObject(attribute[@"value"])[@"stringValue"];
        if ([key isKindOfClass:[NSString class]] &&
            [value isKindOfClass:[NSString class]]) {
            result[key] = value;
        }
    }
    return result;
}

void runOtelTests(void (*check)(BOOL, NSString *)) {
    __block NSMutableArray<NSDictionary<NSString *, id> *> *calls = [NSMutableArray array];
    PXROtelTransport capture = ^NSDictionary<NSString *, id> *(
        NSString *method, NSString *url, NSDictionary<NSString *, NSString *> *headers,
        NSData *body, NSError **error) {
        (void)error;
        NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        [calls addObject:@{@"method": method ?: @"",
                           @"url": url ?: @"",
                           @"headers": headers ?: @{},
                           @"body": text ?: @""}];
        return @{@"status": @(200), @"body": @""};
    };
    PXROtelClock clock = ^long long {
        return 1794294000000000000LL;
    };
    NSDictionary *event = PXREventCreate(@"tool.call", @"s1", @"run-123",
                                         @{@"name": @"echo", @"secret": @"hidden"});
    NSError *error = nil;
    BOOL ok = PXROtelSend(@"https://otel.test/v1/traces", event, @"checkout",
                          @[@"name"], capture, clock, &error);
    check(ok && error == nil, @"otel success");
    check(calls.count == 1, @"otel single request");
    NSDictionary *call = calls.firstObject;
    check([call[@"method"] isEqualToString:@"POST"], @"otel method");
    check([call[@"url"] isEqualToString:@"https://otel.test/v1/traces"], @"otel url");
    check([call[@"headers"][@"content-type"] isEqualToString:@"application/json"],
          @"otel content type");
    NSDictionary *payload = PXROtelTestDecode(call[@"body"]);
    NSArray *resourceSpans = PXROtelTestArray(payload[@"resourceSpans"]);
    NSDictionary *resourceSpan = resourceSpans.count > 0 ? resourceSpans[0] : @{};
    NSArray *resourceAttributes = PXROtelTestArray(
        PXROtelTestObject(resourceSpan[@"resource"])[@"attributes"]);
    NSString *serviceName = nil;
    for (NSDictionary *attribute in resourceAttributes) {
        if ([attribute[@"key"] isEqualToString:@"service.name"]) {
            serviceName = PXROtelTestObject(attribute[@"value"])[@"stringValue"];
        }
    }
    check([serviceName isEqualToString:@"checkout"], @"otel service name");
    NSArray *scopeSpans = PXROtelTestArray(resourceSpan[@"scopeSpans"]);
    NSDictionary *scopeSpan = scopeSpans.count > 0 ? scopeSpans[0] : @{};
    check([PXROtelTestObject(scopeSpan[@"scope"])[@"name"] isEqualToString:@"praxo-core"],
          @"otel scope name");
    NSDictionary *span = PXROtelTestSpan(payload);
    check([span[@"name"] isEqualToString:@"praxo.tool.call"], @"otel span name");
    check(PXROtelTestHex(span[@"traceId"], 32), @"otel trace id shape");
    check(PXROtelTestHex(span[@"spanId"], 16), @"otel span id shape");
    check([span[@"startTimeUnixNano"] isEqualToString:@"1794294000000000000"],
          @"otel start time");
    check([span[@"endTimeUnixNano"] isEqualToString:@"1794294000000000000"],
          @"otel end time");
    NSDictionary *attributes = PXROtelTestAttributes(span);
    check([attributes[@"praxo.event.type"] isEqualToString:@"tool.call"],
          @"otel event type attribute");
    check([attributes[@"praxo.session.id"] isEqualToString:@"s1"],
          @"otel session attribute");
    check([attributes[@"praxo.run.id"] isEqualToString:@"run-123"],
          @"otel run attribute");
    check([attributes[@"praxo.event.at"] isEqualToString:@"1794294000000000000"],
          @"otel event time attribute");
    check([attributes[@"praxo.event.data.name"] isEqualToString:@"echo"],
          @"otel allowlisted data");
    check(attributes[@"praxo.event.data.secret"] == nil, @"otel excluded data");

    NSString *traceId = span[@"traceId"];
    NSString *spanId = span[@"spanId"];
    calls = [NSMutableArray array];
    ok = PXROtelSend(@"https://otel.test/v1/traces", event, @"checkout",
                     @[@"name"], capture, clock, &error);
    NSDictionary *repeat = PXROtelTestSpan(PXROtelTestDecode(calls.firstObject[@"body"]));
    check(ok, @"otel repeat success");
    check([repeat[@"traceId"] isEqualToString:traceId], @"otel deterministic trace id");
    check([repeat[@"spanId"] isEqualToString:spanId], @"otel deterministic span id");

    calls = [NSMutableArray array];
    ok = PXROtelSend(@"https://otel.test/v1/traces", event, @"checkout",
                     @[], capture, clock, &error);
    NSDictionary *excluded = PXROtelTestAttributes(
        PXROtelTestSpan(PXROtelTestDecode(calls.firstObject[@"body"])));
    check(ok, @"otel default exclusion success");
    check(excluded[@"praxo.event.data.name"] == nil, @"otel default excludes name");
    check(excluded[@"praxo.event.data.secret"] == nil, @"otel default excludes secret");

    error = nil;
    ok = PXROtelSend(@"   ", event, @"checkout", @[], capture, clock, &error);
    check(!ok, @"otel endpoint required");
    check([PXRCodeFromError(error) isEqualToString:@"OTEL_URL"], @"otel endpoint error");

    NSArray<NSNumber *> *accepted = @[@200, @201, @204, @299];
    for (NSNumber *status in accepted) {
        PXROtelTransport statusTransport = ^NSDictionary<NSString *, id> *(
            NSString *method, NSString *url, NSDictionary<NSString *, NSString *> *headers,
            NSData *body, NSError **transportError) {
            (void)method;
            (void)url;
            (void)headers;
            (void)body;
            (void)transportError;
            return @{@"status": status, @"body": @""};
        };
        error = nil;
        check(PXROtelSend(@"https://otel.test/v1/traces", event, @"checkout",
                           @[], statusTransport, clock, &error),
              @"otel accepts 2xx");
    }

    NSMutableString *body = [NSMutableString string];
    for (NSUInteger index = 0; index < 100; index++) {
        [body appendString:@"collector down "];
    }
    PXROtelTransport failing = ^NSDictionary<NSString *, id> *(
        NSString *method, NSString *url, NSDictionary<NSString *, NSString *> *headers,
        NSData *data, NSError **transportError) {
        (void)method;
        (void)url;
        (void)headers;
        (void)data;
        (void)transportError;
        return @{@"status": @(503), @"body": body};
    };
    error = nil;
    check(!PXROtelSend(@"https://otel.test/v1/traces", event, @"checkout",
                       @[], failing, clock, &error),
          @"otel non-2xx fails");
    NSString *message = error.localizedDescription ?: @"";
    check([PXRCodeFromError(error) isEqualToString:@"OTEL_HTTP"], @"otel http error code");
    check([message containsString:@"503"], @"otel error status");
    check([message containsString:@"collector down"], @"otel error body");
    check(message.length <= 600, @"otel bounded error body");
}
