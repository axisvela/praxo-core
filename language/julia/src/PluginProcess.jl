module PluginProcess

using Base64
using ..Json

export ProcessConfig, ProcessHost, start_plugin!, invoke_plugin, stop_plugin!, close_plugin!

const PROTOCOL_VERSION = 1
const CONTROL_SERVICE = "host.control"
const METHOD_HEALTH = "health"
const METHOD_SHUTDOWN = "shutdown"
const DEFAULT_TOKEN_ENV = "PRAXOVELA_PLUGIN_TOKEN"

struct ProcessConfig
    plugin_id::String
    path::String
    args::Vector{String}
    token::String
    start_timeout::Float64
    invoke_timeout::Float64
end

ProcessConfig(plugin_id::AbstractString, path::AbstractString;
    args::Vector{String}=String[], token::AbstractString="",
    start_timeout::Real=10.0, invoke_timeout::Real=30.0) =
    ProcessConfig(String(plugin_id), String(path), args, String(token),
        Float64(start_timeout), Float64(invoke_timeout))

mutable struct ProcessHost
    config::ProcessConfig
    io::Union{IO,Nothing}
    token::String
    seq::Int
    active::Bool
end

function ProcessHost(config::ProcessConfig)
    isempty(config.plugin_id) && throw(ArgumentError("plugin: PluginID is required"))
    isempty(config.path) && throw(ArgumentError("plugin: path is required"))
    token = isempty(config.token) ? bytes2hex(rand(UInt8, 32)) : config.token
    ProcessHost(config, nothing, token, 0, false)
end

function _command(host::ProcessHost)
    cmd = Cmd(vcat(host.config.path, host.config.args))
    return addenv(cmd, DEFAULT_TOKEN_ENV => host.token)
end

function _read_frame(io::IO, timeout::Float64)
    result = Ref{Any}(nothing)
    task = @async begin
        try
            result[] = readline(io)
        catch error
            result[] = error
        end
    end
    deadline = time() + timeout
    while !istaskdone(task) && time() < deadline
        sleep(0.005)
    end
    if !istaskdone(task)
        close(io)
        error("plugin: timed out waiting for a response")
    end
    value = result[]
    value isa Exception && throw(value)
    return String(value)
end

function _call(host::ProcessHost, service::String, method::String,
    payload::Vector{UInt8}; timeout::Float64)
    io = host.io
    io === nothing && error("plugin: host is not active")
    host.seq += 1
    frame = Dict{String,Any}(
        "id" => "req-$(host.seq)",
        "version" => PROTOCOL_VERSION,
        "plugin_id" => host.config.plugin_id,
        "service" => service,
        "method" => method,
        "token" => host.token,
        "payload" => base64encode(payload),
    )
    write(io, stringify(frame) * "\n")
    flush(io)
    response = parse_json(_read_frame(io, timeout))
    getbool(response, "ok", false) || throw(ErrorException(
        getstring(response, "message", getstring(response, "code", "plugin: call failed"))))
    encoded = getstring(response, "payload", "")
    return isempty(encoded) ? UInt8[] : base64decode(encoded)
end

function start_plugin!(host::ProcessHost)
    host.io === nothing || error("plugin: host already started")
    host.io = open(pipeline(_command(host), stderr=devnull), "r+")
    try
        _call(host, CONTROL_SERVICE, METHOD_HEALTH, UInt8[];
            timeout=host.config.start_timeout)
    catch error
        close(host.io)
        host.io = nothing
        rethrow(error)
    end
    host.active = true
    return host
end

function invoke_plugin(host::ProcessHost, service::AbstractString,
    method::AbstractString, payload::AbstractString="";
    timeout::Union{Nothing,Real}=nothing)
    host.active || throw(ErrorException("plugin: host is not active"))
    wait = timeout === nothing ? host.config.invoke_timeout : Float64(timeout)
    return _call(host, String(service), String(method), Vector{UInt8}(codeunits(payload));
        timeout=wait)
end

function stop_plugin!(host::ProcessHost)
    host.io === nothing && return
    if host.active
        try
            _call(host, CONTROL_SERVICE, METHOD_SHUTDOWN, UInt8[]; timeout=5.0)
        catch
        end
    end
    host.active = false
    close(host.io)
    host.io = nothing
    return nothing
end

close_plugin!(host::ProcessHost) = stop_plugin!(host)

end
