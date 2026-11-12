#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PXRMcpTransport <NSObject>
- (nullable NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                                   params:(NSDictionary<NSString *, id> *)params
                                                  timeout:(NSTimeInterval)timeout
                                                    error:(NSError **)error;
- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error;
- (void)close;
@end

@interface PXRMcpClient : NSObject
@property (nonatomic, readonly, copy) NSString *protocolVersion;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *serverInfo;

- (instancetype)initWithTransport:(id<PXRMcpTransport>)transport
                  protocolVersion:(NSString *)protocolVersion
                    clientVersion:(NSString *)clientVersion
                          timeout:(NSTimeInterval)timeout;
- (BOOL)start:(NSError **)error;
- (nullable NSArray<NSDictionary<NSString *, id> *> *)listTools:(NSError **)error;
- (nullable id)callTool:(NSString *)name
              arguments:(NSDictionary<NSString *, id> *)arguments
                  error:(NSError **)error;
- (void)close;
@end

@interface PXRStdioMcpTransport : NSObject <PXRMcpTransport>
- (instancetype)initWithCommand:(NSString *)command
                           args:(NSArray<NSString *> *)args;
@end

@interface PXRHttpMcpTransport : NSObject <PXRMcpTransport>
- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                                  headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                          protocolVersion:(NSString *)protocolVersion
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
