#import "PraxoJSON.h"
#import "PraxoWire.h"

#if defined(__APPLE__)
#import <CoreFoundation/CoreFoundation.h>
#endif

NSString *const PXRWireErrorDomain = @"io.axisvela.praxo.wire";

NSError *PXRError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:PXRWireErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL PXRFail(NSError **error, NSInteger code, NSString *message) {
    if (error != NULL) {
        *error = PXRError(code, message);
    }
    return NO;
}

typedef struct {
    __unsafe_unretained NSString *text;
    NSUInteger length;
    NSUInteger index;
} PXRScan;

static void PXRSkipWhitespace(PXRScan *scan) {
    while (scan->index < scan->length) {
        unichar c = [scan->text characterAtIndex:scan->index];
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
            break;
        }
        scan->index++;
    }
}

static BOOL PXRScanHex4(PXRScan *scan, NSError **error) {
    if (scan->index + 4 > scan->length) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid unicode escape");
    }
    for (NSUInteger i = 0; i < 4; i++) {
        unichar c = [scan->text characterAtIndex:scan->index + i];
        BOOL hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
                   (c >= 'A' && c <= 'F');
        if (!hex) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid unicode escape");
        }
    }
    scan->index += 4;
    return YES;
}

static BOOL PXRScanString(PXRScan *scan, NSMutableString * _Nullable output,
                          NSError **error) {
    if (scan->index >= scan->length ||
        [scan->text characterAtIndex:scan->index] != '"') {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"expected JSON string");
    }
    scan->index++;
    while (scan->index < scan->length) {
        unichar c = [scan->text characterAtIndex:scan->index++];
        if (c == '"') {
            return YES;
        }
        if (c < 0x20) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"control character in string");
        }
        if (c != '\\') {
            if (output != nil) {
                [output appendString:[NSString stringWithCharacters:&c length:1]];
            }
            continue;
        }
        if (scan->index >= scan->length) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"unfinished escape");
        }
        unichar escaped = [scan->text characterAtIndex:scan->index++];
        unichar decoded = 0;
        switch (escaped) {
            case '"': decoded = '"'; break;
            case '\\': decoded = '\\'; break;
            case '/': decoded = '/'; break;
            case 'b': decoded = '\b'; break;
            case 'f': decoded = '\f'; break;
            case 'n': decoded = '\n'; break;
            case 'r': decoded = '\r'; break;
            case 't': decoded = '\t'; break;
            case 'u': {
                if (!PXRScanHex4(scan, error)) {
                    return NO;
                }
                NSString *digits = [scan->text substringWithRange:
                    NSMakeRange(scan->index - 4, 4)];
                unsigned int value = 0;
                if (![[NSScanner scannerWithString:digits] scanHexInt:&value]) {
                    return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid unicode escape");
                }
                decoded = (unichar)value;
                break;
            }
            default:
                return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid escape");
        }
        if (output != nil) {
            [output appendString:[NSString stringWithCharacters:&decoded length:1]];
        }
    }
    return PXRFail(error, PXRWireErrorInvalidJSON, @"unterminated string");
}

static BOOL PXRScanNumber(PXRScan *scan, NSError **error) {
    if (scan->index < scan->length &&
        [scan->text characterAtIndex:scan->index] == '-') {
        scan->index++;
    }
    if (scan->index >= scan->length) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid number");
    }
    unichar first = [scan->text characterAtIndex:scan->index];
    if (first == '0') {
        scan->index++;
        if (scan->index < scan->length) {
            unichar next = [scan->text characterAtIndex:scan->index];
            if (next >= '0' && next <= '9') {
                return PXRFail(error, PXRWireErrorInvalidJSON, @"leading zero");
            }
        }
    } else if (first >= '1' && first <= '9') {
        while (scan->index < scan->length) {
            unichar c = [scan->text characterAtIndex:scan->index];
            if (c < '0' || c > '9') {
                break;
            }
            scan->index++;
        }
    } else {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid number");
    }
    if (scan->index < scan->length &&
        [scan->text characterAtIndex:scan->index] == '.') {
        scan->index++;
        NSUInteger start = scan->index;
        while (scan->index < scan->length) {
            unichar c = [scan->text characterAtIndex:scan->index];
            if (c < '0' || c > '9') {
                break;
            }
            scan->index++;
        }
        if (scan->index == start) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid fraction");
        }
    }
    if (scan->index < scan->length) {
        unichar c = [scan->text characterAtIndex:scan->index];
        if (c == 'e' || c == 'E') {
            scan->index++;
            if (scan->index < scan->length) {
                unichar sign = [scan->text characterAtIndex:scan->index];
                if (sign == '+' || sign == '-') {
                    scan->index++;
                }
            }
            NSUInteger start = scan->index;
            while (scan->index < scan->length) {
                unichar d = [scan->text characterAtIndex:scan->index];
                if (d < '0' || d > '9') {
                    break;
                }
                scan->index++;
            }
            if (scan->index == start) {
                return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid exponent");
            }
        }
    }
    return YES;
}

static BOOL PXRScanLiteral(PXRScan *scan, NSString *literal, NSError **error) {
    NSUInteger length = literal.length;
    if (scan->index + length > scan->length) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid literal");
    }
    NSString *candidate = [scan->text substringWithRange:
        NSMakeRange(scan->index, length)];
    if (![candidate isEqualToString:literal]) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid literal");
    }
    scan->index += length;
    return YES;
}

static BOOL PXRScanValue(PXRScan *scan, NSUInteger depth, NSError **error);

static BOOL PXRScanObject(PXRScan *scan, NSUInteger depth, NSError **error) {
    scan->index++;
    NSMutableSet<NSString *> *keys = [NSMutableSet set];
    PXRSkipWhitespace(scan);
    if (scan->index < scan->length &&
        [scan->text characterAtIndex:scan->index] == '}') {
        scan->index++;
        return YES;
    }
    while (YES) {
        PXRSkipWhitespace(scan);
        NSMutableString *key = [NSMutableString string];
        if (!PXRScanString(scan, key, error)) {
            return NO;
        }
        if ([keys member:key] != nil) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"duplicate object key");
        }
        [keys addObject:key];
        PXRSkipWhitespace(scan);
        if (scan->index >= scan->length ||
            [scan->text characterAtIndex:scan->index] != ':') {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"expected colon");
        }
        scan->index++;
        if (!PXRScanValue(scan, depth + 1, error)) {
            return NO;
        }
        PXRSkipWhitespace(scan);
        if (scan->index >= scan->length) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"unterminated object");
        }
        unichar c = [scan->text characterAtIndex:scan->index++];
        if (c == '}') {
            return YES;
        }
        if (c != ',') {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"expected comma");
        }
    }
}

static BOOL PXRScanArray(PXRScan *scan, NSUInteger depth, NSError **error) {
    scan->index++;
    PXRSkipWhitespace(scan);
    if (scan->index < scan->length &&
        [scan->text characterAtIndex:scan->index] == ']') {
        scan->index++;
        return YES;
    }
    while (YES) {
        if (!PXRScanValue(scan, depth + 1, error)) {
            return NO;
        }
        PXRSkipWhitespace(scan);
        if (scan->index >= scan->length) {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"unterminated array");
        }
        unichar c = [scan->text characterAtIndex:scan->index++];
        if (c == ']') {
            return YES;
        }
        if (c != ',') {
            return PXRFail(error, PXRWireErrorInvalidJSON, @"expected comma");
        }
    }
}

static BOOL PXRScanValue(PXRScan *scan, NSUInteger depth, NSError **error) {
    if (depth > 64) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"JSON nesting too deep");
    }
    PXRSkipWhitespace(scan);
    if (scan->index >= scan->length) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"empty JSON");
    }
    unichar c = [scan->text characterAtIndex:scan->index];
    if (c == '{') {
        return PXRScanObject(scan, depth, error);
    }
    if (c == '[') {
        return PXRScanArray(scan, depth, error);
    }
    if (c == '"') {
        return PXRScanString(scan, nil, error);
    }
    if (c == 't') {
        return PXRScanLiteral(scan, @"true", error);
    }
    if (c == 'f') {
        return PXRScanLiteral(scan, @"false", error);
    }
    if (c == 'n') {
        return PXRScanLiteral(scan, @"null", error);
    }
    if (c == '-' || (c >= '0' && c <= '9')) {
        return PXRScanNumber(scan, error);
    }
    return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid JSON value");
}

BOOL PXRParseJSONText(NSString *text, id _Nullable * _Nullable value, NSError **error) {
    if (text.length == 0) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"empty JSON");
    }
    PXRScan scan = {text, text.length, 0};
    if (!PXRScanValue(&scan, 0, error)) {
        return NO;
    }
    PXRSkipWhitespace(&scan);
    if (scan.index != scan.length) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"trailing JSON data");
    }
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return PXRFail(error, PXRWireErrorInvalidJSON, @"invalid UTF-8");
    }
    NSError *parseError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                options:NSJSONReadingAllowFragments
                                                  error:&parseError];
    if (parsed == nil) {
        if (error != NULL) {
            *error = parseError ?: PXRError(PXRWireErrorInvalidJSON, @"invalid JSON");
        }
        return NO;
    }
    if (value != NULL) {
        *value = parsed;
    }
    return YES;
}

BOOL PXRIsBooleanValue(id value) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
#if defined(__APPLE__)
    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
#else
    NSString *className = NSStringFromClass([value class]);
    return [className rangeOfString:@"Bool"].location != NSNotFound;
#endif
}

BOOL PXRIsNumberValue(id value) {
    return [value isKindOfClass:[NSNumber class]] && !PXRIsBooleanValue(value);
}

NSString *PXRJSONText(id value, NSError **error) {
    if (![NSJSONSerialization isValidJSONObject:value]) {
        if (error != NULL) {
            *error = PXRError(PXRWireErrorInvalidJSON, @"value is not JSON encodable");
        }
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:value
                                                   options:0
                                                     error:error];
    if (data == nil) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

BOOL PXRStringHasPrefix(NSString *text, NSString *prefix) {
    if (text == nil || prefix == nil || prefix.length > text.length) {
        return NO;
    }
    if (prefix.length == 0) {
        return YES;
    }
    return [text rangeOfString:prefix options:NSAnchoredSearch].location != NSNotFound;
}

BOOL PXRStringHasSuffix(NSString *text, NSString *suffix) {
    if (text == nil || suffix == nil || suffix.length > text.length) {
        return NO;
    }
    if (suffix.length == 0) {
        return YES;
    }
    return [text rangeOfString:suffix
                       options:(NSAnchoredSearch | NSBackwardsSearch)].location != NSNotFound;
}

BOOL PXRJSONEqual(id left, id right) {
    if (left == nil || right == nil) {
        return left == nil && right == nil;
    }
    if (left == right) {
        return YES;
    }
    if (left == [NSNull null] || right == [NSNull null]) {
        return left == [NSNull null] && right == [NSNull null];
    }
    if ([left isKindOfClass:[NSDictionary class]] &&
        [right isKindOfClass:[NSDictionary class]]) {
        NSDictionary *a = left;
        NSDictionary *b = right;
        if (a.count != b.count) {
            return NO;
        }
        for (id key in a) {
            if (b[key] == nil || !PXRJSONEqual(a[key], b[key])) {
                return NO;
            }
        }
        return YES;
    }
    if ([left isKindOfClass:[NSArray class]] &&
        [right isKindOfClass:[NSArray class]]) {
        NSArray *a = left;
        NSArray *b = right;
        if (a.count != b.count) {
            return NO;
        }
        for (NSUInteger i = 0; i < a.count; i++) {
            if (!PXRJSONEqual(a[i], b[i])) {
                return NO;
            }
        }
        return YES;
    }
    BOOL leftBool = PXRIsBooleanValue(left);
    BOOL rightBool = PXRIsBooleanValue(right);
    if (leftBool || rightBool) {
        return leftBool && rightBool &&
               [(NSNumber *)left boolValue] == [(NSNumber *)right boolValue];
    }
    if ([left isKindOfClass:[NSNumber class]] &&
        [right isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)left doubleValue] == [(NSNumber *)right doubleValue];
    }
    if ([left isKindOfClass:[NSString class]] &&
        [right isKindOfClass:[NSString class]]) {
        return [left isEqualToString:right];
    }
    return NO;
}

NSUInteger PXRCodePointCount(NSString *text) {
    NSUInteger count = 0;
    NSUInteger length = text.length;
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
            unichar next = [text characterAtIndex:i + 1];
            if (next >= 0xDC00 && next <= 0xDFFF) {
                i++;
            }
        }
        count++;
    }
    return count;
}

BOOL PXRMatchesPattern(NSString *pattern, NSString *text) {
    if (pattern.length == 0) {
        return YES;
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:0
                               error:&error];
    if (regex == nil) {
        return NO;
    }
    NSRange range = NSMakeRange(0, text.length);
    return [regex firstMatchInString:text options:0 range:range] != nil;
}

BOOL PXRMatchesFull(NSString *pattern, NSString *text) {
    NSString *wrapped = [NSString stringWithFormat:@"^(?:%@)$", pattern];
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:wrapped
                             options:0
                               error:nil];
    if (regex == nil) {
        return NO;
    }
    NSRange range = NSMakeRange(0, text.length);
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:range];
    return match != nil && match.range.location == 0 && match.range.length == text.length;
}

NSString *PXRChildPath(NSString *base, NSString *key) {
    return [NSString stringWithFormat:@"%@.%@", base, key];
}

NSString *PXRIndexPath(NSString *base, NSUInteger index) {
    return [NSString stringWithFormat:@"%@[%lu]", base, (unsigned long)index];
}
