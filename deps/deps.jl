#
# deps.jl --
#
# Definitions for the Julia interface to TAO C-library.
#
# *IMPORTANT* This file has been automatically generated, do not edit it
#             directly but rather modify the source in `gendeps.c`.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

# Path to the core TAO dynamic library:
const taolib = "/osr/local/lib/libtao.so"

const lib = "/opt/fli/libfli-1.104/lib/libfli.so"
# Possible return values for an operation:
struct Status
    val::Cint
end
const ERROR   = Status(-1)
const OK      = Status( 0)
const TIMEOUT = Status( 1)

# Type used to store a shared memory identifier:
const ShmId = Int32

"""
`TaoBindings.BAD_SHMID` is used to denote an invalid shared memory identifier.
"""
const BAD_SHMID = ShmId(-1)

# Julia type corresponding to a C enumeration:
const Cenum = Cint

"""
`TaoBindings.SHARED_MAGIC` specifies a, hopefully unique, signature stored in
the 24 most significant bits of the TAO shared object type.
"""
const SHARED_MAGIC = 0x310efc00

"""
`TaoBindings.SHARED_OBJECT` is the type of a basic TAO shared object.
"""
const SHARED_OBJECT = 0x310efc00

"""
`TaoBindings.SHARED_ARRAY` is the type of a TAO shared multi-dimensional array.
"""
const SHARED_ARRAY = 0x310efc01

"""
`TaoBindings.SHARED_CAMERA` is the type of a TAO shared camera data.
"""
const SHARED_CAMERA = 0x310efc02

"""
`TaoBindings.REMOTE_MIRROR` is the type of a TAO remote deformable mirror.
"""
const REMOTE_MIRROR = 0x310efc03

"""
`TaoBindings.SHARED_MIRROR_DATA` is the type of a TAO shared deformable mirror data.
"""
const SHARED_MIRROR_DATA = 0x310efc04

"""
`TaoBindings.SHARED_ANY` is the shared object type to use when any type is
acceptable.
"""
const SHARED_ANY = 0xffffffff

"""
`TaoBindings.SHARED_OWNER_SIZE` is the the number of bytes (including the final
null) for the name of the owner.
"""
const SHARED_OWNER_SIZE = 44

"""
`TaoBindings.MAX_NDIMS` is the maximum number of dimensions of TAO arrays.
"""
const MAX_NDIMS = 5

# Union of all element types of TAO shared arrays.
const SharedArrayElementTypes = Union{Int8, UInt8, Int16, UInt16, Int32,
                                      UInt32, Int64, UInt64, Cfloat, Cdouble}

# List of all element types of TAO shared arrays (can be indexed
# by TAO element type identifier).
const SHARED_ARRAY_ELTYPES = (Int8, UInt8, Int16, UInt16, Int32,
                                    UInt32, Int64, UInt64, Cfloat, Cdouble)

"""
    TaoBindings.shared_array_eltype(T) -> id

yields the element type code of TAO shared array corresponding to Julia
type `T`.  An error is raised if `T` is not supported.
"""
shared_array_eltype(::Type{Int8}) = Cint(1)
shared_array_eltype(::Type{UInt8}) = Cint(2)
shared_array_eltype(::Type{Int16}) = Cint(3)
shared_array_eltype(::Type{UInt16}) = Cint(4)
shared_array_eltype(::Type{Int32}) = Cint(5)
shared_array_eltype(::Type{UInt32}) = Cint(6)
shared_array_eltype(::Type{Int64}) = Cint(7)
shared_array_eltype(::Type{UInt64}) = Cint(8)
shared_array_eltype(::Type{Cfloat}) = Cint(9)
shared_array_eltype(::Type{Cdouble}) = Cint(10)
@noinline shared_array_eltype(::Type{T}) where T =
    error("unsupported element type ", T)

# Identifiers of the type of the elements in an array.
const ELTYPE_INT8   =  1 # Signed 8-bit integer
const ELTYPE_UINT8  =  2 # Unsigned 8-bit integer
const ELTYPE_INT16  =  3 # Signed 16-bit integer
const ELTYPE_UINT16 =  4 # Unsigned 16-bit integer
const ELTYPE_INT32  =  5 # Signed 32-bit integer
const ELTYPE_UINT32 =  6 # Unsigned 32-bit integer
const ELTYPE_INT64  =  7 # Signed 64-bit integer
const ELTYPE_UINT64 =  8 # Unsigned 64-bit integer
const ELTYPE_FLOAT  =  9 # Single precision floating-point
const ELTYPE_DOUBLE = 10 # Double precision floating-point

# Julia types of the members of the C `timespec` structure.
const _typeof_timespec_sec = Int64
const _typeof_timespec_nsec = Int64

const FLIDOMAIN_USB = 0x002
const FLIDEVICE_CAMERA = 0x100
