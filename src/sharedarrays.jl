#
# sharedarrays.jl --
#
# Management of shared multi-dimensional arrays for the Julia interface to the
# C libraries of TAO, a Toolkit for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

propertynames(arr::SharedArray) =
    (:accesspoint,
     :counter,
     :shmid,
     :lock,
     :owner,
     :size,
     :timestamp1,
     :timestamp2,
     :timestamp3,
     :timestamp4,
     :type,
     )

getattribute(arr::SharedArray, ::Val{:counter}) =
    ccall((:tao_get_shared_array_counter, taolib), Int64,
          (Ptr{AbstractSharedObject},), arr)

setattribute!(arr::SharedArray, ::Val{:counter}, cnt::Integer) =
    ccall((:tao_set_shared_array_counter, taolib), Cvoid,
          (Ptr{AbstractSharedObject}, Int64), arr, cnt)

getattribute(arr::SharedArray, ::Val{:timestamp1}) = get_timestamp(arr, 1)
getattribute(arr::SharedArray, ::Val{:timestamp2}) = get_timestamp(arr, 2)
getattribute(arr::SharedArray, ::Val{:timestamp3}) = get_timestamp(arr, 3)
getattribute(arr::SharedArray, ::Val{:timestamp4}) = get_timestamp(arr, 4)

get_timestamp(arr::SharedArray, idx::Integer) = begin
    ref = Ref{HighResolutionTime}()
    ccall((:tao_get_shared_array_timestamp, taolib), Cvoid,
          (Ptr{AbstractSharedObject}, Cint, Ptr{HighResolutionTime}),
           arr, idx - 1, ref)
    return ref[]
end

setattribute!(arr::SharedArray, key::Val{:timestamp1}, arg::Union{Real,TimeVal}) =
    set_timestamp!(arr, 1, arg)

set_timestamp!(arr::SharedArray, idx::Integer, arg::Union{Real,TimeVal}) =
    set_timestamp!(arr, idx, HighResolutionTime(arg))

set_timestamp!(arr::SharedArray, idx::Integer, t::HighResolutionTime) =
    ccall((:tao_set_shared_array_timestamp, taolib), Cvoid,
          (Ptr{AbstractSharedObject}, Cint, Ptr{HighResolutionTime}),
           obj, idx - 1, Ref(t))

# Private accessors specific to shared arrays.
_get_arr(obj::SharedArray) =
    getfield(obj, :arr)
_set_arr!(obj::SharedArray{T,N}, val::Array{T,N}) where {T,N} =
    setfield!(obj, :arr, val)

# Make a `TaoBindings.SharedArray{T,N}` behaves like an array.  Note that, for
# performance reasons, reading/writing the array contents is done without any
# attempt to lock the object before.  Locking has to be done appropriately when
# such an object is used.
eltype(obj::SharedArray{T,N}) where {T,N} = T
length(obj::SharedArray) = length(_get_arr(obj))
ndims(obj::SharedArray{T,N}) where {T,N} = N
size(obj::SharedArray) = size(_get_arr(obj))
size(obj::SharedArray, d) = size(_get_arr(obj), d)
axes(obj::SharedArray) = axes(_get_arr(obj))
axes(obj::SharedArray, d) = axes(_get_arr(obj), d)
eachindex(obj::SharedArray) = eachindex(_get_arr(obj))
stride(obj::SharedArray, d) = stride(_get_arr(obj), d)
strides(obj::SharedArray) = strides(_get_arr(obj))
firstindex(obj::SharedArray) = 1
@inline firstindex(obj::SharedArray{T,N}, d) where {T,N} =
    ((d % UInt) - 1 < N ? 1 : error("dimension out of range"))
lastindex(obj::SharedArray) = length(_get_arr(obj))
lastindex(obj::SharedArray, d) = size(_get_arr(obj), d)

similar(obj::SharedArray) = similar(_get_arr(obj))
similar(obj::SharedArray, ::Type{T}) where {T} = similar(_get_arr(obj), T)

similar(obj::SharedArray{T}, dims::Integer...) where {T} =
    similar(obj, T, to_size(dims))
similar(obj::SharedArray{T}, dims::Tuple{Integer,Vararg{Integer}}) where {T} =
    similar(obj, T, to_size(dims))
similar(obj::SharedArray{T}, dims::Tuple{Int,Vararg{Int}}) where {T} =
    similar(_get_arr(obj), T, dims)

similar(obj::SharedArray, ::Type{T}, dims::Integer...) where {T} =
    similar(obj, T, to_size(dims))
similar(obj::SharedArray, ::Type{T}, dims::Tuple{Integer,Vararg{Integer}}) where {T} =
    similar(obj, T, to_size(dims))
similar(obj::SharedArray, ::Type{T}, dims::Tuple{Int,Vararg{Int}}) where {T} =
    similar(_get_arr(obj), T, dims)

reshape(obj::SharedArray, dims...) = reshape(_get_arr(obj), dims...)
copy(obj::SharedArray) = copy(_get_arr(obj))
deepcopy(obj::SharedArray) = deepcopy(_get_arr(obj))
fill!(obj::SharedArray, val) = fill!(_get_arr(obj), val)

@inline @propagate_inbounds Base.getindex(A::SharedArray, inds...) =
    getindex(_get_arr(A), inds...)
@inline @propagate_inbounds Base.setindex!(A::SharedArray, val, inds...) =
    (setindex!(_get_arr(A), val, inds...); return A)

IndexStyle(::Type{<:SharedArray}) = IndexLinear()

# Make a `TaoBindings.SharedArray{T,N}` iterable.
iterate(obj::SharedArray) = iterate(_get_arr(obj))
iterate(obj::SharedArray, state) = iterate(_get_arr(obj), state)

"""
    create(TaoBindings.SharedArray{T}, dims...; perms=0o600, owner=...) -> arr

creates a new shared TAO array with element type `T` and dimensions `dims` and
returns an instance attached to it.  Keyword `perms` can be used to grant
access permissions other than having read and write permissions for the creator
only.  Keyword `owner` can be used to specify the name of the owner of the
shared object (its length must be strictly less than
`TaoBindings.SHARED_OWNER_SIZE` and its default value is given by
`TaoBindings.default_owner()`).

    create(TaoBindings.SharedObject, type, size; perms=0o600, owner=...) -> obj

creates a new shared TAO object of given type and size (in bytes) and returns
an instance attached to it.  Keywords `perms` and `owner` have the same meaning
as above.

"""
create(::Type{SharedArray{T}}, dims::Integer...; kwds...) where {T} =
    create(SharedArray{T}, dims; kwds...)
create(::Type{SharedArray{T}}, dims::NTuple{N,Integer}; kwds...) where {T,N} =
    create(SharedArray{T,N}, dims; kwds...)
create(::Type{SharedArray{T,N}}, dims::Integer...; kwds...) where {T,N} =
    create(SharedArray{T,N}, dims; kwds...)
create(::Type{SharedArray{T,N}}, dims::NTuple{N,Integer}; kwds...) where {T,N} =
    create(SharedArray{T,N}, map(Int, dims); kwds...)
function create(::Type{SharedArray{T,N}},
                dims::NTuple{N,Int};
                owner::AbstractString = default_owner(),
                perms::Integer = 0o600) where {T,N}
    length(owner) < SHARED_OWNER_SIZE || error("owner name too long")
    eltype = shared_array_eltype(T)
    ptr = ccall((:tao_create_shared_array, taolib), Ptr{AbstractSharedObject},
                (Cstring, Cenum, Cint, Ptr{Clong}, Cuint),
                owner, eltype, N, Clong[dims...], perms)
    _check(ptr != C_NULL)
   return _wrap(SharedArray{T,N}, ptr, dims)
end

attach(::Type{SharedArray{T}}, shmid::Integer) where {T} =
    attach(SharedArray, shmid) :: SharedArray{T}

attach(::Type{SharedArray{T,N}}, shmid::Integer) where {T,N} =
    attach(SharedArray, shmid) :: SharedArray{T,N}

function attach(::Type{SharedArray}, shmid::Integer)
    ptr = ccall((:tao_attach_shared_array, taolib), Ptr{AbstractSharedObject},
                (ShmId,), shmid)
    _check(ptr != C_NULL)
    eltype = ccall((:tao_get_shared_array_eltype, taolib), Cenum,
                   (Ptr{AbstractSharedObject},), ptr)
    1 ≤ eltype ≤ length(SHARED_ARRAY_ELTYPES) ||
        _detach_and_throw(ptr, "Bad element type")
    N = Int(ccall((:tao_get_shared_array_ndims, taolib), Cint,
                  (Ptr{AbstractSharedObject},), ptr))
    1 ≤ N ≤ MAX_NDIMS ||
        _detach_and_throw(ptr, "Bad number of dimensions")
    dims = Vector{Int}(undef, N)
    for d in 1:N
        dims[d] = ccall((:tao_get_shared_array_dim, taolib), Clong,
                        (Ptr{AbstractSharedObject}, Cint), ptr, d)
        dims[d] ≥ 1 || _detach_and_throw(ptr, "Bad dimension ", d)
    end
    T = SHARED_ARRAY_ELTYPES[eltype]
    return _wrap(SharedArray{T,N}, ptr, (dims...,))
end

function _wrap(::Type{SharedArray{T,N}}, ptr::Ptr{AbstractSharedObject},
               dims::NTuple{N,Int}) where {T,N}
    data = ccall((:tao_get_shared_array_data, taolib), Ptr{T},
                 (Ptr{AbstractSharedObject},), ptr)
    data != C_NULL ||
        _detach_and_throw(ptr, "Bad shared array data address")
    arr = unsafe_wrap(Array, data, dims; own = false)
    obj = SharedArray{T,N}(ptr, arr, UNLOCKED, true)
    return finalizer(_finalize, obj)
end

@noinline _detach_and_throw(ptr::Ptr{AbstractSharedObject}, args...) =
    _detach_and_throw(ptr, string(args...))

function _detach_and_throw(ptr::Ptr{AbstractSharedObject}, msg::String)
    _call_detach(ptr)
    stack = get_error_stack()
    any_errors(stack) && discard_errors(stack)
    error(msg)
end

function detach(obj::SharedArray{T,N}) where {T,N}
    # Detaching a TAO shared array makes the associated Julia array invalid
    # so we replace it with an array of the correct type but with all
    # dimensions equal to zero.
    _set_arr!(obj, Array{T,N}(undef, ntuple(i -> 0, Val(N))))
    _detach(obj, true)
end
