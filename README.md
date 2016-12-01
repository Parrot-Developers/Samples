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
* Swing
* Mambo

And the following remote controller:

* SkyController
* SkyController 2


*What if you want to only build an app for the Bebop?
Simply delete other files than*

* *DeviceListActivity*
* *DroneDiscoverer*
* *BebopActivity*
* *BebopVideoView*
* *BebopDrone*
* *SDCardModule*

As said before, each mobile sample can be used without having to build the SDK: it will use the precompiled libraries. But you can also use the sample with your own compiled SDK.

### iOS
#### [SDKSample](https://github.com/ARDroneSDK3/Samples/tree/master/iOS/SDKSample)
**Use the precompiled SDK (hosted on Github)**:<br/>
Use the buildWithPrecompiledSDK configuration to use the precompiled libraries (Product->Scheme->Edit Scheme).<br/>
Please note that the first time you'll build with the precompiled SDK, it will download the precompiled libraries from Github, this might take a while.<br/>
By using the precompiled libraries, you don't need to download the sdk source files neither to compile the sdk.

**Use your own compiled SDK**:<br/>
You can build this sample with Alchemy. In your `<SDK>` execute this command:

`./build.sh -p arsdk-ios -t build-sample -j` for iOS
`./build.sh -p arsdk-ios_sim -t build-sample -j` for iOS simulator

Otherwise, if you want to use Xcode to build, first execute this command in `<SDK>`:<br/>
`./build.sh -p arsdk-ios -t build-sdk`<br/>

Then, in XCode, use the buildWithLocalSDK configuration to use your freshly compiled sdk  libraries. (Product->Scheme->Edit Scheme).

**Please note that there are two targets in the iOS sample: SDKSample and SDKSampleForSkyController2.<br/>The first one is using *-lardiscoverywithouteacc* in its Other Linker Flags list and does not include the ExternalAccessory framework. However SDKSampleForSkyController2 uses *-lardiscovery* and includes ExternalAccessory framework.**

### Android
#### [SDKSample](https://github.com/ARDroneSDK3/Samples/tree/master/Android/SDKSample)

**Use the precompiled SDK (hosted on JCenter)**:<br/>
With Android Studio, open the settings.gradle located in `SDKSample/buildWithPrecompiledSDK`.<br/>
By using the precompiled SDK, you don't need to download the sdk source files neither to compile the sdk. 

**Use your own compiled SDK**:<br/>
You can build this sample with Alchemy. In your `<SDK>` execute this command:

`./build.sh -p arsdk-android -t build-sample`

Otherwise, if you want to use Android Studio build, first execute this command in `<SDK>`:
`./build.sh -p arsdk-android -t build-sample-jni`

Then, in Android Studio, open the settings.gradle located in `SDKSample/buildWithLocalSDK`.

Native samples
---------------

#### [BebopSample](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/BebopSample)
This example enables you to **connect** to a Bebop drone and **send and receive commands** to pilot it and get its battery level. It also **receives the video stream**. <br/>

To use it, you'll need to [download](http://developer.parrot.com/docs/SDK3/#download-all-sources) and [compile your own sdk](http://developer.parrot.com/docs/SDK3/#how-to-build-the-sdk).<br/>
Once done, in the sdk root folder, you can build the sample:<br/>
`./build.sh -p arsdk-native -t build-sample-BebopSample -j`
Then run it:<br/>
`./out/arsdk-native/staging/native-wrapper.sh ./out/arsdk-native/staging/usr/bin/BebopSample`

or if you are on a MacOs computer:<br/>
`./out/arsdk-native/staging/native-darwin-wrapper.sh ./out/arsdk-native/staging/usr/bin/BebopSample`

#### [JumpingSumoSample](https://github.com/ARDroneSDK3/Samples/tree/master/Unix/JumpingSumoSample)
This example enables you to **connect** to a JumpingSumo and **send and receive commands** to pilot it and get its battery level. It also **receives the video stream**. <br/>

To use it, you'll need to [download](http://developer.parrot.com/docs/SDK3/#download-all-sources) and [compile your own sdk](http://developer.parrot.com/docs/SDK3/#how-to-build-the-sdk).<br/>
Once done, in the sdk root folder, you can build the sample:<br/>
`./build.sh -p arsdk-native -t build-sample-JumpingSumoSample -j`
Then run it:<br/>
`./out/arsdk-native/staging/native-wrapper.sh ./out/arsdk-native/staging/usr/bin/JumpingSumoSample`

or if you are on a MacOs computer:<br/>
`./out/arsdk-native/staging/native-darwin-wrapper.sh ./out/arsdk-native/staging/usr/bin/JumpingSumoSample`

External contributions
----------------------
Contributions from external developers are located in the `Contributions` folder, then sorted again by OS.
The name of the contributors/authors for each samples are written in the `Contributions/CONTRIBUTORS.txt` file.
