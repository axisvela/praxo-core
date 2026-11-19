#import "PraxoPluginProcess.h"

extern int px_plugin_process_start_simple(const char *plugin_id,
                                          const char *path,
                                          const char *arg,
                                          const char *token,
                                          void **handle,
                                          char *error,
                                          size_t error_size);
extern int px_plugin_process_invoke_simple(void *handle,
                                           const char *service,
                                           const char *method,
                                           const char *payload,
                                           char *response,
                                           size_t response_size,
                                           char *error,
                                           size_t error_size);
extern void px_plugin_process_stop_simple(void *handle);

NSString *const PXRPluginProcessErrorDomain = @"PraxoPluginProcess";

@implementation PXRPluginProcessConfig

- (instancetype)initWithPluginId:(NSString *)pluginId
                            path:(NSString *)path {
    self = [super init];
    if (self != nil) {
        _pluginId = [pluginId copy];
        _path = [path copy];
        _argument = @"";
        _token = @"";
        _startTimeout = 10.0;
        _invokeTimeout = 30.0;
    }
    return self;
}

@end

@implementation PXRPluginProcess {
    PXRPluginProcessConfig *_config;
    void *_handle;
    BOOL _active;
}

- (instancetype)initWithConfig:(PXRPluginProcessConfig *)config {
    self = [super init];
    if (self != nil) {
        _config = config;
    }
    return self;
}

- (BOOL)isActive {
    return _active;
}

static NSError *PXRPluginError(NSString *message) {
    return [NSError errorWithDomain:PXRPluginProcessErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (BOOL)start:(NSError **)error {
    if (_handle != NULL) {
        if (error != NULL) {
            *error = PXRPluginError(@"plugin: host already started");
        }
        return NO;
    }
    char errorBuffer[256] = {0};
    void *handle = NULL;
    int ok = px_plugin_process_start_simple(
        _config.pluginId.UTF8String, _config.path.UTF8String,
        _config.argument.UTF8String, _config.token.UTF8String, &handle,
        errorBuffer, sizeof(errorBuffer));
    if (ok == 0 || handle == NULL) {
        if (error != NULL) {
            *error = PXRPluginError([NSString stringWithUTF8String:errorBuffer]);
        }
        return NO;
    }
    _handle = handle;
    _active = YES;
    return YES;
}

- (NSString *)invoke:(NSString *)service
              method:(NSString *)method
             payload:(NSString *)payload
               error:(NSError **)error {
    if (!_active || _handle == NULL) {
        if (error != NULL) {
            *error = PXRPluginError(@"plugin: host is not active");
        }
        return nil;
    }
    char response[8192] = {0};
    char errorBuffer[256] = {0};
    int ok = px_plugin_process_invoke_simple(
        _handle, service.UTF8String, method.UTF8String, payload.UTF8String,
        response, sizeof(response), errorBuffer, sizeof(errorBuffer));
    if (ok == 0) {
        if (error != NULL) {
            *error = PXRPluginError([NSString stringWithUTF8String:errorBuffer]);
        }
        return nil;
    }
    return [NSString stringWithUTF8String:response];
}

- (void)stop {
    if (_handle != NULL) {
        px_plugin_process_stop_simple(_handle);
        _handle = NULL;
    }
    _active = NO;
}

@end
