#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, id> *PXRSubagentRequest;
typedef NSDictionary<NSString *, id> *PXRSubagentResult;
typedef NSDictionary<NSString *, id> *PXRSubagentTask;

typedef NSDate * _Nullable (^PXRSubagentClock)(void);

typedef PXRSubagentResult _Nullable (^PXRSubagentRunner)(
    PXRSubagentRequest request,
    NSError **error);

FOUNDATION_EXPORT PXRSubagentRequest PXRSubagentRequestCreate(
    NSString *parentSessionId,
    NSString *agentId,
    NSString *prompt,
    NSString * _Nullable mode);

FOUNDATION_EXPORT PXRSubagentResult PXRSubagentResultCreate(
    NSString *taskId,
    NSString *agentId,
    NSString *output);

FOUNDATION_EXPORT PXRSubagentTask PXRSubagentTaskCreate(
    NSString *identifier,
    NSString *parentSessionId,
    NSString *agentId,
    NSString *mode,
    NSString *status,
    NSString *output,
    NSString *errorText,
    NSString *createdAt,
    NSString *updatedAt);

FOUNDATION_EXPORT PXRSubagentTask _Nullable PXRSubagentRun(
    PXRSubagentRequest request,
    PXRSubagentRunner _Nullable runner,
    PXRSubagentClock _Nullable clock,
    NSError **error);

NS_ASSUME_NONNULL_END
