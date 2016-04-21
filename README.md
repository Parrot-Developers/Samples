Samples
=======
This repo contains sample files to show you how to use the SDK. 

Mobile samples
---------------

The mobile samples use the following architecture:<br/> 
![alt mobile_uml](https://raw.githubusercontent.com/Parrot-Developers/Samples/master/Android/uml/mobile_uml_classes.png)

They are standalone, this means that you can clone this repo and use them without compiling the SDK. To enable this, they will use the precompiled SDK libraries.

The mobile samples show you how to connect, pilot, take pictures, display video stream if available, and download medias from the drone.

They support the following drones:

* Bebop 2
* Bebop 
* JumpingSumo 
* Jumping Race
* Jumping Night
* MiniDrone Rolling Spider
* Airborne Cargo
* Airborne Night


*What if you want to only build an app for the Bebop?
Simply delete other files than*

* *DeviceListActivity*
* *DroneDiscoverer*
* *BebopActivity*
* *BebopVideoView*
* *BebopDrone*
* *SDCardModule*


### iOS
#### [SDKSample](https://github.com/ARDroneSDK3/Samples/tree/master/iOS/SDKSample)
**Use the precompiled SDK (hosted on Github)**:<br/>
Use the buildWithPrecompiledSDK configuration to use the precompiled libraries. (Scheme->Edit Scheme

**Use your own compiled SDK**:<br/>
You can build this sample with Alchemy. In your `<SDK>` execute this command:

`./build.sh -p arsdk-ios -t build-sample`

If you prefer to build directly from XCode, use the buildWithLocalSDK configuration to use the precompiled libraries. 


### Android
#### [SDKSample](https://github.com/ARDroneSDK3/Samples/tree/master/Android/SDKSample)

**Use the precompiled SDK (hosted on JCenter)**:<br/>
With Android Studio, open the settings.gradle located in `SDKSample/buildWithPrecompiledSDK`. 

**Use your own compiled SDK**:<br/>
You can build this sample with Alchemy. In your `<SDK>` execute this command:

`./build.sh -p arsdk-android -t build-sample`

Otherwise, if you want to use Android Studio build, first execute this command in `<SDK>`:
`./build.sh -p arsdk-android -t build-sample-jni`

Then, in Android Studio, open the settings.gradle located in `SDKSample/buildWithLocalSDK`.

### Unix
#### [JSPilotingNewAPI](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JSPilotingNewAPI)
This example enables you to **connect** to a JumpingSumo and **send and receive commands** to pilot it and get its battery level. It also **receives the video stream**. <br/>**It uses the new and simplified API (ARController)**

#### [JumpingSumoReceiveStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoReceiveStream)
This example enables you to **connect** to a JumpingSumo and **receive the video stream**.
Two options are available : either display the stream (using ffplay) or store frames on the file system.

#### [BebopDroneReceiveStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/BebopDroneReceiveStream)
This example enables you to **connect** to a Bebop drone and **receive the h264 video stream**.

#### [BebopDroneDecodeStream](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/BebopDroneDecodeStream)
This example enables you to **connect** to a Bebop, **send commands** to pilot it, **receive the h264 video stream**, **decode it**, and display this decoded stream.

External contributions
----------------------
Contributions from external developers are located in the `Contributions` folder, then sorted again by OS.
The name of the contributors/authors for each samples are written in the `Contributions/CONTRIBUTORS.txt` file.
