using Test
using PraxoCore

@testset "PraxoCore wire" begin
    @testset "toolcall" begin
        call = ToolCallParser.parse_toolcall("{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}")
        @test call !== nothing
        @test call.name == "echo"
        @test call.input["text"] == "hi"
        @test ToolCallParser.strip_markup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world"
        ) == "helloworld"
    end

    @testset "jsonschema" begin
        schema = Json.parse_json(
            "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
        )
        errors = JsonSchema.validate(schema, Dict{String,Any}())
        @test length(errors) == 1
        @test errors[1].path == "\$.name"
        @test isempty(JsonSchema.validate(schema, Dict("name" => "ok")))
    end

    @testset "plugin" begin
        manifest = Plugin.parse_manifest(
            "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}"
        )
        @test manifest.id == "com.example.echo"
    end
end
