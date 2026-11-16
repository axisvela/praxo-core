#import "authentication.h"

#import <math.h>
#import <objc/runtime.h>
#import <string.h>

#if defined(__APPLE__)
#import <CoreFoundation/CoreFoundation.h>
#endif

NSString *const ServiceAuthErrorDomain = @"io.axisvela.praxo.service.auth";

@implementation ServiceAuthPrincipal

- (instancetype)initWithSubject:(NSString *)subject
                         tenant:(NSString *)tenant
                        expires:(long long)expires {
    self = [super init];
    if (self != nil) {
        _subject = [subject copy];
        _tenant = [tenant copy];
        _expires = expires;
    }
    return self;
}

@end

@implementation ServiceAuthResponse

- (instancetype)initWithStatus:(NSInteger)status body:(NSString *)body {
    self = [super init];
    if (self != nil) {
        _status = status;
        _body = [body copy];
    }
    return self;
}

@end

@interface ServiceAuthIntrospectionAuthenticator ()

@property (nonatomic, copy) ServiceAuthTransport transport;
@property (nonatomic, copy) NSString *endpoint;
@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *clientSecret;
@property (nonatomic, copy) NSString *tenantClaim;

@end

@interface ServiceAuthRevocationClient ()

@property (nonatomic, copy) ServiceAuthTransport transport;
@property (nonatomic, copy) NSString *endpoint;
@property (nonatomic, copy) NSString *clientId;
@property (nonatomic, copy) NSString *clientSecret;

@end

static BOOL ServiceAuthObjectIsKindOfClass(id value, Class target) {
    if (value == nil) {
        return NO;
    }
    for (Class type = object_getClass(value); type != Nil;
            type = class_getSuperclass(type)) {
        if (type == target) {
            return YES;
        }
    }
    return NO;
}

static BOOL ServiceAuthIsBoolean(id value) {
    if (!ServiceAuthObjectIsKindOfClass(value, [NSNumber class])) {
        return NO;
    }
#if defined(__APPLE__)
    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
#else
    const char *name = [NSStringFromClass([value class]) UTF8String];
    return name != NULL && strstr(name, "Bool") != NULL;
#endif
}

static NSError *ServiceAuthError(ServiceAuthErrorCode code, NSString *message) {
    return [NSError errorWithDomain:ServiceAuthErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation ServiceAuthIntrospectionAuthenticator

- (instancetype)initWithTransport:(ServiceAuthTransport)transport
                         endpoint:(NSString *)endpoint
                         clientId:(NSString *)clientId
                     clientSecret:(NSString *)clientSecret
                      tenantClaim:(nullable NSString *)tenantClaim {
    self = [super init];
    if (self != nil) {
        _transport = [transport copy];
        _endpoint = [endpoint copy];
        _clientId = [clientId copy];
        _clientSecret = [clientSecret copy];
        _tenantClaim = tenantClaim.length > 0 ? [tenantClaim copy] : @"tenant";
    }
    return self;
}

- (nullable NSString *)basicAuthorization {
    if (self.clientId.length == 0) {
        return nil;
    }
    NSString *raw = [NSString stringWithFormat:@"%@:%@",
                     self.clientId, self.clientSecret];
    NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
    return [@"Basic " stringByAppendingString:
        [data base64EncodedStringWithOptions:0]];
}

- (nullable ServiceAuthPrincipal *)authenticateAuthorization:
    (nullable NSString *)authorization
                                                         now:(long long)now {
    const char *authorizationText =
        authorization == nil ? NULL : [authorization UTF8String];
    if (authorizationText == NULL ||
            strncmp(authorizationText, "Bearer ", 7) != 0) {
        return nil;
    }
    NSString *token = [[authorization substringFromIndex:7]
        stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (token.length == 0) {
        return nil;
    }
    NSDictionary<NSString *, NSString *> *form = @{
        @"token": token,
        @"client_id": self.clientId,
        @"client_secret": self.clientSecret,
    };
    NSError *error = nil;
    ServiceAuthResponse *response = self.transport(self.endpoint, form,
        [self basicAuthorization], &error);
    if (response == nil || response.status != 200) {
        return nil;
    }
    NSData *data = [response.body dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return nil;
    }
    id payload = [NSJSONSerialization JSONObjectWithData:data
                                                 options:0
                                                   error:&error];
    if (!ServiceAuthObjectIsKindOfClass(payload, [NSDictionary class])) {
        return nil;
    }
    NSDictionary *object = (NSDictionary *)payload;
    id active = object[@"active"];
    if (!ServiceAuthIsBoolean(active) ||
            [(NSNumber *)active intValue] == 0) {
        return nil;
    }
    id subject = object[@"sub"];
    id tenant = object[self.tenantClaim];
    id expires = object[@"exp"];
    if (!ServiceAuthObjectIsKindOfClass(subject, [NSString class]) ||
            [subject length] == 0) {
        return nil;
    }
    if (!ServiceAuthObjectIsKindOfClass(tenant, [NSString class]) ||
            [tenant length] == 0) {
        return nil;
    }
    if (!ServiceAuthObjectIsKindOfClass(expires, [NSNumber class]) ||
            ServiceAuthIsBoolean(expires)) {
        return nil;
    }
    double expiresNumber = [(NSNumber *)expires doubleValue];
    if (!isfinite(expiresNumber) || floor(expiresNumber) != expiresNumber) {
        return nil;
    }
    if (expiresNumber <= (double)now) {
        return nil;
    }
    if (expiresNumber < -9223372036854775808.0 ||
            expiresNumber >= 9223372036854775808.0) {
        return nil;
    }
    return [[ServiceAuthPrincipal alloc] initWithSubject:subject
                                                 tenant:tenant
                                                expires:(long long)expiresNumber];
}

@end

@implementation ServiceAuthRevocationClient

- (instancetype)initWithTransport:(ServiceAuthTransport)transport
                         endpoint:(NSString *)endpoint
                         clientId:(NSString *)clientId
                     clientSecret:(NSString *)clientSecret {
    self = [super init];
    if (self != nil) {
        _transport = [transport copy];
        _endpoint = [endpoint copy];
        _clientId = [clientId copy];
        _clientSecret = [clientSecret copy];
    }
    return self;
}

- (nullable NSString *)basicAuthorization {
    if (self.clientId.length == 0) {
        return nil;
    }
    NSString *raw = [NSString stringWithFormat:@"%@:%@",
                     self.clientId, self.clientSecret];
    NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
    return [@"Basic " stringByAppendingString:
        [data base64EncodedStringWithOptions:0]];
}

- (BOOL)revokeToken:(NSString *)token
              error:(NSError * _Nullable * _Nullable)error {
    if (token.length == 0) {
        if (error != NULL) {
            *error = ServiceAuthError(ServiceAuthErrorMissingToken,
                                      @"revocation token is required");
        }
        return NO;
    }
    NSDictionary<NSString *, NSString *> *form = @{
        @"token": token,
        @"token_type_hint": @"access_token",
        @"client_id": self.clientId,
        @"client_secret": self.clientSecret,
    };
    NSError *transportError = nil;
    ServiceAuthResponse *response = self.transport(self.endpoint, form,
        [self basicAuthorization], &transportError);
    if (response == nil || response.status != 200) {
        if (error != NULL) {
            *error = ServiceAuthError(ServiceAuthErrorRevocationFailed,
                                      @"token revocation failed");
        }
        return NO;
    }
    return YES;
}

@end
