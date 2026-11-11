#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoOpenAI.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXRAnthropicRequestPayload(
    NSString *model,
    NSInteger maxTokens,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString * _Nullable toolChoice);

FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXRAnthropicParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error);

FOUNDATION_EXPORT BOOL PXRAnthropicGenerate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    NSString * _Nullable version,
    NSInteger maxTokens,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport _Nullable transport,
    NSDictionary<NSString *, id> * _Nullable * _Nullable response,
    NSError **error);

FOUNDATION_EXPORT PXRModelGenerate PXRAnthropicModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    NSString * _Nullable version,
    NSInteger maxTokens,
    PXROpenAITransport _Nullable transport);

NS_ASSUME_NONNULL_END
