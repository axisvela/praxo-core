#import "PraxoMCP.h"
#import <stdio.h>
#if defined(__APPLE__)
#import <TargetConditionals.h>
#endif
#ifndef TARGET_OS_IPHONE
#define TARGET_OS_IPHONE 0
#endif

#import "PraxoCore.h"
#import "PraxoJSON.h"

@implementation PXRMcpClient {
    id<PXRMcpTransport> _transport;
    NSString *_requestedVersion;
    NSString *_clientVersion;
    NSTimeInterval _timeout;
    NSString *_protocolVersion;
    NSDictionary<NSString *, id> *_serverInfo;
}

- (instancetype)initWithTransport:(id<PXRMcpTransport>)transport
                  protocolVersion:(NSString *)protocolVersion
                    clientVersion:(NSString *)clientVersion
                          timeout:(NSTimeInterval)timeout {
    self = [super init];
    if (self) {
        _transport = transport;
        _requestedVersion = [protocolVersion copy];
        _clientVersion = [clientVersion copy];
        _timeout = timeout;
        _protocolVersion = @"";
        _serverInfo = @{};
    }
    return self;
}

- (NSString *)protocolVersion {
    return _protocolVersion;
}

- (NSDictionary<NSString *, id> *)serverInfo {
    return _serverInfo;
}

- (BOOL)start:(NSError **)error {
    if (_protocolVersion.length > 0) return YES;
    NSDictionary *params = @{
        @"protocolVersion": _requestedVersion,
        @"capabilities": @{},
        @"clientInfo": @{@"name": @"praxo-core", @"version": _clientVersion},
    };
    NSDictionary *result = [_transport requestMethod:@"initialize"
                                             params:params
                                            timeout:_timeout
                                              error:error];
    if (result == nil) return NO;
    id version = result[@"protocolVersion"];
    if (![version isKindOfClass:[NSString class]] || [version length] == 0) {
        if (error) {
            *error = PXRCoreError(@"MCP_HANDSHAKE",
                @"mcp: initialize returned no protocol version");
        }
        return NO;
    }
    _protocolVersion = [version copy];
    id info = result[@"serverInfo"];
    _serverInfo = [info isKindOfClass:[NSDictionary class]] ? info : @{};
    [_transport notifyMethod:@"notifications/initialized" params:@{} error:NULL];
    return YES;
}

- (NSArray<NSDictionary<NSString *, id> *> *)listTools:(NSError **)error {
    if (![self start:error]) return nil;
    NSMutableArray<NSDictionary<NSString *, id> *> *tools = [NSMutableArray array];
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    NSMutableSet<NSString *> *cursors = [NSMutableSet set];
    NSString *cursor = nil;
    while (YES) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        if (cursor != nil) params[@"cursor"] = cursor;
        NSDictionary *result = [_transport requestMethod:@"tools/list"
                                                 params:params
                                                timeout:_timeout
                                                  error:error];
        if (result == nil) return nil;
        id list = result[@"tools"];
        if (![list isKindOfClass:[NSArray class]]) {
            if (error) {
                *error = PXRCoreError(@"MCP_PROTOCOL",
                    @"mcp: tools/list tools must be a list");
            }
            return nil;
        }
        for (id item in list) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                if (error) {
                    *error = PXRCoreError(@"MCP_PROTOCOL",
                        @"mcp: invalid tool definition");
                }
                return nil;
            }
            NSString *name = item[@"name"];
            if (![name isKindOfClass:[NSString class]] || name.length == 0) {
                if (error) {
                    *error = PXRCoreError(@"MCP_PROTOCOL",
                        @"mcp: tool name is required");
                }
                return nil;
            }
            if ([names containsObject:name]) {
                if (error) {
                    *error = PXRCoreError(@"MCP_DUPLICATE_TOOL",
                        [NSString stringWithFormat:@"mcp: duplicate tool %@", name]);
                }
                return nil;
            }
            [names addObject:name];
            [tools addObject:item];
        }
        id next = result[@"nextCursor"];
        if (![next isKindOfClass:[NSString class]] || [next length] == 0) break;
        if ([cursors containsObject:next]) {
            if (error) {
                *error = PXRCoreError(@"MCP_PAGINATION",
                    @"mcp: repeated tool pagination cursor");
            }
            return nil;
        }
        [cursors addObject:next];
        cursor = next;
    }
    return tools;
}

- (id)callTool:(NSString *)name
     arguments:(NSDictionary<NSString *, id> *)arguments
         error:(NSError **)error {
    if (![self start:error]) return nil;
    NSDictionary *params = @{
        @"name": name,
        @"arguments": arguments ?: @{},
    };
    NSDictionary *result = [_transport requestMethod:@"tools/call"
                                             params:params
                                            timeout:_timeout
                                              error:error];
    if (result == nil) return nil;
    if ([result[@"isError"] boolValue]) {
        if (error) {
            *error = PXRCoreError(@"MCP_TOOL_ERROR",
                [NSString stringWithFormat:@"mcp: tool %@ failed", name]);
        }
        return nil;
    }
    if (result[@"structuredContent"] != nil) {
        return result[@"structuredContent"];
    }
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    NSArray *content = [result[@"content"] isKindOfClass:[NSArray class]]
        ? result[@"content"] : @[];
    for (id item in content) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        if (![item[@"type"] isEqual:@"text"]) continue;
        if ([item[@"text"] isKindOfClass:[NSString class]]) {
            [texts addObject:item[@"text"]];
        }
    }
    if (texts.count == 0) return [NSNull null];
    if (texts.count == 1) return texts[0];
    return texts;
}

- (void)close {
    [_transport close];
    _protocolVersion = @"";
}

@end

#if !TARGET_OS_IPHONE

@implementation PXRStdioMcpTransport {
    NSString *_command;
    NSArray<NSString *> *_args;
    NSTask *_task;
    NSFileHandle *_input;
    NSFileHandle *_output;
    NSInteger _nextId;
    BOOL _closed;
}

- (instancetype)initWithCommand:(NSString *)command
                           args:(NSArray<NSString *> *)args {
    self = [super init];
    if (self) {
        _command = [command copy];
        _args = [args copy] ?: @[];
        _nextId = 0;
    }
    return self;
}

- (BOOL)ensureStarted:(NSError **)error {
    if (_task != nil) return YES;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = _command;
    task.arguments = _args;
    NSPipe *inputPipe = [NSPipe pipe];
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardInput = inputPipe;
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;
    @try {
        [task launch];
    } @catch (NSException *exception) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT",
                [NSString stringWithFormat:@"mcp: failed to start server: %@",
                    exception.reason ?: @"unknown"]);
        }
        return NO;
    }
    _task = task;
    _input = inputPipe.fileHandleForWriting;
    _output = outputPipe.fileHandleForReading;
    return YES;
}

- (BOOL)sendMessage:(NSDictionary<NSString *, id> *)message error:(NSError **)error {
    if (![self ensureStarted:error]) return NO;
    NSString *text = PXRJSONText(message, error);
    if (text == nil) return NO;
    NSData *data = [[text stringByAppendingString:@"\n"]
        dataUsingEncoding:NSUTF8StringEncoding];
    @try {
        [_input writeData:data];
    } @catch (NSException *exception) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT", @"mcp: write failed");
        }
        return NO;
    }
    return YES;
}

- (nullable NSString *)readLine:(NSError **)error {
    NSMutableData *buffer = [NSMutableData data];
    while (YES) {
        NSData *byte = [_output readDataOfLength:1];
        if (byte.length == 0) {
            if (error) {
                *error = PXRCoreError(@"MCP_CLOSED", @"mcp: connection closed");
            }
            return nil;
        }
        uint8_t value = ((const uint8_t *)byte.bytes)[0];
        if (value == '\n') break;
        if (value != '\r') [buffer appendBytes:&value length:1];
    }
    return [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
}

- (NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                         params:(NSDictionary<NSString *, id> *)params
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    (void)timeout;
    _nextId++;
    NSInteger identifier = _nextId;
    NSDictionary *message = @{
        @"jsonrpc": @"2.0",
        @"id": @(identifier),
        @"method": method,
        @"params": params ?: @{},
    };
    if (![self sendMessage:message error:error]) return nil;
    while (YES) {
        NSString *line = [self readLine:error];
        if (line == nil) return nil;
        id parsed = nil;
        if (!PXRParseJSONText(line, &parsed, error)) return nil;
        if (![parsed isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = PXRCoreError(@"MCP_PROTOCOL",
                    @"mcp: invalid JSON-RPC message");
            }
            return nil;
        }
        if (![parsed[@"id"] isEqual:@(identifier)]) continue;
        if (parsed[@"error"] != nil) {
            if (error) {
                *error = PXRCoreError(@"MCP_RPC",
                    [NSString stringWithFormat:@"mcp: %@ failed", method]);
            }
            return nil;
        }
        id result = parsed[@"result"];
        return [result isKindOfClass:[NSDictionary class]] ? result : @{};
    }
}

- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error {
    NSDictionary *message = @{
        @"jsonrpc": @"2.0",
        @"method": method,
        @"params": params ?: @{},
    };
    return [self sendMessage:message error:error];
}

- (void)close {
    if (_closed) return;
    _closed = YES;
    @try {
        [_input closeFile];
        [_output closeFile];
        [_task terminate];
    } @catch (NSException *exception) {
    }
    _task = nil;
}

@end

#else

@implementation PXRStdioMcpTransport

- (instancetype)initWithCommand:(NSString *)command
                           args:(NSArray<NSString *> *)args {
    return [super init];
}

- (nullable NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                                   params:(NSDictionary<NSString *, id> *)params
                                                  timeout:(NSTimeInterval)timeout
                                                    error:(NSError **)error {
    if (error) {
        *error = PXRCoreError(@"MCP_TRANSPORT",
            @"mcp: stdio transport is unavailable on this platform");
    }
    return nil;
}

- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error {
    if (error) {
        *error = PXRCoreError(@"MCP_TRANSPORT",
            @"mcp: stdio transport is unavailable on this platform");
    }
    return NO;
}

- (void)close {
}

@end

#endif

@implementation PXRHttpMcpTransport {
    NSString *_endpoint;
    NSDictionary<NSString *, NSString *> *_headers;
    NSString *_protocolVersion;
    NSString *_sessionId;
    NSInteger _nextId;
    NSTimeInterval _timeout;
    BOOL _closed;
}

- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                                  headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                          protocolVersion:(NSString *)protocolVersion
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error {
    self = [super init];
    if (!self) return nil;
    NSURL *url = [NSURL URLWithString:endpoint];
    NSString *scheme = url.scheme.lowercaseString;
    if (url == nil || (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT", @"mcp: invalid HTTP endpoint");
        }
        return nil;
    }
    BOOL isHttp = [scheme isEqualToString:@"http"];
    BOOL loop = [self.class isLoopback:url.host];
    if (isHttp && !loop) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT",
                @"mcp: HTTP endpoint must use HTTPS");
        }
        return nil;
    }
    _endpoint = [endpoint copy];
    _headers = [headers copy] ?: @{};
    _protocolVersion = [protocolVersion copy];
    _timeout = timeout;
    _sessionId = @"";
    return self;
}

- (NSDictionary<NSString *, id> *)requestMethod:(NSString *)method
                                         params:(NSDictionary<NSString *, id> *)params
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    if (_closed) {
        if (error) *error = PXRCoreError(@"MCP_CLOSED", @"mcp: client is closed");
        return nil;
    }
    _nextId++;
    NSInteger identifier = _nextId;
    NSDictionary *message = @{
        @"jsonrpc": @"2.0",
        @"id": @(identifier),
        @"method": method,
        @"params": params ?: @{},
    };
    NSDictionary *response = [self post:message timeout:timeout error:error];
    if (response == nil) return nil;
    if (response[@"error"] != nil) {
        if (error) {
            *error = PXRCoreError(@"MCP_RPC",
                [NSString stringWithFormat:@"mcp: %@ failed", method]);
        }
        return nil;
    }
    id result = response[@"result"];
    return [result isKindOfClass:[NSDictionary class]] ? result : @{};
}

- (BOOL)notifyMethod:(NSString *)method
              params:(NSDictionary<NSString *, id> *)params
               error:(NSError **)error {
    if (_closed) return YES;
    NSDictionary *message = @{
        @"jsonrpc": @"2.0",
        @"method": method,
        @"params": params ?: @{},
    };
    [self post:message timeout:_timeout error:error];
    return YES;
}

- (void)close {
    if (_closed) return;
    _closed = YES;
    if (_sessionId.length == 0) return;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:_endpoint]];
    request.HTTPMethod = @"DELETE";
    request.timeoutInterval = _timeout;
    [self applyHeaders:request];
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    (void)[NSURLConnection sendSynchronousRequest:request
                                 returningResponse:&response
                                             error:&error];
}

- (NSDictionary<NSString *, id> *)post:(NSDictionary<NSString *, id> *)message
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:_endpoint]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = timeout;
    [self applyHeaders:request];
    NSError *jsonError = nil;
    NSString *text = PXRJSONText(message, &jsonError);
    if (text == nil) {
        if (error) *error = jsonError;
        return nil;
    }
    request.HTTPBody = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = nil;
    NSError *sendError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&sendError];
    if (sendError != nil) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT",
                [NSString stringWithFormat:@"mcp: HTTP transport failed: %@",
                    sendError.localizedDescription]);
        }
        return nil;
    }
    NSString *session = [self header:response name:@"mcp-session-id"];
    if (session.length > 0) _sessionId = session;
    NSInteger status = response.statusCode;
    NSString *body = data != nil
        ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
        : @"";
    if (status == 202 || status == 204 || body.length == 0) return @{};
    if (status < 200 || status >= 300) {
        if (error) {
            *error = PXRCoreError(@"MCP_TRANSPORT",
                [NSString stringWithFormat:@"mcp: HTTP %ld", (long)status]);
        }
        return nil;
    }
    NSString *contentType = [self header:response name:@"content-type"];
    id decoded = nil;
    if ([contentType.lowercaseString containsString:@"text/event-stream"]) {
        decoded = [self parseSSE:body identifier:message[@"id"] error:error];
    } else {
        if (!PXRParseJSONText(body, &decoded, error)) return nil;
    }
    if (![decoded isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = PXRCoreError(@"MCP_PROTOCOL",
                @"mcp: invalid JSON-RPC response");
        }
        return nil;
    }
    id result = decoded[@"result"];
    if ([result isKindOfClass:[NSDictionary class]]) {
        id version = result[@"protocolVersion"];
        if ([version isKindOfClass:[NSString class]] && [version length] > 0) {
            _protocolVersion = [version copy];
        }
    }
    return decoded;
}

- (void)applyHeaders:(NSMutableURLRequest *)request {
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    [request setValue:@"application/json, text/event-stream"
        forHTTPHeaderField:@"accept"];
    [request setValue:_protocolVersion
        forHTTPHeaderField:@"mcp-protocol-version"];
    if (_sessionId.length > 0) {
        [request setValue:_sessionId forHTTPHeaderField:@"mcp-session-id"];
    }
    for (NSString *key in _headers) {
        [request setValue:_headers[key] forHTTPHeaderField:key];
    }
}

- (NSString *)header:(NSHTTPURLResponse *)response name:(NSString *)name {
    for (NSString *key in response.allHeaderFields) {
        if ([key.lowercaseString isEqual:name.lowercaseString]) {
            return [response.allHeaderFields[key] description];
        }
    }
    return @"";
}

- (nullable id)parseSSE:(NSString *)body
             identifier:(nullable NSNumber *)identifier
                  error:(NSError **)error {
    NSString *normalized = [body stringByReplacingOccurrencesOfString:@"\r\n"
                                                            withString:@"\n"];
    NSArray<NSString *> *events = [normalized componentsSeparatedByString:@"\n\n"];
    id fallback = nil;
    for (NSString *event in events) {
        NSMutableArray<NSString *> *data = [NSMutableArray array];
        for (NSString *line in [event componentsSeparatedByString:@"\n"]) {
            if ([line hasPrefix:@":"]) continue;
            if ([line hasPrefix:@"data:"]) {
                NSString *value = [line substringFromIndex:5];
                [data addObject:[value stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceCharacterSet]]];
            }
        }
        if (data.count == 0) continue;
        id decoded = nil;
        if (!PXRParseJSONText([data componentsJoinedByString:@"\n"], &decoded, error)) {
            return nil;
        }
        if (identifier != nil && [decoded isKindOfClass:[NSDictionary class]] &&
            [decoded[@"id"] isEqual:identifier]) {
            return decoded;
        }
        if (fallback == nil) fallback = decoded;
    }
    if (fallback == nil && error) {
        *error = PXRCoreError(@"MCP_PROTOCOL",
            @"mcp: response contained no message");
    }
    return fallback;
}

+ (BOOL)isLoopback:(nullable NSString *)host {
    if (host == nil) return NO;
    NSString *value = [host lowercaseString];
    if ([value isEqualToString:@"localhost"]) return YES;
    if ([value isEqualToString:@"127.0.0.1"]) return YES;
    if ([value isEqualToString:@"::1"]) return YES;
    if (PXRStringHasPrefix(value, @"127.")) return YES;
    return NO;
}

@end
