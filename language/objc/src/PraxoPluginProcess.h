#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PXRPluginProcessErrorDomain;

@interface PXRPluginProcessConfig : NSObject
@property(nonatomic, copy) NSString *pluginId;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *argument;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, assign) double startTimeout;
@property(nonatomic, assign) double invokeTimeout;
- (instancetype)initWithPluginId:(NSString *)pluginId
                            path:(NSString *)path;
@end

@interface PXRPluginProcess : NSObject
@property(nonatomic, readonly, getter=isActive) BOOL active;
- (instancetype)initWithConfig:(PXRPluginProcessConfig *)config;
- (BOOL)start:(NSError **)error;
- (nullable NSString *)invoke:(NSString *)service
                       method:(NSString *)method
                      payload:(NSString *)payload
                        error:(NSError **)error;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
