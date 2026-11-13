#import <Foundation/Foundation.h>

#import "PraxoCore.h"
#import "PraxoRetriever.h"

void runRetrieverTests(void (*check)(BOOL, NSString *)) {
    PXDocument document = PXDocumentCreate(@"doc-1", @"content",
                                           @{@"source": @"unit"}, @0.5);
    check([document[@"id"] isEqualToString:@"doc-1"], @"retriever document id");
    check([document[@"content"] isEqualToString:@"content"], @"retriever document content");
    check([document[@"metadata"][@"source"] isEqualToString:@"unit"],
          @"retriever document metadata");
    check([document[@"score"] doubleValue] == 0.5, @"retriever document score");

    __block NSUInteger calls = 0;
    __block NSString *seenQuery = nil;
    __block NSInteger seenLimit = 0;
    PXRetriever retriever = ^NSArray<PXDocument> *(
        NSString *query, NSInteger limit, NSError **error) {
        (void)error;
        calls++;
        seenQuery = query;
        seenLimit = limit;
        return @[PXDocumentCreate(@"doc-1",
                                  [NSString stringWithFormat:@"%@:%ld", query, (long)limit],
                                  nil, nil)];
    };
    NSError *error = nil;
    NSArray<PXDocument> *documents = PXRetrieveDocuments(retriever, @"hello", 3, &error);
    check(error == nil, @"retriever success error");
    check(documents.count == 1, @"retriever document count");
    check([documents.firstObject[@"content"] isEqualToString:@"hello:3"],
          @"retriever query and limit");
    check(calls == 1, @"retriever single invocation");
    check([seenQuery isEqualToString:@"hello"], @"retriever query forwarding");
    check(seenLimit == 3, @"retriever limit forwarding");

    error = nil;
    documents = PXRetrieveDocuments(retriever, @"hello", -1, &error);
    check(documents == nil, @"retriever negative limit fails");
    check([PXRCodeFromError(error) isEqualToString:@"RETRIEVER_INVALID"],
          @"retriever negative limit error");
    check(calls == 1, @"retriever negative limit does not invoke");

    error = nil;
    documents = PXRetrieveDocuments(nil, @"hello", 1, &error);
    check(documents == nil, @"retriever missing callback fails");
    check([PXRCodeFromError(error) isEqualToString:@"RETRIEVER_INVALID"],
          @"retriever missing callback error");

    error = nil;
    PXRetriever empty = ^NSArray<PXDocument> *(
        NSString *query, NSInteger limit, NSError **retrieveError) {
        (void)query;
        (void)limit;
        (void)retrieveError;
        return nil;
    };
    documents = PXRetrieveDocuments(empty, @"hello", 0, &error);
    check(documents != nil && documents.count == 0 && error == nil,
          @"retriever nil result becomes empty");

    error = nil;
    PXRetriever failing = ^NSArray<PXDocument> *(
        NSString *query, NSInteger limit, NSError **retrieveError) {
        (void)query;
        (void)limit;
        if (retrieveError != NULL) {
            *retrieveError = PXRCoreError(@"RETRIEVER_FAILED", @"retriever failed");
        }
        return nil;
    };
    documents = PXRetrieveDocuments(failing, @"hello", 1, &error);
    check(documents == nil, @"retriever callback error fails");
    check([PXRCodeFromError(error) isEqualToString:@"RETRIEVER_FAILED"],
          @"retriever callback error preserved");
}
