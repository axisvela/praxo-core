include(joinpath(@__DIR__, "..", "src", "PraxoCore.jl"))

using .PraxoCore

python = Sys.iswindows() ? raw"C:\Python314\python.exe" : "python3"
fixture = joinpath(@__DIR__, "fixtures", "process_plugin.py")
host = ProcessHost(ProcessConfig("com.example.echo", python; args=[fixture]))
start_plugin!(host)
try
    response = invoke_plugin(host, "tool.provider", "echo", "{\"text\":\"hi\"}")
    @assert String(response) == "{\"text\":\"hi\"}"
    println("julia plugin process tests passed")
finally
    stop_plugin!(host)
end
