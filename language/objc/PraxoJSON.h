#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PXRWireErrorDomain;

NSError *PXRError(NSInteger code, NSString *message);
BOOL PXRParseJSONText(NSString *text, id _Nullable * _Nullable value, NSError **error);
NSString * _Nullable PXRJSONText(id value, NSError **error);
BOOL PXRJSONEqual(id left, id right);
BOOL PXRStringHasPrefix(NSString *text, NSString *prefix);
BOOL PXRStringHasSuffix(NSString *text, NSString *suffix);
BOOL PXRIsBooleanValue(id value);
BOOL PXRIsNumberValue(id value);
NSUInteger PXRCodePointCount(NSString *text);
BOOL PXRMatchesPattern(NSString *pattern, NSString *text);
BOOL PXRMatchesFull(NSString *pattern, NSString *text);
NSString *PXRChildPath(NSString *base, NSString *key);
NSString *PXRIndexPath(NSString *base, NSUInteger index);

NS_ASSUME_NONNULL_END
