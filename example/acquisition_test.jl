#   Basic example to play around image configuration
# take the number of images as specified and save to bmp/png format

using FLICameras

interface = FLICameras.FLIDOMAIN_USB
deviceType = FLICameras.FLIDEVICE_CAMERA

camList = FLICameras.CameraList(interface, deviceType)
camera = FLICameras.Camera(camList, 1)

FLICameras.initialize(camera)

# image configuration context
imgConfig = FLICameras.ImageConfigContext()
format = ".bmp"
numImage = 5

# save images
acquire_n_save_image(camera,numImage, imgConfig, format)
