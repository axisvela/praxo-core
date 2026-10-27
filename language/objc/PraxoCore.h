#import <Foundation/Foundation.h>

#import "PraxoJSON.h"
#import "PraxoWire.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PXRCoreErrorDomain;
extern NSString *const PXRCodeKey;

typedef void (^PXREventSink)(NSDictionary<NSString *, id> *event);
typedef BOOL (^PXRModelGenerate)(NSDictionary<NSString *, id> *request,
                                 NSDictionary<NSString *, id> * _Nullable * _Nullable response,
                                 NSError **error);
typedef id _Nullable (^PXRToolInvoke)(NSDictionary<NSString *, id> *arguments,
                                      NSError **error);
typedef NSString * _Nullable (^PXRRepairer)(NSString *text);

NSError *PXRCoreError(NSString *code, NSString *message);
NSString *PXRCodeFromError(NSError * _Nullable error);

NSDictionary<NSString *, id> *PXRMessageCreate(NSString *role, NSString *content);
NSDictionary<NSString *, id> *PXRMessageAssistant(NSString *content,
                                                  NSArray<NSDictionary<NSString *, id> *> *toolCalls);
NSDictionary<NSString *, id> *PXRMessageTool(NSString *content, NSString *toolId);
NSDictionary<NSString *, id> *PXRToolCallCreate(NSString *identifier,
                                                NSString *name,
                                                NSDictionary<NSString *, id> *arguments);
NSDictionary<NSString *, id> *PXRToolSpecCreate(NSString *name, NSString *description);
NSDictionary<NSString *, id> *PXRUsageCreate(NSInteger inputTokens, NSInteger outputTokens);
NSDictionary<NSString *, id> *PXRUsageAdd(NSDictionary<NSString *, id> *left,
                                          NSDictionary<NSString *, id> *right);
NSDictionary<NSString *, id> *PXRRequestCreate(NSArray<NSDictionary<NSString *, id> *> *messages,
                                               NSArray<NSDictionary<NSString *, id> *> *tools);
NSDictionary<NSString *, id> *PXRResponseCreate(NSDictionary<NSString *, id> *message,
                                                NSDictionary<NSString *, id> *usage);
NSDictionary<NSString *, id> *PXRSessionCreate(NSString *identifier,
                                               NSArray<NSDictionary<NSString *, id> *> *messages);
NSDictionary<NSString *, id> *PXRRunResultCreate(NSString *runId,
                                                 NSString *output,
                                                 NSInteger steps,
                                                 NSDictionary<NSString *, id> *usage);
NSDictionary<NSString *, id> *PXRMemoryRecordCreate(NSString *identifier,
                                                    NSString *frame,
                                                    NSString *content,
                                                    NSString * _Nullable createdAt);
NSDictionary<NSString *, id> *PXRPathGrantCreate(NSString *root, NSString *access);
NSDictionary<NSString *, id> *PXRDecisionCreate(BOOL allowed, NSString *reason);
NSDictionary<NSString *, id> *PXREventCreate(NSString *type,
                                             NSString *sessionId,
                                             NSString * _Nullable runId,
                                             id _Nullable data);
NSDictionary<NSString *, id> *PXRContextBudgetCreate(NSInteger maxTokens, NSInteger keepRecent);
NSDictionary<NSString *, id> *PXRMessageWire(NSDictionary<NSString *, id> *message);
NSArray<NSString *> *PXRStreamKinds(void);

PXREventSink PXRMultiSink(NSArray<PXREventSink> *sinks);
PXREventSink PXRFilterSink(PXREventSink target, NSArray<NSString *> *predicateTypes);
void PXREmit(PXREventSink _Nullable sink, NSDictionary<NSString *, id> *event);

NSMutableDictionary<NSString *, id> *PXRMemoryStoreCreate(void);
void PXRMemoryPut(NSMutableDictionary<NSString *, id> *store,
                  NSString *sessionId,
                  NSDictionary<NSString *, id> *record);
NSArray<NSDictionary<NSString *, id> *> *PXRMemorySearch(NSMutableDictionary<NSString *, id> *store,
                                                         NSString *sessionId,
                                                         NSString *query,
                                                         NSInteger limit);

NSMutableSet<NSString *> *PXRCheckpointAllowlistCreate(void);
void PXRCheckpointRegister(NSMutableSet<NSString *> *allowlist, NSString *type);
NSString * _Nullable PXRCheckpointMarshal(NSMutableSet<NSString *> *allowlist,
                                          NSString *type,
                                          id value,
                                          NSError **error);
id _Nullable PXRCheckpointUnmarshal(NSMutableSet<NSString *> *allowlist,
                                    NSString *data,
                                    NSError **error);

NSArray<NSDictionary<NSString *, id> *> * _Nullable PXRPathCheckerCreate(
    NSArray<NSDictionary<NSString *, id> *> *grants, NSError **error);
NSDictionary<NSString *, id> * _Nullable PXRPathCheck(
    NSArray<NSDictionary<NSString *, id> *> *checker,
    NSString *target,
    NSString *need,
    NSError **error);
BOOL PXRPathAllowed(NSArray<NSDictionary<NSString *, id> *> *checker,
                    NSString *target,
                    NSString *need);

NSInteger PXREstimateTokens(NSArray<NSDictionary<NSString *, id> *> *messages);
NSArray<NSDictionary<NSString *, id> *> *PXRCompactContext(
    NSDictionary<NSString *, id> *budget,
    NSArray<NSDictionary<NSString *, id> *> *messages,
    BOOL *ok);

NSString *PXRPIIRedact(NSString *text);
id PXRRedactValue(id value);
NSDictionary<NSString *, id> *PXRStructuredOutputCreate(NSDictionary<NSString *, id> *schema,
                                                        NSInteger maxRepairs,
                                                        PXRRepairer _Nullable repairer);
NSString * _Nullable PXRStructuredApply(NSDictionary<NSString *, id> *config,
                                        NSString *text,
                                        NSError **error);
NSMutableDictionary<NSString *, id> *PXRCallLimitCreate(NSInteger modelLimit, NSInteger toolLimit);
BOOL PXRCallLimitModel(NSMutableDictionary<NSString *, id> *limit, NSError **error);
BOOL PXRCallLimitTool(NSMutableDictionary<NSString *, id> *limit, NSError **error);
NSMutableSet<NSString *> *PXRToolSelectionCreate(NSArray<NSString *> *selected);
NSArray<NSDictionary<NSString *, id> *> *PXRSelectTools(
    NSMutableSet<NSString *> *selection,
    NSArray<NSDictionary<NSString *, id> *> *tools);
BOOL PXRCheckToolSelected(NSMutableSet<NSString *> *selection,
                          NSString *name,
                          NSError **error);

PXRModelGenerate PXRModelCreateScripted(NSArray<NSDictionary<NSString *, id> *> *steps);
PXRModelGenerate PXRModelCreateStatic(NSString *content);
PXRModelGenerate PXRModelCreateFailing(void);
PXRModelGenerate PXRModelCreateFallback(PXRModelGenerate primary, PXRModelGenerate fallback);
NSDictionary<NSString *, id> *PXRToolCreate(NSString *name,
                                            NSString *description,
                                            PXRToolInvoke invoke);
NSMutableDictionary<NSString *, id> *PXRAgentOptionsCreate(PXRModelGenerate model);
NSDictionary<NSString *, id> * _Nullable PXRAgentRun(NSMutableDictionary<NSString *, id> *options,
                                                     NSDictionary<NSString *, id> *session,
                                                     NSString *prompt,
                                                     NSError **error);

NS_ASSUME_NONNULL_END
