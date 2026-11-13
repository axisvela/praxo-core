#import <Foundation/Foundation.h>

#import "PraxoCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, id> * _Nullable (^PXROtelTransport)(
    NSString *method,
    NSString *url,
    NSDictionary<NSString *, NSString *> *headers,
    NSData *body,
    NSError **error);

typedef long long (^PXROtelClock)(void);

FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXROtelPayload(
    NSDictionary<NSString *, id> *event,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    long long nanoseconds);

FOUNDATION_EXPORT BOOL PXROtelSend(
    NSString *endpoint,
    NSDictionary<NSString *, id> *event,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    PXROtelTransport _Nullable transport,
    PXROtelClock _Nullable clock,
    NSError **error);

FOUNDATION_EXPORT PXREventSink PXROtelSink(
    NSString *endpoint,
    NSString *serviceName,
    NSArray<NSString *> *allowedDataKeys,
    PXROtelTransport _Nullable transport,
    PXROtelClock _Nullable clock);

NS_ASSUME_NONNULL_END
