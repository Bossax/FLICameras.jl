#
# types.jl -
#
# Type definitions for the Julia interface to FLI SDK
#
#------------------------------------------------------------------------------

# Julia type for a C enumeration.
const Cenum = Cint

struct CallError <: Exception
    code::Cint      # return value 0 success, non-zero on failure
    func::Symbol    # function causing error
end


abstract type CameraStatus end

# structs for acquisition signal
struct Stop<:CameraStatus end
struct Continue<:CameraStatus end

# Julia type alias
const flidev = Clong
const CameraHandle = Ptr{flidev}


"""

`TaoBindings.AbstractHighResolutionTime` is the parent type of time types with
a resolution of one nanosecond, that is [`TaoBindings.TimeSpec`](@ref) and
[`TaoBindings.HighResolutionTime`](@ref).

"""
abstract type AbstractHighResolutionTime end

"""
The structure `TaoBindings.HighResolutionTime` is the Julia equivalent to the
TAO `tao_time_t` structure.  Its members are `sec`, an integer number of
seconds, and `nsec`, an integer number of nanoseconds.

Also see [`TaoBindings.TimeSpec`](@ref).

"""
struct HighResolutionTime <: AbstractHighResolutionTime
    sec::Int64
    nsec::Int64
end

"""
    imgConfigContext
    stores configuration parameters for the hardware to be set prior to the
    next acquisition loop
""" ImageConfigContext

mutable struct ImageConfigContext

    width::Clong
    height::Clong
    offsetX::Clong
    offsetY::Clong
    exposuretime::Cdouble   # msec

    bytePerPixel::Int

    # TODO: add binning??


    function ImageConfigContext()
        max_width = 1600
        max_height = 1200
        return new(max_width, max_height, 0, 0,1,100.0)
    end
end

mutable struct CameraList
    camList::Vector{String}
    domainList::Vector{Clong}
    numCam::Int64

    function CameraList(interface::UInt16, deviceType::UInt16)

        inputDomain = convert(Clong, interface | deviceType)
        maxStrLength::UInt32 = 100
        filename = Ref{String}()
        name =  Ref{String}()
        domain = Ref{Clong}()

        numCam = 0
        camList = Vector{String}(undef,2)
        domainList = Vector{String}(undef,2)

        @checked_call(:FLICreateList,(Clong,), inputDomain)

        # Retrieve the camera list
        while true
            err = ccall((:FLIListNext, lib), Cint,
                        (Ptr{Clong}, Ptr{String},UInt32,Ptr{String},UInt32,),
                         domain,filename, maxStrLength,name, maxStrLength)

            if err != 0
                break
            end

            @checked_call(:FLIListFirst,(Ptr{Clong}, Ptr{String},UInt32,
                        Ptr{String},UInt32,), domain,filename, maxStrLength,
                        name, maxStrLength)

            numCam = numCam +1
            camList[numCam] = filename[]
            domainList[numCam] = domain[]

        end

        @checked_call(:FLIDeleteList,(nothing,), nothing)
        
        # Return the instanciated object.
        return new(camList, domainList, numCam)
    end

end


mutable struct Camera
    handle::CameraHandle
    domain::Clong
    status::CameraStatus

    # get camera from indexing a camera list
    function Camera(devList::CameraList , i::Integer)
        1 ≤ i ≤ length(devList.numCam) || error("out of bound index in camera list ")
        devName = devList.camList[i]
        domainName = devList.domainList[i]
        ref = Ref{CameraHandle}(0)

        @checked_call(:FLIOpen, (CameraHandle, String, Clong,),
                      ref, devName, domainName)
        return finalizer(_finalize,new(ref[], domainName))

    end
end
