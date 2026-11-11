#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoOpenAI.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXRGeminiRequestPayload(
    NSArray<NSDictionary<NSString *, id> *> *messages,
    NSArray<NSDictionary<NSString *, id> *> *tools,
    NSString * _Nullable toolChoice,
    NSInteger maxOutputTokens);

FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXRGeminiParseResponse(
    NSDictionary<NSString *, id> *data, NSError **error);

FOUNDATION_EXPORT BOOL PXRGeminiGenerate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    NSInteger maxOutputTokens,
    NSDictionary<NSString *, id> *request,
    PXROpenAITransport _Nullable transport,
    NSDictionary<NSString *, id> * _Nullable * _Nullable response,
    NSError **error);

FOUNDATION_EXPORT PXRModelGenerate PXRGeminiModelCreate(
    NSString *baseURL,
    NSString *model,
    NSString * _Nullable apiKey,
    NSInteger maxOutputTokens,
    PXROpenAITransport _Nullable transport);

NS_ASSUME_NONNULL_END
