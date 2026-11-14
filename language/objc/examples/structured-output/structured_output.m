#import <Foundation/Foundation.h>
#import "PraxoWire.h"

int main(void) {
    @autoreleasepool {
        NSDictionary *schema = @{
            @"type": @"object",
            @"required": @[@"name"],
            @"properties": @{@"name": @{@"type": @"string"}},
        };
        NSArray *validErrors = PXRValidateSchema(schema, @{@"name": @"ok"});
        NSArray *invalidErrors = PXRValidateSchema(schema, @{});
        if (validErrors.count != 0 || invalidErrors.count == 0) return 1;
        printf("Objective-C structured output example passed\n");
    }
    return 0;
}
