#import "PraxoRetriever.h"

#import "PraxoCore.h"

PXDocument PXDocumentCreate(
    NSString *identifier,
    NSString *content,
    NSDictionary<NSString *, id> *metadata,
    NSNumber *score) {
    NSMutableDictionary<NSString *, id> *document = [NSMutableDictionary dictionary];
    document[@"id"] = identifier ?: @"";
    document[@"content"] = content ?: @"";
    if (metadata != nil) {
        document[@"metadata"] = metadata;
    }
    if (score != nil) {
        document[@"score"] = score;
    }
    return document;
}

NSArray<PXDocument> *PXRetrieveDocuments(
    PXRetriever retriever,
    NSString *query,
    NSInteger limit,
    NSError **error) {
    if (limit < 0) {
        if (error != NULL) {
            *error = PXRCoreError(@"RETRIEVER_INVALID", @"retriever: invalid limit");
        }
        return nil;
    }
    if (retriever == nil) {
        if (error != NULL) {
            *error = PXRCoreError(@"RETRIEVER_INVALID", @"retriever: retriever is required");
        }
        return nil;
    }
    NSError *retrieveError = nil;
    NSArray<PXDocument> *documents = retriever(query ?: @"", limit, &retrieveError);
    if (retrieveError != nil) {
        if (error != NULL) {
            *error = retrieveError;
        }
        return nil;
    }
    return documents ?: @[];
}
