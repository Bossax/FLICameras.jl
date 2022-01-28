#
# camera.jl
#
# general camera status functions
# APIs
#

#------------------------------------------------------------------------------


#==
    Setter functions
==#

"""
    Set exposure time
""" set_exposuretime


"""
    Set_ROI
""" set_ROI

"""
    Set temperature
""" set_temperature

#===
    Getter functions
===#

"""
    Get temperature
""" get_temperature



"""
    Flush CCD to clear the data before taking a new image

""" flushCCD

@inline flushCCD(camera::Camera) = @checked_call(:FLIFlushRow,(CameraHandle,Clong,Clong,),
                                    handle(camera), 1200 , 1)

"""
    Expose camera CCD to take image as long as specified by exposure time
"""
@inline exposeFrame(camera::Camera) = @checked_call(:FLIExposeFrame,(CameraHandle,),
                                                    handle(camera))

#===
Camera opearations
===#

"""
    begin acquisition

""" beginAcquisition
function beginAcquisition(camera::Camera, sig::Channel{CameraStatus},
                            new_img::Condition, empty_buff::Condition)
    camera.status = Continue()
    flushCCD(camera)

    while true

        exposeFrame(camera)
        while !isexposing(camera) end
        notify(new_img)

        wait(empty_buff) # wait condition

        flushCCD(camera)

        isready(sig) && (signal = take!(sig))
        if signal == Stop()
            camera.status = Stop()
        end
    end

end

"""
    Get the next image from camera buffer
    1.  img_cache provided by function caller to avoid allocating
    2.  imgConfig contains info about the image format
    3.  new_img conditional variable

""" getNextImage
function getNextImage(img_cache::Vector{Ptr{T}},
                      imgConfig:: ImageConfigContext, new_img::Condition,
                      empty_buff::Condition) where T<:Number
    width = imgConfig.width
    height = imgConfig.height
    widthInByte = imgConfig.width * imgConfig.bytePerPixel
    wait(new_img)               # wait to grab image

    for row in 1:height
        @checked_call(:FLIGrabRow, (CameraHandle, Ptr{UInt8}, Clong,),
                        handle(camera), pointer_array[row],widthInByte)
    end

    notify(empty_buff)
    nothing

end

"""
end acquisition
""" endAcquisition
function endAcquisition(camera::Camera, sig::Channel{CameraStatus})
    camera.status = Continue() || error("Camera is not running")
    put!(sig, Stop());
    nothing
end
