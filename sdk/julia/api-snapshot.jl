using PraxoCore

root = normpath(joinpath(@__DIR__, "..", ".."))

function version_of(path)
    for line in eachline(path)
        match(r"^version\s*=\s*\"([^\"]+)\"", line) !== nothing &&
            return match(r"^version\s*=\s*\"([^\"]+)\"", line).captures[1]
    end
    error("version not found in $(path)")
end

function snapshot()
    version = version_of(joinpath(@__DIR__, "Project.toml"))
    spec = strip(read(joinpath(root, "spec", "SPEC_VERSION"), String))
    names_list = sort!(
        String[
            String(name) for name in names(PraxoCore)
            if String(name) != "PraxoCore"
        ],
    )
    return join(
        vcat(
            "# PRAXO-CORE Julia API $(version)",
            "# SPEC_VERSION $(spec)",
            "",
            names_list,
            "",
        ),
        "\n",
    )
end

const content = snapshot()
const check = "--check" in ARGS
const version = version_of(joinpath(@__DIR__, "Project.toml"))
const target = joinpath(@__DIR__, "api", "$(version).txt")

if check
    if !isfile(target)
        println(stderr, "missing snapshot: $(target)")
        exit(1)
    end
    if read(target, String) != content
        println(stderr, "snapshot is stale: $(target)")
        exit(1)
    end
    println("snapshot is current: $(target)")
else
    mkpath(dirname(target))
    write(target, content)
    println("wrote $(target)")
end
