#import <Foundation/Foundation.h>
#import "PraxoCore.h"

int main(void) {
    @autoreleasepool {
        NSMutableArray<NSString *> *allTypes = [NSMutableArray array];
        NSMutableArray<NSString *> *toolTypes = [NSMutableArray array];
        PXREventSink all = ^(NSDictionary *event) {
            [allTypes addObject:event[@"type"]];
        };
        PXREventSink tool = ^(NSDictionary *event) {
            [toolTypes addObject:event[@"type"]];
        };
        PXREventSink filter = PXRFilterSink(tool, @[@"tool.call"]);
        PXREventSink multi = PXRMultiSink(@[all, filter]);
        for (NSString *type in @[@"run.started", @"tool.call", @"run.completed"]) {
            multi(PXREventCreate(type, @"s1", nil, nil));
        }
        if (![allTypes isEqualToArray:@[@"run.started", @"tool.call", @"run.completed"]] ||
            ![toolTypes isEqualToArray:@[@"tool.call"]]) {
            return 1;
        }
        printf("Objective-C event sink example passed\n");
    }
    return 0;
}
