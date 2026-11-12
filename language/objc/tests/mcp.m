#import <Foundation/Foundation.h>

#import "PraxoMCP.h"

@interface FakeMcpTransport : NSObject <PXRMcpTransport>
@property (nonatomic) BOOL closed;
@property (nonatomic, copy) NSString *notified;
@end

@implementation FakeMcpTransport

- (NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                         params:(NSDictionary<NSString *, id> *)params
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    (void)params;
    (void)timeout;
    (void)error;
    if ([method isEqual:@"initialize"]) {
        return @{
            @"protocolVersion": @"2025-03-26",
            @"serverInfo": @{@"name": @"fake-http"},
        };
    }
    if ([method isEqual:@"tools/list"]) {
        return @{
            @"tools": @[
                @{
                    @"name": @"echo",
                    @"description": @"Echo input",
                    @"inputSchema": @{@"type": @"object"},
                },
            ],
        };
    }
    if ([method isEqual:@"tools/call"]) {
        return @{
            @"content": @[@{@"type": @"text", @"text": @"http-ok"}],
        };
    }
    return @{};
}

- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error {
    (void)params;
    (void)error;
    self.notified = method;
    return YES;
}

- (void)close {
    self.closed = YES;
}

@end

void runMcpTests(void (*check)(BOOL, NSString *)) {
    FakeMcpTransport *transport = [[FakeMcpTransport alloc] init];
    PXRMcpClient *client = [[PXRMcpClient alloc]
        initWithTransport:transport
          protocolVersion:@"2025-03-26"
            clientVersion:@"0.3.0"
                  timeout:5.0];
    NSError *error = nil;
    check([client start:&error], @"mcp start");
    check([client.protocolVersion isEqual:@"2025-03-26"],
          @"mcp protocol version");
    check([transport.notified isEqual:@"notifications/initialized"],
          @"mcp notify");
    NSArray<NSDictionary<NSString *, id> *> *tools = [client listTools:&error];
    check(tools.count == 1, @"mcp tools");
    check([tools[0][@"name"] isEqual:@"echo"], @"mcp tool name");
    id result = [client callTool:@"echo" arguments:@{@"text": @"hi"} error:&error];
    check([result isEqual:@"http-ok"], @"mcp call");
    [client close];
    check(transport.closed, @"mcp close");

    NSError *rejected = nil;
    PXRHttpMcpTransport *transportRejected = [[PXRHttpMcpTransport alloc]
        initWithEndpoint:@"http://example.com/mcp"
                 headers:nil
         protocolVersion:@"2025-03-26"
                 timeout:5.0
                   error:&rejected];
    check(transportRejected == nil, @"mcp https transport nil");
    check(rejected != nil, @"mcp https error");
}
