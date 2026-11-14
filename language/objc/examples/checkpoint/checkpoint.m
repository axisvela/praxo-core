#import <Foundation/Foundation.h>
#import "PraxoCore.h"
#import "PraxoJSON.h"

int main(void) {
    @autoreleasepool {
        NSMutableSet<NSString *> *allow = PXRCheckpointAllowlistCreate();
        PXRCheckpointRegister(allow, @"order");
        NSError *error = nil;
        NSString *data = PXRCheckpointMarshal(allow, @"order", @{@"value": @"x"}, &error);
        id decoded = PXRCheckpointUnmarshal(allow, data, &error);
        if (!PXRJSONEqual(decoded, @{@"value": @"x"})) return 1;
        printf("Objective-C checkpoint example passed\n");
    }
    return 0;
}
