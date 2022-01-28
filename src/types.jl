#
# types.jl -
#
# Type definitions for the Julia interface to FLI SDK
#
#------------------------------------------------------------------------------

# Julia type for a C enumeration.
const Cenum = Cint

struct CallError <: Exception
    code::Cint      # return value
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
    imgConfigContext
    stores configuration parameters for the hardware to be set prior to the
    next acquisition loop
""" ImageConfigContext

mutable struct ImageConfigContext

    width::Clong
    height::Clong
    offsetX::Clong
    offsetY::Clong
    bytePerPixel::Int
    exposuretime::Cdouble   # msec

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

    function CameraList(interface::UInt8, deviceType::UInt8)

        inputDomain = convert(Clong,domain | deviceT)
        maxStrLength::UInt32 = 100
        filename = Ref{String}(0)
        name =  Ref{String}(0)
        domain = Ref{Clong}(0)

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
        return new(ref[], domainName)

    end
end
