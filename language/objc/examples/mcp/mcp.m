#import <Foundation/Foundation.h>
#import "PraxoMCP.h"

@interface FakeTransport : NSObject <PXRMcpTransport>
@end

@implementation FakeTransport

- (NSDictionary *)requestMethod:(NSString *)method
                         params:(NSDictionary *)params
                        timeout:(NSTimeInterval)timeout
                          error:(NSError **)error {
    if ([method isEqualToString:@"initialize"]) {
        return @{@"protocolVersion": @"2024-11-05", @"serverInfo": @{@"name": @"example-mcp"}};
    }
    if ([method isEqualToString:@"tools/list"]) {
        return @{@"tools": @[@{@"name": @"echo"}, @{@"name": @"add"}]};
    }
    if ([method isEqualToString:@"tools/call"]) {
        return @{@"structuredContent": @{@"sum": @5}};
    }
    return @{};
}

- (void)notifyMethod:(NSString *)method params:(NSDictionary *)params {}
- (void)close {}

@end

int main(void) {
    @autoreleasepool {
        FakeTransport *transport = [FakeTransport new];
        PXRMcpClient *client = [[PXRMcpClient alloc] initWithTransport:transport];
        NSError *error = nil;
        if (![client start:&error]) return 1;
        NSArray *tools = [client listTools:&error];
        id result = [client callTool:@"add" arguments:@{} error:&error];
        [client close];
        if (tools.count != 2 || ![result[@"sum"] isEqual:@5]) return 1;
        printf("Objective-C MCP example passed\n");
    }
    return 0;
}
