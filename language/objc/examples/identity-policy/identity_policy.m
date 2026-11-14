#import <Foundation/Foundation.h>

static BOOL authorize(NSDictionary *principal, NSString *tool, NSString *tenant) {
    if (principal == nil) return NO;
    if (![principal[@"active"] boolValue]) return NO;
    if (![principal[@"role"] isEqualToString:@"operator"]) return NO;
    if (![principal[@"tenant"] isEqualToString:tenant]) return NO;
    return [tool isEqualToString:@"record"];
}

int main(void) {
    @autoreleasepool {
        NSDictionary *operator = @{
            @"tenant": @"acme", @"role": @"operator", @"active": @YES,
        };
        if (!authorize(operator, @"record", @"acme")) return 1;
        NSDictionary *viewer = @{
            @"tenant": @"acme", @"role": @"viewer", @"active": @YES,
        };
        if (authorize(viewer, @"record", @"acme")) return 1;
        if (authorize(operator, @"record", @"other")) return 1;
        if (authorize(nil, @"record", @"acme")) return 1;
        printf("Objective-C identity policy example passed\n");
    }
    return 0;
}
