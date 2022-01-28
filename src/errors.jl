#
# errors.jl -
#
# Management of errors for the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------

# Throws a `CallError` exception if `err` indicates an error in function `func`.
function _check(err::Cint, func::Symbol)
    if err != 0
        throw_call_error(err, func)
    end
    return nothing
end

const _error_symbols = Dict{Cint,Symbol}()

@noinline throw_call_error(err::Integer, func::Symbol) =
    throw(CallError(err, func))

show(io::IO, ::MIME"text/plain", err::CallError) =
    print(io, " Error code ", err.code,
          " returned by function `", err.func, "`")
