#
# errors.jl --
#
# Management of errors for the Julia interface to the C libraries of TAO, a
# Toolkit for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

# Structure to store a single error of the TAO Library.
struct ErrorInfo
    func::String
    code::Cint
    proc::Ptr{Cvoid}
end

"""
    TaoBindings.TaoError(errs)

yields an exception to be thrown in case of errors in TAO Library.
Argument `errs` is a vector of `TaoBindings.ErrorInfo` elements.

""" TaoError

struct TaoError <: Exception
    errs::Array{ErrorInfo}
end

"""
    TaoBindings.get_error_stack()

yields the address of the calling thread error stack.

""" get_error_stack

struct ErrorStack
    top::Ptr{Cvoid} # pointer to last error
end

# We use a per-thread cache to speed-up querying the address of the calling
# thread error stack. On my Intel Core i7-5500U: _call_get_error_stack() takes
# 26ns while get_error_stack() only takes 5ns.
const ERROR_STACK = Ptr{ErrorStack}[]
function get_error_stack()
    id = Threads.threadid()
    while length(ERROR_STACK) < id
        push!(ERROR_STACK, C_NULL)
    end
    @inbounds begin
        if ERROR_STACK[id] == C_NULL
            ERROR_STACK[id] = _call_get_error_stack()
        end
        return ERROR_STACK[id]
    end
end

_call_get_error_stack() =
    ccall((:tao_get_error_stack, taolib), Ptr{ErrorStack}, ())

"""
    TaoBindings.any_errors()

yields whether there are any errors in the calling thread error stack.

"""
any_errors() = any_errors(get_error_stack())
any_errors(ptr::Ptr{ErrorStack}) = (unsafe_load(ptr)).top != C_NULL

"""
    TaoBindings._check(ans::Status, warn=false)

or

    TaoBindings._check(success::Bool, warn=false)

deals with error reporting after calling one or several functions of the TAO
Library.  Argument `ans` is the status value returned by a call to a TAO
function returning a `tao_status_t`; the call is considered as successful if
`ans != TaoBindings.ERROR`.  Another possibility is to specify a boolean value
`success` to indicate whether the call(s) to the function(s) in the TAO Library
was (were) successful.  If there are errors, optional argument `warning`
(`false` by default) indicates whether to just print the error messages as
warnings or to throw an exception.

Note that, if the first argument indicates a success but there are some
unreported erros in the calling thread error stacks, these errors are printed
as warnings.

!!! warn
    All methods in `TaoBindings` which `ccall` one of the error prone fucntions
    of the TAO Library shall call `TaoBindings._check` before they return to
    avoid memory leaks.

"""
_check(ans::Status, warn::Bool=false) = _check(ans != ERROR, warn)

@inline function _check(success::Bool, warn::Bool=false)
    stack = get_error_stack()
    if !success || any_errors(stack)
        _something_went_wrong(success, stack, warn)
    end
    nothing
end

# Slow method to deal with errors/warnings.  Should be called by _check only if
# something unexpected occured.
@noinline function _something_went_wrong(success::Bool,
                                         stack::Ptr{ErrorStack},
                                         warn::Bool)
    if any_errors(stack)
        if success || warn
            _call_report_errors(stack, "WARNING ", "        ", "\n")
        else
            throw(TaoError(pop_errors(stack)))
        end
    elseif !success
        mesg = "failure detected in a call to a function of TAO Library without error information!"
        if warn
            println("WARNING ", mesg)
        else
            error(mesg)
        end
    end
end

"""
    TaoBindings.get_error_reason(err)

yields the error message associated to `err` which is either an instance of
`TaoBindings.ErrorInfo` or an integer error code.

"""
get_error_reason(err::ErrorInfo) = get_error_reason(err.code)
get_error_reason(code::Integer) =
    unsafe_string(ccall((:tao_get_error_reason, taolib), Ptr{UInt8},
                        (Cint,), code))

"""
    TaoBindings.get_error_name(err)

yields the literal name associated to `err` which is either an instance of
`TaoBindings.ErrorInfo` or an integer error code.

"""
get_error_name(err::ErrorInfo) = get_error_name(err.code)
get_error_name(code::Integer) =
    unsafe_string(ccall((:tao_get_error_name, taolib), Ptr{UInt8},
                        (Cint,), code))

"""
    TaoBindings.report_errors(first, other, last, sfx)

prints the errors of the calling thread to the standard error output and clear
the contents of the error stack.  Arguments `first`, `other` and `last` are the
prefixes to use for printing the first, subsequent and last errors.  Argument
`sfx` is the suffix to use for printing errors.

"""
report_errors() = report_errors("(TAO-ERROR) ",
                                "         ├─ ",
                                "         └─ ", "\n")
function report_errors(first::AbstractString, other::AbstractString,
                       last::AbstractString, sfx::AbstractString)
    _call_report_errors(get_error_stack(), first, other, last, sfx)
end

function _call_report_errors(stack::Ptr{ErrorStack}, first::AbstractString,
                             other::AbstractString, last::AbstractString,
                             sfx::AbstractString)
    ccall((:tao_report_errors_to_stream, taolib), Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Cstring, Cstring, Cstring),
          C_NULL, Ptr{ErrorStack}, first, other, last, sfx)
end


"""
    TaoBindings.discard_errors(stack=get_error_stack())

discards the contents of the calling thread error stack.

"""
discard_errors(stack::Ptr{ErrorStack} = get_error_stack()) =
    ccall((:tao_discard_errors, taolib), Cvoid, (Ptr{ErrorStack},), stack)

"""
    TaoBindings.pop_errors(stack=get_error_stack())

pops the errors out of the calling thread error stack and returns an array of
instances of `TaoBindings.ErrorInfo` (possibly empty if there are no errors).

"""
function pop_errors(stack::Ptr{ErrorStack} = get_error_stack())
    func = Ref{Ptr{UInt8}}(0)
    code = Ref{Cint}(0)
    proc = Ref{Ptr{Cvoid}}(0)
    errs = ErrorInfo[]
    while 0 != ccall((:tao_pop_error, taolib), Cint,
                     (Ptr{ErrorStack}, Ptr{Ptr{UInt8}}, Ptr{Cint},
                      Ptr{Ptr{Cvoid}}), stack, func, code, proc)
        funcname = func[] == C_NULL ? "" : unsafe_string(func[])
        push!(errs, ErrorInfo(funcname, code[], proc[]))
    end
    return errs
end

struct ErrorInfoWorkspace
    reason::Ref{Ptr{UInt8}}
    info::Ref{Ptr{UInt8}}
    buffer::Vector{UInt8}
    ErrorInfoWorkspace() = new(Ref{Ptr{UInt8}}(0),
                               Ref{Ptr{UInt8}}(0),
                               Array{UInt8}(undef, 20))
end

unsafe_retrieve_error_details(err::ErrorInfo) =
    unsafe_retrieve_error_details!(err, ErrorInfoWorkspace())
unsafe_retrieve_error_details!(err::ErrorInfo, wrk::ErrorInfoWorkspace) = begin
    GC.@preserve wrk begin # FIXME: preserve not necessary?
        ccall((:tao_retrieve_error_details, taolib), Cvoid,
              (Cint, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}},
               Ptr{Ptr{Cvoid}}, Ptr{UInt8}),
              err.code, wrk.reason, wrk.info, err.proc, wrk.buffer)
        return (err.func, unsafe_string(wrk.reason[]),
                unsafe_string(wrk.info[]))
    end
end

function showerror(io::IO, err::ErrorInfo)
    func, reason, info = unsafe_retrieve_error_details(err)
    print(io, "TaoBindings.ErrorInfo: ", reason, " in function `",
          func, "` [", info, ']')
end

function showerror(io::IO, e::TaoError)
    wrk = ErrorInfoWorkspace()
    errs = e.errs
    prefix1= "TaoError: "
    prefix2= "          "
    for i in 1:length(errs)
        func, reason, info = unsafe_retrieve_error_details!(errs[i], wrk)
        print(io, (i == 1 ? prefix1 : prefix2), reason, " in function `",
              func, "` [", info, ']')
    end
end
