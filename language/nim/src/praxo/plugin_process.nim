type
  PluginProcessError* = object of CatchableError
  ProcessHost* = ref object
    handle*: pointer

proc pxStart(pluginId, path, arg, token: cstring, handle: ptr pointer,
  errorBuffer: cstring, errorSize: csize_t): cint
  {.importc: "px_plugin_process_start_simple", cdecl.}

proc pxInvoke(handle: pointer, service, methodName, payload: cstring,
  response: cstring, responseSize: csize_t, errorBuffer: cstring,
  errorSize: csize_t): cint
  {.importc: "px_plugin_process_invoke_simple", cdecl.}

proc pxStop(handle: pointer)
  {.importc: "px_plugin_process_stop_simple", cdecl.}

proc start*(host: ProcessHost, pluginId, path, arg, token: string): void =
  var handle: pointer = nil
  var errorBuffer: array[256, char]
  errorBuffer[0] = '\0'
  let ok = pxStart(pluginId.cstring, path.cstring, arg.cstring, token.cstring,
    addr handle, cast[cstring](addr errorBuffer[0]), errorBuffer.len.csize_t)
  if ok == 0 or handle == nil:
    raise newException(PluginProcessError,
      $cast[cstring](addr errorBuffer[0]))
  host.handle = handle

proc invoke*(host: ProcessHost, service, methodName, payload: string): string =
  if host.handle == nil:
    raise newException(PluginProcessError, "plugin: host is not active")
  var response: array[8192, char]
  var errorBuffer: array[256, char]
  response[0] = '\0'
  errorBuffer[0] = '\0'
  let ok = pxInvoke(host.handle, service.cstring, methodName.cstring,
    payload.cstring, cast[cstring](addr response[0]), response.len.csize_t,
    cast[cstring](addr errorBuffer[0]), errorBuffer.len.csize_t)
  if ok == 0:
    raise newException(PluginProcessError,
      $cast[cstring](addr errorBuffer[0]))
  result = $cast[cstring](addr response[0])

proc stop*(host: ProcessHost): void =
  if host.handle != nil:
    pxStop(host.handle)
    host.handle = nil
