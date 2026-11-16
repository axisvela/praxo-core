#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ServiceAuthErrorDomain;

typedef NS_ENUM(NSInteger, ServiceAuthErrorCode) {
    ServiceAuthErrorMissingToken = 1,
    ServiceAuthErrorRevocationFailed = 2,
};

@interface ServiceAuthPrincipal : NSObject

@property (nonatomic, readonly, copy) NSString *subject;
@property (nonatomic, readonly, copy) NSString *tenant;
@property (nonatomic, readonly) long long expires;

- (instancetype)initWithSubject:(NSString *)subject
                         tenant:(NSString *)tenant
                        expires:(long long)expires NS_DESIGNATED_INITIALIZER;

@end

@interface ServiceAuthResponse : NSObject

@property (nonatomic, readonly) NSInteger status;
@property (nonatomic, readonly, copy) NSString *body;

- (instancetype)initWithStatus:(NSInteger)status
                          body:(NSString *)body NS_DESIGNATED_INITIALIZER;

@end

typedef ServiceAuthResponse * _Nullable (^ServiceAuthTransport)(
    NSString *url,
    NSDictionary<NSString *, NSString *> *form,
    NSString * _Nullable authorization,
    NSError * _Nullable * _Nullable error);

@interface ServiceAuthIntrospectionAuthenticator : NSObject

- (instancetype)initWithTransport:(ServiceAuthTransport)transport
                         endpoint:(NSString *)endpoint
                         clientId:(NSString *)clientId
                     clientSecret:(NSString *)clientSecret
                      tenantClaim:(nullable NSString *)tenantClaim
    NS_DESIGNATED_INITIALIZER;

- (nullable ServiceAuthPrincipal *)authenticateAuthorization:
    (nullable NSString *)authorization
                                                         now:(long long)now;

@end

@interface ServiceAuthRevocationClient : NSObject

- (instancetype)initWithTransport:(ServiceAuthTransport)transport
                         endpoint:(NSString *)endpoint
                         clientId:(NSString *)clientId
                     clientSecret:(NSString *)clientSecret
    NS_DESIGNATED_INITIALIZER;

- (BOOL)revokeToken:(NSString *)token
              error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
