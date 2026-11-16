#import "authentication.h"

#import <Foundation/Foundation.h>
#import <stdio.h>

static int failures = 0;

#define CHECK(condition) \
    do { \
        if (!(condition)) { \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #condition); \
            failures += 1; \
        } \
    } while (0)

static const long long kNow = 1700000000;

static NSString *ValidBody(void) {
    return @"{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
            "\"exp\":1700000060}";
}

static BOOL StringEquals(NSString *left, NSString *right) {
    if (left == nil || right == nil) {
        return left == right;
    }
    return [left compare:right] == NSOrderedSame;
}

static ServiceAuthTransport FakeTransport(NSMutableArray *calls,
                                          NSInteger status,
                                          NSString *body,
                                          BOOL fail) {
    return ^ServiceAuthResponse *(NSString *url,
                                  NSDictionary<NSString *, NSString *> *form,
                                  NSString *authorization,
                                  NSError **error) {
        NSMutableDictionary *call = [NSMutableDictionary dictionary];
        call[@"url"] = url;
        call[@"form"] = form;
        if (authorization != nil) {
            call[@"authorization"] = authorization;
        }
        [calls addObject:call];
        if (fail) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:@"test"
                                             code:1
                                         userInfo:nil];
            }
            return nil;
        }
        return [[ServiceAuthResponse alloc] initWithStatus:status body:body];
    };
}

static void expectRejected(NSString *body, NSInteger status, BOOL fail) {
    NSMutableArray *calls = [NSMutableArray array];
    ServiceAuthIntrospectionAuthenticator *auth =
        [[ServiceAuthIntrospectionAuthenticator alloc]
            initWithTransport:FakeTransport(calls, status, body, fail)
                     endpoint:@"https://idp.example/introspect"
                     clientId:@""
                 clientSecret:@""
                  tenantClaim:nil];
    ServiceAuthPrincipal *principal =
        [auth authenticateAuthorization:@"Bearer token-1" now:kNow];
    CHECK(principal == nil);
}

static void testSuccess(void) {
    NSMutableArray *calls = [NSMutableArray array];
    ServiceAuthIntrospectionAuthenticator *auth =
        [[ServiceAuthIntrospectionAuthenticator alloc]
            initWithTransport:FakeTransport(calls, 200, ValidBody(), NO)
                     endpoint:@"https://idp.example/introspect"
                     clientId:@"svc"
                 clientSecret:@"secret"
                  tenantClaim:nil];
    ServiceAuthPrincipal *principal =
        [auth authenticateAuthorization:@"Bearer token-1" now:kNow];
    CHECK(principal != nil);
    CHECK(StringEquals(principal.subject, @"user-1"));
    CHECK(StringEquals(principal.tenant, @"tenant-a"));
    CHECK(principal.expires == kNow + 60);
    CHECK(calls.count == 1);
    NSDictionary *call = calls.firstObject;
    CHECK(StringEquals(call[@"url"], @"https://idp.example/introspect"));
    CHECK(StringEquals(call[@"form"][@"token"], @"token-1"));
    CHECK(StringEquals(call[@"form"][@"client_id"], @"svc"));
    CHECK(StringEquals(call[@"form"][@"client_secret"], @"secret"));
    CHECK(StringEquals(call[@"authorization"], @"Basic c3ZjOnNlY3JldA=="));
}

static void testLocalRejections(void) {
    NSMutableArray *calls = [NSMutableArray array];
    ServiceAuthIntrospectionAuthenticator *auth =
        [[ServiceAuthIntrospectionAuthenticator alloc]
            initWithTransport:FakeTransport(calls, 200, ValidBody(), NO)
                     endpoint:@"https://idp.example/introspect"
                     clientId:@"svc"
                 clientSecret:@"secret"
                  tenantClaim:nil];
    CHECK([auth authenticateAuthorization:nil now:kNow] == nil);
    CHECK([auth authenticateAuthorization:@"Basic token" now:kNow] == nil);
    CHECK([auth authenticateAuthorization:@"Bearer   " now:kNow] == nil);
    CHECK(calls.count == 0);
}

static void testRejectedBodies(void) {
    expectRejected(@"{\"active\":false,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\",\"exp\":1700000060}", 200, NO);
    expectRejected(@"{\"active\":true,\"tenant\":\"tenant-a\","
                   "\"exp\":1700000060}", 200, NO);
    expectRejected(@"{\"active\":true,\"sub\":\"\",\"tenant\":\"tenant-a\","
                   "\"exp\":1700000060}", 200, NO);
    expectRejected(@"{\"active\":true,\"sub\":\"user-1\","
                   "\"exp\":1700000060}", 200, NO);
    expectRejected(@"{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"\","
                   "\"exp\":1700000060}", 200, NO);
    expectRejected(@"{\"active\":true,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\",\"exp\":1700000000}", 200, NO);
    expectRejected(@"{\"active\":true,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\"}", 200, NO);
    expectRejected(@"not-json", 200, NO);
    expectRejected(ValidBody(), 500, NO);
    expectRejected(ValidBody(), 200, YES);
}

static void testNoBasicWithoutClientId(void) {
    NSMutableArray *calls = [NSMutableArray array];
    ServiceAuthIntrospectionAuthenticator *auth =
        [[ServiceAuthIntrospectionAuthenticator alloc]
            initWithTransport:FakeTransport(calls, 200, ValidBody(), NO)
                     endpoint:@"https://idp.example/introspect"
                     clientId:@""
                 clientSecret:@""
                  tenantClaim:nil];
    ServiceAuthPrincipal *principal =
        [auth authenticateAuthorization:@"Bearer token-1" now:kNow];
    CHECK(principal != nil);
    NSDictionary *call = calls.firstObject;
    CHECK(call[@"authorization"] == nil);
}

static void testCustomTenantClaim(void) {
    NSMutableArray *calls = [NSMutableArray array];
    NSString *body = @"{\"active\":true,\"sub\":\"user-1\",\"org\":\"org-a\","
                      "\"exp\":1700000060}";
    ServiceAuthIntrospectionAuthenticator *auth =
        [[ServiceAuthIntrospectionAuthenticator alloc]
            initWithTransport:FakeTransport(calls, 200, body, NO)
                     endpoint:@"https://idp.example/introspect"
                     clientId:@""
                 clientSecret:@""
                  tenantClaim:@"org"];
    ServiceAuthPrincipal *principal =
        [auth authenticateAuthorization:@"Bearer token-1" now:kNow];
    CHECK(principal != nil);
    CHECK(StringEquals(principal.tenant, @"org-a"));
}

static void testRevocation(void) {
    NSMutableArray *calls = [NSMutableArray array];
    ServiceAuthRevocationClient *client =
        [[ServiceAuthRevocationClient alloc]
            initWithTransport:FakeTransport(calls, 200, @"", NO)
                     endpoint:@"https://idp.example/revoke"
                     clientId:@"svc"
                 clientSecret:@"secret"];
    NSError *error = nil;
    CHECK([client revokeToken:@"token-1" error:&error]);
    CHECK(error == nil);
    CHECK(calls.count == 1);
    NSDictionary *call = calls.firstObject;
    CHECK(StringEquals(call[@"form"][@"token"], @"token-1"));
    CHECK(StringEquals(call[@"form"][@"token_type_hint"], @"access_token"));
    CHECK(StringEquals(call[@"form"][@"client_id"], @"svc"));
    CHECK(StringEquals(call[@"form"][@"client_secret"], @"secret"));
    CHECK(StringEquals(call[@"authorization"], @"Basic c3ZjOnNlY3JldA=="));

    NSMutableArray *statusCalls = [NSMutableArray array];
    ServiceAuthRevocationClient *rejected =
        [[ServiceAuthRevocationClient alloc]
            initWithTransport:FakeTransport(statusCalls, 400, @"", NO)
                     endpoint:@"https://idp.example/revoke"
                     clientId:@"svc"
                 clientSecret:@"secret"];
    error = nil;
    CHECK(![rejected revokeToken:@"token-1" error:&error]);
    CHECK(error.code == ServiceAuthErrorRevocationFailed);

    NSMutableArray *errorCalls = [NSMutableArray array];
    ServiceAuthRevocationClient *failing =
        [[ServiceAuthRevocationClient alloc]
            initWithTransport:FakeTransport(errorCalls, 200, @"", YES)
                     endpoint:@"https://idp.example/revoke"
                     clientId:@"svc"
                 clientSecret:@"secret"];
    error = nil;
    CHECK(![failing revokeToken:@"token-1" error:&error]);
    CHECK(error.code == ServiceAuthErrorRevocationFailed);

    NSMutableArray *localCalls = [NSMutableArray array];
    ServiceAuthRevocationClient *local =
        [[ServiceAuthRevocationClient alloc]
            initWithTransport:FakeTransport(localCalls, 200, @"", NO)
                     endpoint:@"https://idp.example/revoke"
                     clientId:@"svc"
                 clientSecret:@"secret"];
    error = nil;
    CHECK(![local revokeToken:@"" error:&error]);
    CHECK(error.code == ServiceAuthErrorMissingToken);
    CHECK(localCalls.count == 0);
}

int main(void) {
    @autoreleasepool {
        testSuccess();
        testLocalRejections();
        testRejectedBodies();
        testNoBasicWithoutClientId();
        testCustomTenantClaim();
        testRevocation();
        if (failures != 0) {
            return 1;
        }
        printf("Objective-C service auth tests passed\n");
    }
    return 0;
}
