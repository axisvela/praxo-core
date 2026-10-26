module Json

using JSON

export parse_json, stringify, getvalue, getstring, getbool, getint, getarray, equals

function parse_json(text::AbstractString)
    isempty(strip(text)) && return nothing
    return JSON.parse(text)
end

function stringify(value)
    return JSON.json(value)
end

function getvalue(node, key::AbstractString, fallback=nothing)
    if node isa AbstractDict && haskey(node, key)
        return node[key]
    end
    return fallback
end

function getstring(node, key::AbstractString, fallback=nothing)
    value = getvalue(node, key, fallback)
    return value isa AbstractString ? String(value) : fallback
end

function getbool(node, key::AbstractString, fallback::Bool=false)
    value = getvalue(node, key, fallback)
    return value isa Bool ? value : fallback
end

function getint(node, key::AbstractString, fallback::Integer=0)
    value = getvalue(node, key, fallback)
    return value isa Integer ? Int(value) : (value isa AbstractFloat ? Int(value) : Int(fallback))
end

function getarray(node, key::AbstractString)
    value = getvalue(node, key, Any[])
    return value isa AbstractVector ? value : Any[]
end

function equals(left, right)
    if left === nothing || right === nothing
        return left === nothing && right === nothing
    end
    if left isa AbstractDict && right isa AbstractDict
        length(left) == length(right) || return false
        for (key, value) in left
            haskey(right, key) || return false
            equals(value, right[key]) || return false
        end
        return true
    end
    if left isa AbstractVector && right isa AbstractVector
        length(left) == length(right) || return false
        for index in eachindex(left)
            equals(left[index], right[index]) || return false
        end
        return true
    end
    if left isa Number && right isa Number
        return left == right
    end
    return left == right
end

end
