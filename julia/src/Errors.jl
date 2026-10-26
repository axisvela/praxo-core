module Errors

export PraxoError

struct PraxoError <: Exception
    code::String
    message::String
end

Base.showerror(io::IO, error::PraxoError) = print(io, error.message)

end
