#
# macros.jl -
#
# Implementation of macros to simplify calling functions of the Spinnaker C
# SDK.
#
#------------------------------------------------------------------------------

"""
    @unchecked_call(func, argtypes, args...) -> err

calls function `func` in the Spinnaker C SDK with arguments `args...` of types
`argtypes` and returns the result `err`.  The function to call may be specified
as a string or as a symbol.  Example:

    @unchecked_call(:spinSystemGetLibraryVersion,
                    (SystemHandle, Ptr{LibraryVersion},),
                    handle(system), ref)

is equivalent to (`lib` is the constant string the path to the Spinnaker
dynamic library and `Cint` is the type of the result returned by all functions
of the Spinnaker C SDK):

    err = ccall((:spinSystemGetLibraryVersion, lib), Cint,
                (SystemHandle, Ptr{LibraryVersion},),
                handle(system), ref)

or

   err = @ccall lib.spinSystemGetLibraryVersion(
       handle(system)::SystemHandle,
       ref::Ptr{LibraryVersion}
   )::Cint

"""
macro unchecked_call(func, args...)
    esc(_unchecked_call_expr(func, args...))
end

"""
    @checked_call(func, argtypes, args...)

calls function `func` in the Spinnaker C SDK with arguments `args...` of types
`argtypes` throwing an exception if the value returned by the function
indicates an error.  The function to call may be specified as a string or as a
symbol.  Example:

    @checked_call(:spinSystemGetLibraryVersion,
                  (SystemHandle, Ptr{LibraryVersion},),
                  handle(system), ref)

is equivalent to (`lib` is the constant string the path to the Spinnaker
dynamic library and `Cint` is the type of the result returned by all functions
of the Spinnaker C SDK):

    let err = ccall((:spinSystemGetLibraryVersion, lib), Cint,
                    (SystemHandle, Ptr{LibraryVersion},),
                    handle(system), ref)
        _check(err, :spinSystemGetLibraryVersion)
    end

"""
macro checked_call(func, args...)
    esc(_checked_call_expr(func, args...))
end

# Yield an expression equivalent to a symbol.
_quote_expr(obj::QuoteNode) = _quote_expr(obj.value)
_quote_expr(str::AbstractString) = _quote_expr(Symbol(str))
_quote_expr(sym::Symbol) = Expr(:quote, sym)

# Yield the expression to call a function of the SDK and return its result.
_unchecked_call_expr(func, args...) =
    Expr(:call, :ccall, Expr(:tuple, _quote_expr(func), :lib), :Cint, args...)

# Yield the expression to call a function of the SDK and check its result.
_checked_call_expr(func, args...) =
    Expr(:call, :_check, _unchecked_call_expr(func, args...), _quote_expr(func))
