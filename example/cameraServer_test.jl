using Revise
using Distributed
addprocs(1)

@everywhere using Pkg
@everywhere Pkg.activate("/home/evwaco/.julia/dev/FLICameras.jl/")
@everywhere import FLICameras as FC

interface = FC.FLIDOMAIN_USB
deviceType = FC.FLIDEVICE_CAMERA

camList = FC.CameraList(interface, deviceType)
camera = FC.Camera(camList, 1)

dev = FC.create(FC.SharedCamera)
shcam = FC.attach(FC.SharedCamera, dev.shmid)

FC.register(shcam,camera)
dims = (800,800)    # image ROI
remcam = FC.RemoteCamera{UInt8}(shcam, dims)

#--- listening
# 1. broadcasting shmid of cmds, state, img, imgBuftime, remote camera monitor
img_shmid = FC.get_shmid(remcam.img)
imgTime_shmid = FC.get_shmid(remcam.imgTime)
cmds_shmid = FC.get_shmid(remcam.cmds)
shmids = [img_shmid,imgTime_shmid,cmds_shmid]
FC.broadcast_shmids(shmids)

## 2. initialize the server
RemoteCameraEngine = FC.listening(shcam, remcam)

## This rest of the code is supposed to be done by a remote client
begin
    remcam.cmds[1] = FC._to_Cint(SC.CMD_INIT)
    notify(remcam.no_cmds)
end

## 3. configure camera
# update ImageConfigContext in shared camera
new_conf = FC.ImageConfigContext()
#  milli exposure time
new_conf.exposuretime = 50.0
# ROI
new_conf.width = 800
new_conf.height = 800
new_conf.offsetX = (1600-new_conf.width )/2
new_conf.offsetY = (1200-new_conf.height)/2

## configure
FC.set_img_config(shcam,new_conf)

begin
    remcam.cmds[1] = SC._to_Cint(SC.CMD_CONFIG)
    notify(remcam.no_cmds)
end

## 4. start acquisition
begin
    remcam.cmds[1] = SC._to_Cint(SC.CMD_WORK)
    notify(remcam.no_cmds)
end

# 5. stop acquisition
begin
    remcam.cmds[1] = SC._to_Cint(SC.CMD_STOP)
    notify(remcam.no_cmds)
end

#6. update and restart acquisition
begin
    remcam.cmds[1] = SC._to_Cint(SC.CMD_UPDATE)
    notify(remcam.no_cmds)
end
