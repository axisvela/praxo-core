module JsonSchema

using ..Json

export ValidationError, validate

struct ValidationError
    path::String
    message::String
end

function validate(schema, data)
    errors = ValidationError[]
    visit(schema isa AbstractDict ? schema : Dict{String,Any}(), data, "\$", errors)
    return errors
end

function visit(schema, data, path::String, errors::Vector{ValidationError})
    kind = Json.getstring(schema, "type", "")
    if data === nothing
        if !isempty(kind)
            push!(errors, ValidationError(path, "expected $(kind), got null"))
        end
        return
    end
    if kind == "object"
        visit_object(schema, data, path, errors)
    elseif kind == "array"
        visit_array(schema, data, path, errors)
    elseif kind == "string"
        visit_string(schema, data, path, errors)
    elseif kind == "number" || kind == "integer"
        visit_number(schema, kind, data, path, errors)
    elseif kind == "boolean"
        visit_boolean(schema, data, path, errors)
    end
end

function visit_object(schema, data, path::String, errors::Vector{ValidationError})
    if !(data isa AbstractDict)
        push!(errors, ValidationError(path, "expected object"))
        return
    end
    for name in Json.getarray(schema, "required")
        name isa AbstractString || continue
        if !haskey(data, name)
            push!(errors, ValidationError("$(path).$(name)", "required field missing"))
        end
    end
    properties = Json.getvalue(schema, "properties", nothing)
    properties isa AbstractDict || return
    for (name, child) in properties
        if haskey(data, name) && child isa AbstractDict
            visit(child, data[name], "$(path).$(name)", errors)
        end
    end
end

function visit_array(schema, data, path::String, errors::Vector{ValidationError})
    if !(data isa AbstractVector)
        push!(errors, ValidationError(path, "expected array"))
        return
    end
    items = Json.getvalue(schema, "items", nothing)
    items isa AbstractDict || return
    for (index, value) in enumerate(data)
        visit(items, value, "$(path)[$(index - 1)]", errors)
    end
end

function visit_string(schema, data, path::String, errors::Vector{ValidationError})
    if !(data isa AbstractString)
        push!(errors, ValidationError(path, "expected string"))
        return
    end
    count = length(data)
    minimum = Json.getint(schema, "minLength", 0)
    maximum = Json.getint(schema, "maxLength", 0)
    if minimum > 0 && count < minimum
        push!(errors, ValidationError(path, "min length $(minimum), got $(count)"))
    end
    if maximum > 0 && count > maximum
        push!(errors, ValidationError(path, "max length $(maximum), got $(count)"))
    end
    pattern = Json.getstring(schema, "pattern", nothing)
    if pattern !== nothing
        try
            if !occursin(Regex(pattern), data)
                push!(errors, ValidationError(path, "pattern '$(pattern)' not matched"))
            end
        catch
            push!(errors, ValidationError(path, "invalid pattern '$(pattern)'"))
        end
    end
    check_enum(schema, data, path, errors)
end

function visit_number(schema, kind::String, data, path::String, errors::Vector{ValidationError})
    if !(data isa Number) || data isa Bool
        push!(errors, ValidationError(path, "expected number"))
        return
    end
    if kind == "integer" && !isinteger(data)
        push!(errors, ValidationError(path, "expected integer, got $(data)"))
        return
    end
    check_enum(schema, data, path, errors)
    minimum = Json.getvalue(schema, "minimum", nothing)
    maximum = Json.getvalue(schema, "maximum", nothing)
    if minimum isa Number && minimum != 0 && data < minimum
        push!(errors, ValidationError(path, "value below minimum"))
    end
    if maximum isa Number && maximum != 0 && data > maximum
        push!(errors, ValidationError(path, "value above maximum"))
    end
end

function visit_boolean(schema, data, path::String, errors::Vector{ValidationError})
    if !(data isa Bool)
        push!(errors, ValidationError(path, "expected boolean"))
        return
    end
    check_enum(schema, data, path, errors)
end

function check_enum(schema, data, path::String, errors::Vector{ValidationError})
    values = Json.getvalue(schema, "enum", nothing)
    values isa AbstractVector || return
    isempty(values) && return
    any(value -> Json.equals(value, data), values) && return
    push!(errors, ValidationError(path, "value not in enum"))
end

end
