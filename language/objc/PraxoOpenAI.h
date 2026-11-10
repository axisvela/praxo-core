#import <Foundation/Foundation.h>

#import "PraxoCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^PXROpenAITransport)(NSString *path,
                                   NSDictionary<NSString *, id> *payload,
                                   NSInteger *statusCode,
                                   NSString * _Nullable * _Nullable responseBody,
                                   NSError **error);

FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXROpenAIRequestPayload(
    NSString *model,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString * _Nullable toolChoice);

FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXROpenAIParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error);

FOUNDATION_EXPORT BOOL PXROpenAIGenerate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport _Nullable transport,
    NSDictionary<NSString *, id> * _Nullable * _Nullable response,
    NSError **error);

FOUNDATION_EXPORT PXRModelGenerate PXROpenAIModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    PXROpenAITransport _Nullable transport);

NS_ASSUME_NONNULL_END
