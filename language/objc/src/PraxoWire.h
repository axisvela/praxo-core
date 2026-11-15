#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PXRSpecVersion;
extern NSString *const PXRSDKVersion;
extern NSString *const PXRWireErrorDomain;

typedef NS_ENUM(NSInteger, PXRWireErrorCode) {
    PXRWireErrorInvalidJSON = 1,
    PXRWireErrorInvalidToolCall = 2,
    PXRWireErrorInvalidSchema = 3,
    PXRWireErrorInvalidManifest = 4,
};

FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXRParseInputJSON(NSString *raw);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXRParseToolCall(
    NSString *content, NSError **error);
FOUNDATION_EXPORT NSString *PXRStripToolCallMarkup(NSString *content);
FOUNDATION_EXPORT NSArray<NSString *> *PXRValidateSchema(
    NSDictionary<NSString *, id> *schema, id data);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXRParseManifest(
    NSString *raw, NSError **error);

NS_ASSUME_NONNULL_END
