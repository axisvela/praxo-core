#import "PraxoHarmovela.h"

#import "PraxoJSON.h"

static NSString *PXRString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *PXRTrimSlashes(NSString *text) {
    NSUInteger length = text.length;
    while (length > 0 && [text characterAtIndex:length - 1] == '/') {
        length--;
    }
    return [text substringToIndex:length];
}

static NSString *PXRBounded(NSString *text, NSUInteger limit) {
    return text.length > limit ? [text substringToIndex:limit] : text;
}

static NSDate *PXRHarmovelaAt(NSDictionary<NSString *, id> *event,
                              PXRHarmovelaClock clock) {
    id value = event[@"at"];
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if (clock != nil) {
        NSDate *at = clock();
        if (at != nil) {
            return at;
        }
    }
    return [NSDate date];
}

static void PXRTimeParts(NSDate *at, long long *seconds, long long *nanos) {
    NSTimeInterval interval = at.timeIntervalSince1970;
    long long whole = (long long)floor(interval);
    long long fraction = (long long)llround((interval - (double)whole) * 1000000000.0);
    if (fraction >= 1000000000LL) {
        whole += 1;
        fraction -= 1000000000LL;
    }
    *seconds = whole;
    *nanos = fraction;
}

static NSString *PXRFormatCreatedAt(NSDate *at, long long seconds, long long nanos) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSDate *whole = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)seconds];
    return [NSString stringWithFormat:@"%@.%09lldZ", [formatter stringFromDate:whole], nanos];
}

static NSString *PXREventID(NSDictionary<NSString *, id> *event,
                            long long seconds,
                            long long nanos) {
    NSString *prefix = PXRString(event[@"runId"]);
    if (prefix.length == 0) {
        prefix = PXRString(event[@"sessionId"]);
    }
    if (prefix.length == 0) {
        prefix = @"event";
    }
    long long epoch = seconds * 1000000000LL + nanos;
    return [NSString stringWithFormat:@"%@-%lld", prefix, epoch];
}

NSDictionary<NSString *, id> *PXRHarmovelaEnvelope(
    NSDictionary<NSString *, id> *event,
    NSString *source,
    NSString *specVersion,
    NSDate *at) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    id data = event[@"data"];
    if ([data isKindOfClass:[NSDictionary class]]) {
        [payload addEntriesFromDictionary:data];
    }
    NSString *sessionId = PXRString(event[@"sessionId"]);
    if (sessionId.length > 0) {
        payload[@"session_id"] = sessionId;
    }
    NSString *runId = PXRString(event[@"runId"]);
    if (runId.length > 0) {
        payload[@"run_id"] = runId;
    }
    long long seconds = 0;
    long long nanos = 0;
    PXRTimeParts(at, &seconds, &nanos);
    return @{
        @"spec_version": specVersion.length > 0 ? specVersion : @"0.2",
        @"id": PXREventID(event, seconds, nanos),
        @"type": PXRString(event[@"type"]),
        @"source": source.length > 0 ? source : @"praxo-core",
        @"created_at": PXRFormatCreatedAt(at, seconds, nanos),
        @"payload": payload,
    };
}

static NSDictionary<NSString *, id> *PXRHarmovelaDefaultTransport(
    NSString *method,
    NSString *url,
    NSDictionary<NSString *, id> *headers,
    NSData *body,
    NSError **error) {
    NSURL *target = [NSURL URLWithString:url];
    if (target == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"HARMOVELA_HTTP", @"harmovela: invalid URL");
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
            *error = connectionError ?: PXRCoreError(@"HARMOVELA_HTTP",
                                                     @"harmovela: request failed");
        }
        return nil;
    }
    NSInteger status = [urlResponse isKindOfClass:[NSHTTPURLResponse class]]
        ? [(NSHTTPURLResponse *)urlResponse statusCode] : 200;
    NSString *text = [[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding] ?: @"";
    return @{@"status": @(status), @"body": text};
}

BOOL PXRHarmovelaSend(
    NSString *baseURL,
    NSDictionary<NSString *, id> *event,
    NSString *source,
    NSString *specVersion,
    PXRHarmovelaTransport transport,
    PXRHarmovelaClock clock,
    NSError **error) {
    if (baseURL.length == 0) {
        if (error != NULL) {
            *error = PXRCoreError(@"HARMOVELA_BASE_URL",
                                  @"harmovela: base URL is required");
        }
        return NO;
    }
    NSDictionary *envelope = PXRHarmovelaEnvelope(
        event,
        source.length > 0 ? source : @"praxo-core",
        specVersion.length > 0 ? specVersion : @"0.2",
        PXRHarmovelaAt(event, clock));
    NSError *jsonError = nil;
    NSString *raw = PXRJSONText(envelope, &jsonError);
    if (raw == nil) {
        if (error != NULL) {
            *error = jsonError ?: PXRCoreError(@"HARMOVELA_JSON",
                                               @"harmovela: cannot encode envelope");
        }
        return NO;
    }
    NSDictionary *headers = @{@"content-type": @"application/json"};
    NSData *body = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [PXRTrimSlashes(baseURL) stringByAppendingString:@"/events"];
    NSDictionary *response = transport != nil
        ? transport(@"POST", url, headers, body, error)
        : PXRHarmovelaDefaultTransport(@"POST", url, headers, body, error);
    if (response == nil) {
        return NO;
    }
    NSInteger status = [response[@"status"] respondsToSelector:@selector(integerValue)]
        ? [response[@"status"] integerValue] : 0;
    if (status < 200 || status >= 300) {
        NSString *text = PXRString(response[@"body"]);
        if (error != NULL) {
            *error = PXRCoreError(
                @"HARMOVELA_HTTP",
                [NSString stringWithFormat:@"harmovela: HTTP %ld: %@",
                                           (long)status,
                                           PXRBounded(text, 512)]);
        }
        return NO;
    }
    return YES;
}

PXREventSink PXRHarmovelaSink(
    NSString *baseURL,
    NSString *source,
    NSString *specVersion,
    PXRHarmovelaTransport transport,
    PXRHarmovelaClock clock) {
    return ^(NSDictionary<NSString *, id> *event) {
        PXRHarmovelaSend(baseURL, event, source, specVersion, transport, clock, NULL);
    };
}
