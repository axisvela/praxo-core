#import <Foundation/Foundation.h>

#import "PraxoPluginProcess.h"

void runPluginProcessTests(void (*check)(BOOL, NSString *)) {
    const char *configured = getenv("PRAXO_PYTHON");
    NSString *python = configured != NULL
        ? [NSString stringWithUTF8String:configured]
#ifdef _WIN32
        : @"python";
#else
        : @"python3";
#endif
    PXRPluginProcessConfig *config =
        [[PXRPluginProcessConfig alloc] initWithPluginId:@"com.example.echo"
                                                   path:python];
    config.argument = @"tests/fixtures/process_plugin.py";
    PXRPluginProcess *host = [[PXRPluginProcess alloc] initWithConfig:config];
    NSError *error = nil;
    if (![host start:&error]) {
        check(NO, [@"plugin process start: " stringByAppendingString:error.localizedDescription]);
        return;
    }
    NSString *response = [host invoke:@"tool.provider"
                               method:@"echo"
                              payload:@"{\"text\":\"hi\"}"
                                error:&error];
    check([response isEqualToString:@"{\"text\":\"hi\"}"],
          @"plugin process echo response");
    [host stop];
    check(!host.isActive, @"plugin process stopped");
}
