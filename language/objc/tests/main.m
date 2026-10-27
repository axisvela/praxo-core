#import <Foundation/Foundation.h>

#import "PraxoJSON.h"
#import "PraxoWire.h"

static NSUInteger failures = 0;
static NSUInteger checks = 0;

static void check(BOOL condition, NSString *message) {
    checks++;
    if (!condition) {
        failures++;
        fprintf(stderr, "FAIL %s\n", message.UTF8String);
    }
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
    NSDictionary *input = vector[@"input"];
    NSDictionary *expect = vector[@"expect"];
    NSString *identifier = vector[@"id"];
    NSString *operation = input[@"operation"];
    NSString *content = input[@"content"];
    if ([operation isEqualToString:@"strip"]) {
        NSString *actual = PXRStripToolCallMarkup(content);
        check([actual isEqualToString:expect[@"text"]],
              [NSString stringWithFormat:@"%@ strip result", identifier]);
        return;
    }
    NSError *error = nil;
    NSDictionary *call = PXRParseToolCall(content, &error);
    if ([expect[@"nil"] boolValue]) {
        check(call == nil,
              [NSString stringWithFormat:@"%@ expected nil", identifier]);
        return;
    }
    check(call != nil,
          [NSString stringWithFormat:@"%@ expected call", identifier]);
    if (call == nil) {
        return;
    }
    check([call[@"name"] isEqual:expect[@"name"]],
          [NSString stringWithFormat:@"%@ name", identifier]);
    check(PXRJSONEqual(call[@"input"], expect[@"input"]),
          [NSString stringWithFormat:@"%@ input", identifier]);
}

static void runSchema(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = vector[@"input"];
    NSDictionary *expect = vector[@"expect"];
    NSString *identifier = vector[@"id"];
    NSDictionary *schema = input[@"schema"];
    NSArray<NSString *> *paths = PXRValidateSchema(schema, input[@"data"]);
    BOOL valid = paths.count == 0;
    check(valid == [expect[@"valid"] boolValue],
          [NSString stringWithFormat:@"%@ validity", identifier]);
    NSArray *expectedPaths = expect[@"errorPaths"];
    if ([expectedPaths isKindOfClass:[NSArray class]]) {
        check(PXRJSONEqual(paths, expectedPaths),
              [NSString stringWithFormat:@"%@ error paths", identifier]);
    }
}

static void runPlugin(NSDictionary<NSString *, id> *vector) {
    NSDictionary *input = vector[@"input"];
    NSDictionary *expect = vector[@"expect"];
    NSString *identifier = vector[@"id"];
    NSString *raw = input[@"raw"];
    if (raw == nil) {
        id manifest = input[@"manifest"];
        NSData *data = [NSJSONSerialization dataWithJSONObject:manifest
                                                       options:0
                                                         error:nil];
        raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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
              [NSString stringWithFormat:@"%@ id", identifier]);
    }
    if (expect[@"kind"] != nil) {
        check([manifest[@"kind"] isEqual:expect[@"kind"]],
              [NSString stringWithFormat:@"%@ kind", identifier]);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *spec = argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"../../spec";
        NSDictionary *toolcall = loadJSON([spec stringByAppendingPathComponent:@"vectors/toolcall.json"]);
        NSDictionary *schema = loadJSON([spec stringByAppendingPathComponent:@"vectors/jsonschema.json"]);
        NSDictionary *plugin = loadJSON([spec stringByAppendingPathComponent:@"vectors/plugin.json"]);
        if (toolcall == nil || schema == nil || plugin == nil) {
            return 1;
        }
        for (NSDictionary *vector in vectors(toolcall)) {
            runToolCall(vector);
        }
        for (NSDictionary *vector in vectors(schema)) {
            runSchema(vector);
        }
        for (NSDictionary *vector in vectors(plugin)) {
            runPlugin(vector);
        }
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
