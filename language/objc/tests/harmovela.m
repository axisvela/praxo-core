#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoHarmovela.h"
#import "PraxoJSON.h"

static NSDictionary<NSString *, id> *PXRDecodeEnvelope(NSString *body) {
    id value = nil;
    NSError *error = nil;
    if (!PXRParseJSONText(body ?: @"", &value, &error)) {
        return nil;
    }
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static PXRHarmovelaTransport PXRStatusTransport(NSInteger status, NSString *body) {
    return ^NSDictionary<NSString *, id> *(NSString *method,
                                           NSString *url,
                                           NSDictionary<NSString *, id> *headers,
                                           NSData *data,
                                           NSError **error) {
        (void)method;
        (void)url;
        (void)headers;
        (void)data;
        (void)error;
        return @{@"status": @(status), @"body": body ?: @""};
    };
}

void runHarmovelaTests(void (*check)(BOOL, NSString *)) {
    __block NSMutableArray<NSDictionary<NSString *, id> *> *calls = [NSMutableArray array];
    PXRHarmovelaTransport capture = ^NSDictionary<NSString *, id> *(
        NSString *method, NSString *url, NSDictionary<NSString *, id> *headers,
        NSData *body, NSError **error) {
        (void)error;
        NSString *text = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        [calls addObject:@{@"method": method ?: @"",
                           @"url": url ?: @"",
                           @"headers": headers ?: @{},
                           @"body": text ?: @""}];
        return @{@"status": @(201), @"body": @""};
    };
    PXRHarmovelaClock clock = ^NSDate *{
        return [NSDate dateWithTimeIntervalSince1970:1794294000.0];
    };

    NSDictionary *event = PXREventCreate(@"tool.call", @"s1", @"run-123",
                                         @{@"name": @"echo"});
    NSError *error = nil;
    BOOL ok = PXRHarmovelaSend(@"http://harmovela.test/aep/api/", event,
                               @"praxo-core", @"0.2", capture, clock, &error);
    check(ok && error == nil, @"harmovela success");
    check(calls.count == 1, @"harmovela single request");
    NSDictionary *call = calls.firstObject;
    check([call[@"method"] isEqualToString:@"POST"], @"harmovela method");
    check([call[@"url"] isEqualToString:@"http://harmovela.test/aep/api/events"],
          @"harmovela path");
    check([call[@"headers"][@"content-type"] isEqualToString:@"application/json"],
          @"harmovela content type");
    NSDictionary *envelope = PXRDecodeEnvelope(call[@"body"]);
    check([envelope[@"spec_version"] isEqualToString:@"0.2"], @"harmovela spec");
    check([envelope[@"id"] isEqualToString:@"run-123-1794294000000000000"],
          @"harmovela id");
    check([envelope[@"type"] isEqualToString:@"tool.call"], @"harmovela type");
    check([envelope[@"source"] isEqualToString:@"praxo-core"], @"harmovela source");
    check([envelope[@"created_at"] isEqualToString:@"2026-11-10T07:00:00.000000000Z"],
          @"harmovela created_at");
    NSDictionary *payload = envelope[@"payload"];
    check([payload[@"name"] isEqualToString:@"echo"], @"harmovela payload data");
    check([payload[@"session_id"] isEqualToString:@"s1"], @"harmovela payload session");
    check([payload[@"run_id"] isEqualToString:@"run-123"], @"harmovela payload run");

    calls = [NSMutableArray array];
    NSDictionary *merged = PXREventCreate(
        @"tool.call", @"s1", nil,
        @{@"name": @"echo", @"session_id": @"event-side", @"run_id": @"old"});
    error = nil;
    ok = PXRHarmovelaSend(@"http://harmovela.test", merged, @"custom", @"0.3",
                          capture, clock, &error);
    check(ok && error == nil, @"harmovela custom success");
    NSDictionary *mergedEnvelope = PXRDecodeEnvelope(calls.firstObject[@"body"]);
    check([mergedEnvelope[@"source"] isEqualToString:@"custom"], @"harmovela custom source");
    check([mergedEnvelope[@"spec_version"] isEqualToString:@"0.3"], @"harmovela custom spec");
    check([mergedEnvelope[@"id"] hasPrefix:@"s1-"], @"harmovela session id");
    NSDictionary *mergedPayload = mergedEnvelope[@"payload"];
    check([mergedPayload[@"session_id"] isEqualToString:@"s1"], @"harmovela session override");
    check([mergedPayload[@"run_id"] isEqualToString:@"old"], @"harmovela data run retained");

    NSArray<NSNumber *> *accepted = @[@200, @201, @204, @299];
    for (NSNumber *status in accepted) {
        error = nil;
        PXRHarmovelaTransport transport =
            PXRStatusTransport(status.integerValue, @"");
        check(PXRHarmovelaSend(@"http://harmovela.test", event, @"praxo-core",
                               @"0.2", transport, clock, &error),
              @"harmovela accepts 2xx");
    }

    NSMutableString *body = [NSMutableString string];
    for (NSUInteger index = 0; index < 100; index++) {
        [body appendString:@"service down "];
    }
    PXRHarmovelaTransport failing = PXRStatusTransport(503, body);
    error = nil;
    check(!PXRHarmovelaSend(@"http://harmovela.test", event, @"praxo-core",
                            @"0.2", failing, clock, &error),
          @"harmovela non-2xx fails");
    NSString *message = error.localizedDescription ?: @"";
    check([message containsString:@"503"], @"harmovela error status");
    check([message containsString:@"service down"], @"harmovela error body");
    check(message.length <= 600, @"harmovela bounded error");
}
