#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, id> *PXDocument;

typedef NSArray<PXDocument> * _Nullable (^PXRetriever)(
    NSString *query,
    NSInteger limit,
    NSError **error);

FOUNDATION_EXPORT PXDocument PXDocumentCreate(
    NSString *identifier,
    NSString *content,
    NSDictionary<NSString *, id> * _Nullable metadata,
    NSNumber * _Nullable score);

FOUNDATION_EXPORT NSArray<PXDocument> * _Nullable PXRetrieveDocuments(
    PXRetriever _Nullable retriever,
    NSString *query,
    NSInteger limit,
    NSError **error);

NS_ASSUME_NONNULL_END
