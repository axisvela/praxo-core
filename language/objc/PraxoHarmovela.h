#import <Foundation/Foundation.h>

#import "PraxoCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, id> * _Nullable (^PXRHarmovelaTransport)(
    NSString *method,
    NSString *url,
    NSDictionary<NSString *, id> *headers,
    NSData *body,
    NSError **error);

typedef NSDate * _Nullable (^PXRHarmovelaClock)(void);

FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXRHarmovelaEnvelope(
    NSDictionary<NSString *, id> *event,
    NSString *source,
    NSString *specVersion,
    NSDate *at);

FOUNDATION_EXPORT BOOL PXRHarmovelaSend(
    NSString *baseURL,
    NSDictionary<NSString *, id> *event,
    NSString *source,
    NSString *specVersion,
    PXRHarmovelaTransport _Nullable transport,
    PXRHarmovelaClock _Nullable clock,
    NSError **error);

FOUNDATION_EXPORT PXREventSink PXRHarmovelaSink(
    NSString *baseURL,
    NSString *source,
    NSString *specVersion,
    PXRHarmovelaTransport _Nullable transport,
    PXRHarmovelaClock _Nullable clock);

NS_ASSUME_NONNULL_END
