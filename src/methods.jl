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
