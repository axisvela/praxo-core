#import "PraxoWire.h"
#import "PraxoJSON.h"

#import <math.h>

static void PXRVisitSchema(NSDictionary<NSString *, id> *schema,
                           id data,
                           NSString *path,
                           NSMutableArray<NSString *> *errors);

static void PXRCheckEnum(NSDictionary<NSString *, id> *schema,
                         id data,
                         NSString *path,
                         NSMutableArray<NSString *> *errors) {
    NSArray *values = schema[@"enum"];
    if (![values isKindOfClass:[NSArray class]] || values.count == 0) {
        return;
    }
    for (id value in values) {
        if (PXRJSONEqual(value, data)) {
            return;
        }
    }
    [errors addObject:path];
}

static void PXRVisitObject(NSDictionary<NSString *, id> *schema,
                           id data,
                           NSString *path,
                           NSMutableArray<NSString *> *errors) {
    if (![data isKindOfClass:[NSDictionary class]]) {
        [errors addObject:path];
        return;
    }
    NSDictionary<NSString *, id> *object = data;
    NSArray *required = schema[@"required"];
    if ([required isKindOfClass:[NSArray class]]) {
        for (id item in required) {
            if ([item isKindOfClass:[NSString class]] && object[item] == nil) {
                [errors addObject:PXRChildPath(path, item)];
            }
        }
    }
    NSDictionary<NSString *, id> *properties = schema[@"properties"];
    if ([properties isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in properties) {
            id value = object[key];
            id child = properties[key];
            if (value != nil && [child isKindOfClass:[NSDictionary class]]) {
                PXRVisitSchema(child, value, PXRChildPath(path, key), errors);
            }
        }
    }
}

static void PXRVisitArray(NSDictionary<NSString *, id> *schema,
                          id data,
                          NSString *path,
                          NSMutableArray<NSString *> *errors) {
    if (![data isKindOfClass:[NSArray class]]) {
        [errors addObject:path];
        return;
    }
    NSArray *array = data;
    NSDictionary<NSString *, id> *items = schema[@"items"];
    if ([items isKindOfClass:[NSDictionary class]]) {
        for (NSUInteger i = 0; i < array.count; i++) {
            PXRVisitSchema(items, array[i], PXRIndexPath(path, i), errors);
        }
    }
}

static void PXRVisitString(NSDictionary<NSString *, id> *schema,
                           id data,
                           NSString *path,
                           NSMutableArray<NSString *> *errors) {
    if (![data isKindOfClass:[NSString class]]) {
        [errors addObject:path];
        return;
    }
    NSString *text = data;
    NSUInteger length = PXRCodePointCount(text);
    id minValue = schema[@"minLength"];
    id maxValue = schema[@"maxLength"];
    if (PXRIsNumberValue(minValue) && [minValue doubleValue] != 0 &&
        length < (NSUInteger)[minValue doubleValue]) {
        [errors addObject:path];
    }
    if (PXRIsNumberValue(maxValue) && [maxValue doubleValue] != 0 &&
        length > (NSUInteger)[maxValue doubleValue]) {
        [errors addObject:path];
    }
    id patternValue = schema[@"pattern"];
    if ([patternValue isKindOfClass:[NSString class]]) {
        NSString *pattern = patternValue;
        BOOL ascii = YES;
        for (NSUInteger i = 0; i < pattern.length; i++) {
            if ([pattern characterAtIndex:i] > 0x7F) {
                ascii = NO;
                break;
            }
        }
        if (!ascii || pattern.length > 512 || !PXRMatchesPattern(pattern, text)) {
            [errors addObject:path];
        }
    }
    PXRCheckEnum(schema, data, path, errors);
}

static void PXRVisitNumber(NSDictionary<NSString *, id> *schema,
                           NSString *kind,
                           id data,
                           NSString *path,
                           NSMutableArray<NSString *> *errors) {
    if (!PXRIsNumberValue(data)) {
        [errors addObject:path];
        return;
    }
    NSNumber *number = data;
    double value = number.doubleValue;
    if ([kind isEqualToString:@"integer"] && trunc(value) != value) {
        [errors addObject:path];
        return;
    }
    PXRCheckEnum(schema, data, path, errors);
    id minimum = schema[@"minimum"];
    id maximum = schema[@"maximum"];
    if (PXRIsNumberValue(minimum) && [minimum doubleValue] != 0 &&
        value < [minimum doubleValue]) {
        [errors addObject:path];
    }
    if (PXRIsNumberValue(maximum) && [maximum doubleValue] != 0 &&
        value > [maximum doubleValue]) {
        [errors addObject:path];
    }
}

static void PXRVisitBoolean(NSDictionary<NSString *, id> *schema,
                            id data,
                            NSString *path,
                            NSMutableArray<NSString *> *errors) {
    if (!PXRIsBooleanValue(data)) {
        [errors addObject:path];
        return;
    }
    PXRCheckEnum(schema, data, path, errors);
}

static void PXRVisitSchema(NSDictionary<NSString *, id> *schema,
                           id data,
                           NSString *path,
                           NSMutableArray<NSString *> *errors) {
    NSString *kind = schema[@"type"];
    if (![kind isKindOfClass:[NSString class]]) {
        kind = @"";
    }
    if (data == nil || data == [NSNull null]) {
        if (kind.length > 0) {
            [errors addObject:path];
        }
        return;
    }
    if ([kind isEqualToString:@"object"]) {
        PXRVisitObject(schema, data, path, errors);
    } else if ([kind isEqualToString:@"array"]) {
        PXRVisitArray(schema, data, path, errors);
    } else if ([kind isEqualToString:@"string"]) {
        PXRVisitString(schema, data, path, errors);
    } else if ([kind isEqualToString:@"number"] ||
               [kind isEqualToString:@"integer"]) {
        PXRVisitNumber(schema, kind, data, path, errors);
    } else if ([kind isEqualToString:@"boolean"]) {
        PXRVisitBoolean(schema, data, path, errors);
    }
}

NSArray<NSString *> *PXRValidateSchema(NSDictionary<NSString *, id> *schema,
                                       id data) {
    if (![schema isKindOfClass:[NSDictionary class]]) {
        return @[@"$"];
    }
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    PXRVisitSchema(schema, data ?: [NSNull null], @"$", errors);
    return errors;
}
