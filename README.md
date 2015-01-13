Samples
=======
This repo contains sample files to show you how to use the SDK. 

Runnable samples
---------------

#### [JumpingSumoChangePosture](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoChangePosture)
This example enables you to **connect** to a JumpingSumo and **send a command** to change its posture.

#### [JumpingSumoReceiveStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoReceiveStream)
This example enables you to **connect** to a JumpingSumo and **receive the video stream**.
Two options are available : either display the stream (using ffplay) or store frames on the file system.

Non runnable samples
-------------------
They are located in the Android and iOS folders.
You can't compile them because of missing files. They are here to give you a full example on how to create the interface between drones and the controllers.

The device controllers are used as an interface between the products and the controller.

* MiniDroneDeviceController is used to control the RollingSpider
* JumpingSumoDeviceController is used to control the JumpingSumo
* Drone3DeviceController is used to control the Bebop drone
