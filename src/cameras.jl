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
set_exposuretime(camera::Camera, exposuretime::Clong) = begin
        @checked_call(:FLISetExposureTIme,(CameraHandle, Clong), handle(camera), exposuretime)
end

"""
    Set_ROI
""" set_ROI
function set_ROI(camera::Camera, roi::Vector{Clong})
    if length(roi) != 4
        #overwrite the information
         roi = [1600,1200,0,0]
    end
	width = roi[1]
	height = roi[2]
	offsetx = roi[3]
	offsety = roi[4]

	max_width = 1600
	max_height = 1200

	upper_x = (max_width - width)/2 + offsetx;
	upper_y = (max_height - height)/2+ offsety;
	lower_x = upper_x + width + offsetx;
	lower_y = upper_y + height + offsety;

	lower_x <= max_width || error("X offset is too large")
	lower_y <= max_height || error("Y offset is too large")

	 #
     @checked_call(:FLISetImageArea,(CameraHandle, Clong, Clong, Clong, Clong), handle(camera),upper_x,upper_y, lower_x, lower_y)

     nothing
end

"""
    Set temperature
""" set_temperature
set_temperature(camera::Camera, temperature::Float64) = begin
    @checked_call(:FLISetTemeprature,(CameraHandle, Float64), handle(camera), temperature)
end
#===
    Getter functions
===#

"""
    Get temperature
""" get_temperature
function get_temperature(camera::Camera)
	ref = Ref{Float64}(0)
	@checked_call(:FLIGetTemperature, (CameraHandle, Ptr{Float64}), handle(camera), ref)
	return  ref[]
end

"""
    Get timestamp to second using time() C library
    return: Float64
""" get_timestamp
@inline get_sys_timestamp() = time()

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
	initialize the camera by setting the temperature and wait until it cools down

"""
function initialize(camera::Camera; temperature::Float64 = -20.0)
	@info "Camera is initializing..."
	set_temperature(camera, temperature)
	temp = 30.0
	t0 = time()
	while temp > temperature
		temp = get_temperature(camera)
		t1 = time()
		if t1-t0 >= 5.0
			println("Camera temperature = ", temp, " ° C" )
			t0 = time()
		end
	end
	nothing

end

"""
    acquire and save images
"""
function acquire_n_save_image(camera::Camera, nSave::Int,imgConfig:: ImageConfigContext,
                                format::String)
    flushCCD(camera)
    width = imgConfig.width
    height = imgConfig.height
    widthInByte = imgConfig.width * imgConfig.bytePerPixel
    buff = Ref{UInt8}(0)
    img_cache = Matrix{UInt8}(udnef,height,width)
    for j in 1:nSave

        exposeFrame(camera)
        while !isexposing(camera) end

        for row in 1:height
            @checked_call(:FLIGrabRow, (CameraHandle, Ptr{UInt8}, Clong,),
                            handle(camera), buff, widthInByte)

            copyto!(img_cache[row,:], buff[])
        end

        flushCCD(camera)
        fname = @sprintf "FLI_image_%d" j
        fname = join([fname,format])
        save(fname, colorview(Gray,map(_convert,img_cache)))
        @printf "%s is saved\n" fname
    end

end


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

        wait(empty_buff) # wait for buffer to finish grabing image

        flushCCD(camera)

        isready(sig) && (signal = take!(sig))
        if signal == Stop()
            camera.status = Stop()
            break
        end
    end
    nothing

end

"""
    Get the next image from camera buffer
    1.  img_cache provided by function caller to avoid allocating
    2.  imgConfig contains info about the image format
    3.  new_img conditional variable

""" getNextImage
function getNextImage(img_cache::Matrix{T}, timestamp::Vector{Float64},
                      imgConfig:: ImageConfigContext, new_img::Condition,
                      empty_buff::Condition) where T<:Number

    width = imgConfig.width
    height = imgConfig.height
    widthInByte = imgConfig.width * imgConfig.bytePerPixel
    wait(new_img)          # wait to grab image

    timestamp[1] = get_sys_timestamp()

    buff = Ref{UInt8}(0)
    for row in 1:height
        @checked_call(:FLIGrabRow, (CameraHandle, Ptr{UInt8}, Clong,),
                        handle(camera), buff, widthInByte)
        copyto!(img_cache[row,:], buff[])
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

## Functions for remote workers


"""
    Work
    create image buffer, and start image acquisition.
""" work
function working(camNum::Int64)
      w = workers()
      try
         remote_do(FLICameras.work,w[1],camNum)

     catch e
         @info e
      end
     return w[1]
 end


"""
    Work function
"""
function work(camNum::Int64)
    Base.exit_on_sigint(false)
    interface = FLICameras.FLIDOMAIN_USB
    deviceType = FLICameras.FLIDEVICE_CAMERA

    camList = FLICameras.CameraList(interface, deviceType)
    camera = FLICameras.Camera(camList, camNum)

    # attach shared arrays
    img_array, imgTime_array = FLICameras.attach_remote_process()

    # operational variables
    new_img = Condition()
    empty_buff = Condition()
    sig = Channel{FLICameras.CameraStatus}(1)
    img_cache = Matrix{UInt8}(undef,imgConfig.width, imgConfig.height)
    timestamp_cache = [0.0];

    # start acquisition thread
    main_routine = @async beginAcquisition(camera, sig, new_img, empty_buff)

    # start grabbing image
    try
        while true

            getNextImage(img_cache, timestamp_cache, imgConfig, new_img, empty_buff)

            wrlock(img_array,1.0)do
                copyto!(img_array, img_cache)
            end
            wrlock(imgTime_array,1.0) do
                imgTime_array[1] = timestamp_cache
            end

        end

    catch e
        #
        FLICameras.endAcquisition(camera, sig)
        if e isa InterruptException
            @info "Acquisition loop is terminated"
            return nothing
        else
            rethrow(e)
            return nothing
        end

    end
end
