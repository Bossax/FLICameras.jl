#
# methods.jl -
#
# Implementation of methods for the Julia interface to the FLI SDK.
#
#------------------------------------------------------------------------------
handle(obj::Camera) = getfield(obj, :handle)

isnull(obj::Camera) = isnull(handle(obj))
isnull(ptr::Ptr{T}) where {T} = (ptr == null_pointer(T))

null_pointer(::Type{T}) where {T} = Ptr{T}(0)
null_pointer(x) = null_pointer(typeof(x))

_clear_handle!(obj::Camera) =
    setfield!(obj, :handle, fieldtype(typeof(obj), :handle)(0))

_convert(p::Int64) = convert(Float64,p)

function _finalize(obj::Camera)
    ptr = handle(obj)
    if !isnull(ptr)
        _clear_handle!(obj)

    end
    return nothing
end

#------------------------------------------------------------------------------
# Specialize `getproperty` and `setproperty!` in the name of the member (for
# type-stability and faster code).

getproperty(obj::Camera, sym::Symbol) = getproperty(obj, Val(sym))
setproperty!(obj::Camera, sym::Symbol, val) =
    setproperty!(obj, Val(sym), val)

# The following methods are to deal with errors.
getproperty(obj::Camera, ::Val{M}) where M = throw_unknown_field(Camera, M)

setproperty!(obj::Camera, ::Val{M}, val) where M =
    if M in propertynames(obj)
        throw_read_only_field(Camera, M)
    else
        throw_unknown_field(Camera, M)
    end

@noinline throw_unknown_field(T::Type, sym::Union{Symbol,AbstractString}) =
    throw(ErrorException("objects of type $T have no field `$sym`"))

@noinline throw_read_only_field(T::Type, sym::Union{Symbol,AbstractString}) =
    throw(ErrorException("field `$sym` of objects of type $T is read-only"))
