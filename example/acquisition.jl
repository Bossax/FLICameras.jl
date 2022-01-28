using FLICameras

interface = FLICameras.FLIDOMAIN_USB
deviceType = FLICameras.FLIDEVICE_CAMERA

camList = FLICameras.CameraList(interface, deviceType)
camera = FLICameras.Camera(camList, 1)

# image configuration context
imgConfig = FLICameras.ImageConfigContext()

# allcate variables for image acquisition
new_img = Condition()
empty_buff = Condition()
img_cache = Vector{Ptr{UInt8}}(imgConfig.height,Cvoid)
)
