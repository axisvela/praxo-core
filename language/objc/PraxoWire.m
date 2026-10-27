#import "PraxoWire.h"
#import "PraxoJSON.h"

NSString *const PXRSpecVersion = @"0.2.0";
NSString *const PXRSDKVersion = @"0.1.0";

static NSArray<NSArray<NSString *> *> *PXRMatches(NSString *pattern, NSString *text) {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:NSRegularExpressionDotMatchesLineSeparators
                               error:&error];
    if (regex == nil) {
        return @[];
    }
    NSRange range = NSMakeRange(0, text.length);
    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:text options:0 range:range];
    NSMutableArray<NSArray<NSString *> *> *result = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        NSMutableArray<NSString *> *captures = [NSMutableArray array];
        for (NSUInteger i = 0; i < match.numberOfRanges; i++) {
            NSRange capture = [match rangeAtIndex:i];
            if (capture.location == NSNotFound) {
                [captures addObject:@""];
            } else {
                [captures addObject:[text substringWithRange:capture]];
            }
        }
        [result addObject:captures];
    }
    return result;
}

NSDictionary<NSString *, id> *PXRParseInputJSON(NSString *raw) {
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    id value = nil;
    if (PXRParseJSONText(trimmed, &value, nil) &&
        [value isKindOfClass:[NSDictionary class]]) {
        return value;
    }
    NSString *escaped = [trimmed stringByReplacingOccurrencesOfString:@"\\"
                                                           withString:@"\\\\"];
    if (PXRParseJSONText(escaped, &value, nil) &&
        [value isKindOfClass:[NSDictionary class]]) {
        return value;
    }
    return nil;
}

static NSDictionary<NSString *, id> *PXRCall(NSString *name,
                                             NSDictionary<NSString *, id> *input,
                                             NSDictionary<NSString *, id> *source) {
    NSMutableDictionary<NSString *, id> *call = [NSMutableDictionary dictionary];
    call[@"name"] = name;
    call[@"input"] = input ?: @{};
    NSArray<NSString *> *keys = @[@"operation", @"resource", @"risk", @"reason",
                                  @"idempotency_key"];
    for (NSString *key in keys) {
        id value = source[key];
        if ([value isKindOfClass:[NSString class]]) {
            call[key] = value;
        }
    }
    return call;
}

static NSDictionary<NSString *, id> *PXRParseJSONCall(NSString *content) {
    id value = nil;
    if (!PXRParseJSONText(content, &value, nil) ||
        ![value isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary<NSString *, id> *object = value;
    id name = object[@"name"];
    if (![name isKindOfClass:[NSString class]] || [name length] == 0) {
        return nil;
    }
    NSDictionary<NSString *, id> *input = object[@"input"];
    if (input != nil && ![input isKindOfClass:[NSDictionary class]]) {
        input = @{};
    }
    return PXRCall(name, input ?: @{}, object);
}

static NSDictionary<NSString *, id> *PXRParseXMLCall(NSString *content) {
    NSArray<NSArray<NSString *> *> *matches = PXRMatches(
        @"<tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</tool_call>", content);
    NSArray<NSString *> *match = matches.lastObject;
    if (match == nil || match.count < 3) {
        return nil;
    }
    NSDictionary<NSString *, id> *input = PXRParseInputJSON(match[2]);
    if (input == nil) {
        return nil;
    }
    return PXRCall(match[1], input, @{});
}

static NSDictionary<NSString *, id> *PXRParseTagCall(NSString *content) {
    NSArray<NSArray<NSString *> *> *matches = PXRMatches(
        @"<([a-zA-Z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[a-zA-Z][\\w.-]*>|$)",
        content);
    NSArray<NSString *> *match = matches.lastObject;
    if (match == nil || match.count < 3) {
        return nil;
    }
    NSDictionary<NSString *, id> *input = PXRParseInputJSON(match[2]);
    if (input == nil) {
        return nil;
    }
    return PXRCall(match[1], input, @{});
}

static NSDictionary<NSString *, id> *PXRParsePlainCall(NSString *content) {
    NSArray<NSArray<NSString *> *> *matches = PXRMatches(
        @"(?m)^\\s*([a-zA-Z][\\w.-]*)\\s+(\\{.*\\})\\s*$", content);
    NSArray<NSString *> *match = matches.lastObject;
    if (match == nil || match.count < 3 ||
        [match[1] rangeOfString:@"."].location == NSNotFound) {
        return nil;
    }
    NSDictionary<NSString *, id> *input = PXRParseInputJSON(match[2]);
    if (input == nil) {
        return nil;
    }
    return PXRCall(match[1], input, @{});
}

NSDictionary<NSString *, id> * _Nullable PXRParseToolCall(
    NSString *content, NSError **error) {
    if (content == nil) {
        if (error != NULL) {
            *error = PXRError(PXRWireErrorInvalidToolCall, @"tool call content is nil");
        }
        return nil;
    }
    NSDictionary<NSString *, id> *call = PXRParseJSONCall(content)
        ?: PXRParseXMLCall(content)
        ?: PXRParseTagCall(content)
        ?: PXRParsePlainCall(content);
    if (call == nil && error != NULL) {
        *error = PXRError(PXRWireErrorInvalidToolCall, @"content is not a tool call");
    }
    return call;
}

NSString *PXRStripToolCallMarkup(NSString *content) {
    if (content == nil) {
        return @"";
    }
    NSArray<NSString *> *patterns = @[
        @"<tool_call\\s+name=\"[^\"]+\"\\s*>.*?(?:</tool_call>|$)",
        @"<tool_call_invoke>.*?(?:</tool_call_invoke>|$)",
        @"<[a-zA-Z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[a-zA-Z][\\w.-]*>|$)",
    ];
    NSString *output = content;
    for (NSString *pattern in patterns) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression
            regularExpressionWithPattern:pattern
                                 options:NSRegularExpressionDotMatchesLineSeparators
                                   error:&error];
        if (regex != nil) {
            NSRange range = NSMakeRange(0, output.length);
            output = [regex stringByReplacingMatchesInString:output
                                                     options:0
                                                       range:range
                                                withTemplate:@""];
        }
    }
    NSError *error = nil;
    NSRegularExpression *blankLines = [NSRegularExpression
        regularExpressionWithPattern:@"\\n{3,}"
                             options:0
                               error:&error];
    if (blankLines != nil) {
        NSRange range = NSMakeRange(0, output.length);
        output = [blankLines stringByReplacingMatchesInString:output
                                                      options:0
                                                        range:range
                                                 withTemplate:@"\n\n"];
    }
    return [output stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
