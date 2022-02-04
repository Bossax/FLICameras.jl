#
# cameras.jl --
#
# Management of cameras for the Julia interface to the C libraries of TAO, a
# Toolkit for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

propertynames(cam::SharedCamera) =
    (
      #tao attribute
      :owner,
      :shmid,
      :size,
      :lock,

      :listlength,
      :last,
      :next,
      :lastTS,
      :nextTS,

      :cameras,
      :attachedCam,
      :img_config,


     )
# dispatch for sharedcamera
getproperty(dev::SharedCamera, sym::Symbol) =
                            getproperty(dev,Val(sym))

#dispatch tao attribute
getproperty(dev::SharedCamera,::Val{:shmid}) = getattribute(dev,Val(:shmid))
getproperty(dev::SharedCamera,::Val{:size}) = getattribute(dev,Val(:size))
getproperty(dev::SharedCamera,::Val{:owner}) = getattribute(dev,Val(:owner))

# relay to taolib
getattribute(obj::SharedCamera, ::Val{:shmid}) =
    ccall((:tao_get_shared_data_shmid, taolib), ShmId,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::SharedCamera, ::Val{:size}) =
    ccall((:tao_get_shared_data_size, taolib), Csize_t,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::SharedCamera, ::Val{:owner}) =
  _pointer_to_string(ccall((:tao_get_shared_object_owner, taolib),
                             Ptr{UInt8}, (Ptr{AbstractSharedObject},), obj))


# dispatch Julia properties
getproperty(dev::SharedCamera, ::Val{sym}) where{sym} =
                                        getfield(dev, sym)

# property is read-only
setproperty!(dev::SharedCamera, sym::Symbol, val)  =
                                setattribute!(dev,Val(sym),val)


# attribute manipulation function
inc_attachedCam(dev::SharedCamera) = begin
                        val = dev.attachedCam +1
                        setfield!(dev, :attachedCam,Int8(val))
                    end

for sym in (
            :last,
            :next,
            :lastTs,
            :nextTS
                    )
    _sym = "$sym"
    @eval $(Symbol("set_",sym))(dev::SharedCamera,val::Integer) =
                                    setfield!(dev,Symbol($_sym),Int16(val))
end

set_img_config(shcam::SharedCamera, conf::ImageConfigContext) = setfield!(shcam,:img_config,conf)
#--- RemoteCamera property

propertynames(cam::RemoteCamera) =
    (
      # RemoteCamera properties
      :arrays,
      :timestamps,
      :img,
      :imgTime,
      :cmds,
      :time_origin,
      :no_cmds,

      # SharedCamera
      :owner,
      :shmid,
      :lock,
      :attachedcam,
      :listlength,
      :state,
      :counter,
      :last,
      :next,
      :lastTS,
      :nextTS

     )

#top level dispatch
getproperty(remcam::RemoteCamera,sym::Symbol) = getproperty(remcam, Val(sym))

#RemoteCamera properties (read-only)
for sym in (:timestamps,
            :img,
            :imgTime,
            :cmds,
            :shmids,
            :arrays,
            :device,
            :no_cmds,
            :time_origin,
            :worker_pid)
    _sym = "$sym"
    @eval getproperty(remoteCam::RemoteCamera,::$(Val{sym})) =
                        getfield(remoteCam,Symbol($_sym))
end


# Shared Camera properties
# getattribute(cam::RemoteCamera, ::Val{:lock}) = getfield(device(cam), :lock)
getproperty(remoteCam::RemoteCamera, key::Val)=
                                        getproperty(device(remoteCam), key)


# wall to setting properties
setproperty!(remoteCam::RemoteCamera, sym::Symbol, val) =
    throw_non_existing_or_read_only_attribute(remoteCam,sym)


# Constructors for `RemoteCamera`s.
# RemoteCamera(dev::SharedCamera) = RemoteCamera{dev.pixeltype}(dev)

# RemoteCamera(srv::ServerName) = RemoteCamera(attach(SharedCamera, srv))
# RemoteCamera{T}(srv::ServerName) where {T<:AbstractFloat} =
#     RemoteCamera{T}(attach(SharedCamera, srv))


#--- Accessors.
camera(cam::RemoteCamera) = cam
camera(cam::SharedCamera) = cam
device(cam::RemoteCamera) = getfield(cam, :device)
device(cam::SharedCamera,i::Int64) = cam.cameras[i]
eltype(::AbstractCamera{T}) where {T} = T

show(io::IO, cam::RemoteCamera{T}) where {T} =
    print(io, "RemoteCamera{$T}(owner=\"", cam.owner,")")



#--- create functions
function create(::Type{SharedCamera}; owner::AbstractString = default_owner(),
                perms::Integer = 0o600)

    length(owner) < SHARED_OWNER_SIZE || error("owner name too long")

    ptr = ccall((:tao_create_shared_object, taolib), Ptr{AbstractSharedObject},
                (Cstring, UInt32, Csize_t, Cuint),
                owner, _fix_shared_object_type(SHARED_CAMERA), 464, perms)
                # 464 bytes from sizeof(tao_shar_camera) in C program
    _check(ptr != C_NULL)

    return _wrap(SharedCamera, ptr)
end

## Camera util functions
function register(dev::SharedCamera, cam::Camera)
    inc_attachedCam(dev)
    try
        dev.cameras[dev.attachedCam] = cam
    catch
        throw(ErrorException("No more space to attach cameras"))
    end
end


function broadcast_shmids(shmids::Vector{ShmId})
    fname = "shmids.txt"
    path = "/tmp/FLICameras/"

    fname ∈ readdir(path) || touch(joinpath(path,fname))

    open(path*fname,"w") do f
        for shmid in shmids
            write(f,@sprintf("%d\n",shmid))
        end
    end
end

const img_param = fieldnames(ImageConfigContext)
const img_param_type = fieldtypes(ImageConfigContext)

#TODO: Fix this
function _read_and_update_config(shcam::SharedCamera)
    fname = "img_config.txt"
    path = "/tmp/FLICameras/"
    fname ∈ readdir(path) || throw(LoadError("image config doest not exist"))
    f = open(path*fname,"r")
    rd = readlines(f)

    new_conf = shcam.img_config

    for i in 1:length(rd)
      if !isempty(rd[i])
        setfield!(new_conf,img_param[i],parse(img_param_type[i],rd[i]))
      end
    end
    @show new_conf
    set_img_config(shcam,new_conf)
  end


#--- Command and state mapper

for (cmd, now_state, next_state) in (
        (:CMD_INIT,  :STATE_UNKNOWN   ,   STATE_INIT),
        (:CMD_WORK,  :STATE_WAIT      ,   STATE_WORK),
        (:CMD_STOP,  :STATE_WORK      ,   STATE_WAIT),
        (:CMD_QUIT,  :STATE_WAIT      ,   STATE_QUIT),
    )

    @eval sort_next_state(::Val{$cmd}, ::Val{$now_state}) = $next_state
end

# sort_next_state(Val(),::Val{SIG_ERROR})
for (sig, cmd, next_state) in (
        (:SIG_DONE,  :CMD_INIT      ,   STATE_WAIT),
        (:SIG_DONE,  :CMD_STOP      ,   STATE_WAIT),
        (:SIG_DONE,  :CMD_WORK      ,   STATE_WORK),
        (:SIG_DONE,  :CMD_ABORT     ,   STATE_WAIT),
        (:SIG_DONE,  :CMD_QUIT      ,   STATE_QUIT),
        (:SIG_ERROR,  :CMD_WORK      ,   STATE_ERROR),
    )

    @eval sort_next_state(::Val{$cmd}, ::Val{$sig}) = $next_state
end

sort_next_state(cmd::RemoteCameraCommand, current_state::RemoteCameraState) = sort_next_state(Val(cmd), Val(current_state))
sort_next_state(cmd::RemoteCameraCommand, shcam_sig::ShCamSIG) = sort_next_state(Val(cmd), Val(shcam_sig))


thread_safe_wait(r::Condition) = begin
                                lock(r)
                                try
                                  wait(r)
                                finally
                                  unlock(r)
                                end
                              end
thread_safe_notify(r::Condition) = begin
                                lock(r)
                                try
                                  wait(r)
                                finally
                                  unlock(r)
                                end
                              end
## Listening function
@inline no_new_cmds(cmds::SharedArray{Cint,1}) = begin
                        sum(cmds .== -1) == length(cmds)
                      end
pop!(cmds::SharedArray{Cint,1}) = begin
                          val = cmds[1]
                          cmds[:] = vcat(cmds[2:end],-1)
                          return val
                        end
"""
  Listening
  1. check cmds written to the shmid
  2. read the cmds
  3. start the command
"""
listening(shcam::SharedCamera, remcam::RemoteCamera) = @async _listening(shcam, remcam)

function _listening(shcam::SharedCamera, remcam::RemoteCamera)

  while true
   # check the command
   @info "wait cmds"

   @async _keep_checking_cmds(remcam.cmds, remcam.no_cmds )
   wait(remcam.no_cmds)
   #  read new cmd
   cmd = rdlock(remcam.cmds,0.5) do
       pop!(remcam.cmds)
   end
   # sent the command to the camera
   if next_camera_operation(RemoteCameraCommand(cmd),shcam, remcam)
     @info "Command successful..."
   else
     @info "Command failed..."
   end

 end
end

"""
   This function keeps checking the cmd array if there is a new command written to
   the shared array
"""
function _keep_checking_cmds(cmd_array::SharedArray{Cint,1}, no_cmds::Condition)

     cmd0 = rdlock(cmd_array,0.5) do
         cmd_array[1]
     end
     cmd_now = copy(cmd0)

   while cmd_now == cmd0
     cmd_now = rdlock(cmd_array,0.5) do
         cmd_array[1]
     end
     sleep(0.01)

   end
   notify(no_cmds)
   nothing
end

## attach extension
function attach(::Type{SharedCamera}, shmid::Integer)
    # Attach the shared object to the address space of the caller, then wrap it
    # in a Julia object.
    ptr = ccall((:tao_attach_shared_camera, taolib),
                Ptr{AbstractSharedObject}, (ShmId,), shmid)
    _check(ptr != C_NULL)
    cam = _wrap(SharedCamera, ptr)
    return cam
end

# attached image and image timestamp shared array on a worker process
function attach_remote_process()
    # read shared array shmids
    fname = "/tmp/FLICameras/shmids.txt"
    f = open(fname,"r")
    rd = readlines(f)
    shmids = []
    for line in rd
      push!(shmids,parse(Int64,line))
    end

    img_array = attach(SharedArray{UInt8},shmids[1])
    imgTime_array = attach(SharedArray{Float64},shmids[2])

    return img_array, imgTime_array
end
#--- shared camera operations
update_worker_pid(pid::Integer,remcam::RemoteCamera) = begin
  wrlock(remcam.device,0.1) do
    setfield!(remcam,:worker_pid,pid)
  end
end

# Operation - Commands table
next_camera_operation(cmd::RemoteCameraCommand,shcam::SharedCamera, remcam::RemoteCamera) = next_camera_operation(Val(cmd),shcam ,remcam)

for (cmd, cam_op) in (
    (:CMD_WORK,     :start),
    (:CMD_STOP,     :stop),
    (:CMD_CONFIG,   :config),
    (:CMD_UPDATE,   :update),
    (:CMD_RESET,    :reset)

    )
@eval begin
    function next_camera_operation(::Val{$cmd}, shcam::SharedCamera, remcam::RemoteCamera)
        try
            cameraTask = $cam_op(shcam,remcam)
            str_op = $cam_op
            @info "Executed  $str_op \n"
        catch ex
            @assert ex.code != 0
            @warn "Error occurs at $(ex.func)"

            return_val =  false
            return return_val
        end

        return_val =  true

        return return_val
    end
end
end


"""
    FLICameras.start(cam)
    Start camera acquisition loop on a worker process.
    Sending data to shared arrays
""" start

start(shcam::SharedCamera,remcam::RemoteCamera ) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)
    pid =[0]
    try
      # start working
      pid[1] = working(1)
      @info "worker pid = $(pid[1])"

    catch ex
      rethrow(ex)
    end

    # broadcast worker pid
    update_worker_pid(pid[1],remcam)
    @info "start is DONE"

    nothing
end

"""
  FLICameras.update(SharedCamera, RemoteCamera)
  This function interrupts the ongoing acquisition loop to update the camera
  configuration and start a new acquisition loop
  The new camera configuration setting is read through a file.
""" update
function update(shcam::SharedCamera,remcam::RemoteCamera)
  stop(shcam,remcam)
  _read_and_update_config(shcam)
  config(shcam,remcam)
  @info "Camera configuration has been updated"
  working(1)
  nothing
end


"""
    FLICameras.stop(cam; timeout=5.0)

    stops image acquisition by shared or remote camera `cam` not waiting more than
    the limit set by `timeout` in seconds.  Nothing is done if acquisition is not
    running or about to start.
stop
"""
stop(shcam::SharedCamera,remcam::RemoteCamera) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)
    pid = remcam.worker_pid
    try
      interrupt(pid)

    catch ex
      rethrow(ex)
    end

    nothing

end

"""
  FLICameras.config(SharedCamera, RemtoeCamera)
  Change camera setting according to the ImageConfigContext in SharedCamera
""" config

config(shcam::SharedCamera,remcam::RemoteCamera) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)
    ROI = []    #contain ROI info
    try

      for k in 1:length(fieldnames(ImageConfigContext))
        if k <=4
          val =  getfield(shcam.img_config,param)
          push!(ROI,val)
        elseif k == 5
          set_ROI(camera,ROI)
          val =  getfield(shcam.img_config,:exposuretime)
          set_exposuretime(camera,val)
        else
          val =  getfield(shcam.img_config,:bytePerPixel)
        end

    end

    catch ex
        rethrow(ex)
    end

    nothing
end
