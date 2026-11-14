#import <Foundation/Foundation.h>

static NSDictionary *handle(NSString *method, NSString *path, NSString *principal, NSString *body) {
    if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/healthz"]) {
        return @{@"status": @200, @"body": @"{\"status\":\"ok\"}"};
    }
    if (![method isEqualToString:@"POST"] || ![path isEqualToString:@"/run"]) {
        return @{@"status": @404, @"body": @"{\"error\":\"not found\"}"};
    }
    if (principal.length == 0) {
        return @{@"status": @401, @"body": @"{\"error\":\"missing X-Praxo-Principal\"}"};
    }
    if ([body rangeOfString:@"\"prompt\""].location == NSNotFound) {
        return @{@"status": @400, @"body": @"{\"error\":\"prompt is required\"}"};
    }
    return @{@"status": @200, @"body": @"{\"output\":\"hello from the service\"}"};
}

int main(void) {
    @autoreleasepool {
        if ([handle(@"GET", @"/healthz", @"", @"")[@"status"] intValue] != 200) return 1;
        if ([handle(@"POST", @"/run", @"", @"{\"prompt\":\"hi\"}")[@"status"] intValue] != 401) return 1;
        if ([handle(@"POST", @"/run", @"user-1", @"{\"prompt\":\"hi\"}")[@"status"] intValue] != 200) return 1;
        printf("Objective-C service example passed\n");
    }
    return 0;
}
