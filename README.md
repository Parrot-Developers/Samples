Samples
=======
This repo contains sample files to show you how to use the SDK. 

Runnable samples
---------------

### Unix
#### [JumpingSumoChangePosture](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoChangePosture)
This example enables you to **connect** to a JumpingSumo and **send a command** to change its posture.

#### [JumpingSumoReceiveStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoReceiveStream)
This example enables you to **connect** to a JumpingSumo and **receive the video stream**.
Two options are available : either display the stream (using ffplay) or store frames on the file system.

#### [JumpingSumoPiloting](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoPiloting)
This example enables you to **connect** to a JumpingSumo and **send and receive commands** to pilot it and get its battery level.

#### [BebopDroneReceiveStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/BebopDroneReceiveStream)
This example enables you to **connect** to a Bebop drone and **receive the h264 video stream**.

#### [BebopDroneDecodeStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/BebopDroneDecodeStream)
This example enables you to **connect** to a Bebop, **send commands** to pilot it, **receive the h264 video stream**, **decode it**, and display this decoded stream.

### iOS
#### [RollingSpiderPiloting](https://github.com/ARDroneSDK3/Samples/tree/master/iOS/RollingSpiderPiloting)
This example enables you to **discover** and **connect** to a RollingSpider and **send and receive commands** to pilot it and get its battery level.

#### [BebopDronePiloting](https://github.com/ARDroneSDK3/Samples/tree/master/iOS/BebopDronePiloting)
This example enables you to **discover** and **connect** to a Bebop drone, **send and receive commands** to pilot it and get its battery level and other states.

### Android
#### [RollingSpiderPiloting](https://github.com/ARDroneSDK3/Samples/tree/master/Android/RollingSpiderPiloting)
This example enables you to **discover** and **connect** to a RollingSpider and **send and receive commands** to pilot it and get its battery level.

#### [BebopDronePiloting](https://github.com/ARDroneSDK3/Samples/tree/master/Android/BebopDronePiloting)
This example enables you to **discover** and **connect** to a Bebop drone, **send and receive commands** to pilot it and get its battery level and other states.

Non runnable samples extracted from FreeFlight3
-------------------

They are located in the Android/FeeFlight3Extract/ and iOS/FeeFlight3Extract/ folders.
You can't compile them because of missing files due to closed sources copyright. They are here to give you a full example on how to create the interface between drones and the controllers.

The device controllers are used as an interface between the products and the controller.

* MiniDroneDeviceController is used to control the RollingSpider
* JumpingSumoDeviceController is used to control the JumpingSumo
* Drone3DeviceController is used to control the Bebop drone
 

External contributions
----------------------
Contributions from external developers are located in the `Contributions` folder, then sorted again by OS.
The name of the contributors/authors for each samples are written in the `Contributions/CONTRIBUTORS.txt` file.
