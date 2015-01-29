/*
    Copyright (C) 2014 Parrot SA

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the 
      distribution.
    * Neither the name of Parrot nor the names
      of its contributors may be used to endorse or promote products
      derived from this software without specific prior written
      permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.
*/
package com.parrot.freeflight3.devicecontrollers;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_ANIMATIONS_FLIP_DIRECTION_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_NETWORK_WIFISCAN_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_PICTURESETTINGS_AUTOWHITEBALANCESELECTION_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_PICTURESETTINGS_PICTUREFORMATSELECTION_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_GENERATOR_ERROR_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORK_WIFISCAN_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCommand;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.argraphics.ARFragment;
import com.parrot.arsdk.arnetwork.ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM;
import com.parrot.arsdk.arsal.ARSALPrint;
import com.parrot.freeflight3.recordcontrollers.ARDrone3PhotoRecordController;
import com.parrot.freeflight3.recordcontrollers.ARDrone3VideoRecordController;

import java.util.HashMap;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class ARDrone3DeviceController extends ARDrone3DeviceControllerAndLibARCommands implements DeviceControllerVideoStreamControl
{
    public static String ARDrone3DeviceControllerFlyingStateChangedNotification = "ARDrone3DeviceControllerFlyingStateChangedNotification";
    public static String ARDrone3DeviceControllerFlyingState = "ARDrone3DeviceControllerFlyingState";
    public static String ARDrone3DeviceControllerEmergencyStateChangedNotification = "ARDrone3DeviceControllerEmergencyStateChangedNotification";
    public static String ARDrone3DeviceControllerEmergencyState = "ARDrone3DeviceControllerEmergencyState";
    
    private static String TAG = ARDrone3DeviceController.class.getSimpleName();
    private static double LOOP_INTERVAL = 0.025;
    
    private ARDrone3State droneState; // Current ARDrone3 state. Lock before use.
    private Lock droneStateLock; // Lock for the ARDrone3 state.
    
    private ARDrone3VideoRecordController videoRecordController;
    private ARDrone3PhotoRecordController photoRecordController;
    
    private HashMap<String, Intent> intentCache;
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId)
    {
        if(!isInitialized())
        {
            initialize();
        }
        
        stateLock.lock();
        
        if (state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED)
        {
            if (null != intent)
            {
                /** get the deviceService */
                ARDiscoveryDeviceService extraService = (ARDiscoveryDeviceService) intent.getParcelableExtra(DEVICECONTROLLER_EXTRA_DEVICESERVICE);
                boolean fastReconnection = intent.getBooleanExtra(DEVICECONTROLLER_EXTRA_FASTRECONNECTION, false);
                String deviceControllerBridgeClassName = intent.getStringExtra(DEVICECONTROLLER_EXTRA_DEVICECONTROLER_BRIDGE);
                Class<? extends DeviceController> deviceControllerBridgeClass = null;
                if(deviceControllerBridgeClassName != null)
                {
                    try
                    {
                        Class<?> cls = Class.forName(deviceControllerBridgeClassName);
                        
                        if (DeviceController.class.isAssignableFrom(cls))
                        {
                            deviceControllerBridgeClass = (Class<? extends DeviceController>) cls;
                        }
                    }
                    catch (ClassNotFoundException e)
                    {
                        //do nothing
                    }
                }
                
                setConfigurations (extraService, fastReconnection, deviceControllerBridgeClass);
    
                start ();
            }
            else
            {
                Log.e(TAG, "Can't start device controller");
            }
        }
        else
        {
            Log.w(TAG, "onStartCommand not effective because device controller is not stopped");
        }
        
        stateLock.unlock();
        
        return super.onStartCommand (intent, flags, startId);
    }
    
    public void initialize ()
    {
        if(!isInitialized())
        {
            droneStateLock = new ReentrantLock ();
            initARDrone3DeviceControllerIntents ();
            super.initialize ();
        }
    }
    
    public void setConfigurations (ARDiscoveryDeviceService service, boolean fastReconnection, Class<? extends DeviceController> dcBridgeClass)
    {
        ARDrone3ARNetworkConfig netConfig = new ARDrone3ARNetworkConfig();
        
        this.fastReconnection = fastReconnection;
        super.setConfigurations((ARNetworkConfig) netConfig, service, LOOP_INTERVAL, dcBridgeClass);
    }
    
    private void initARDrone3DeviceControllerIntents ()
    {
        intentCache = new HashMap<String, Intent>(2);
        intentCache.put(ARDrone3DeviceControllerFlyingStateChangedNotification, new Intent (ARDrone3DeviceControllerFlyingStateChangedNotification));
        intentCache.put(ARDrone3DeviceControllerEmergencyStateChangedNotification, new Intent (ARDrone3DeviceControllerEmergencyStateChangedNotification));
    }
    
    protected Intent getARDrone3DeviceControllerIntent (String name)
    {
        return intentCache.get(name) ;
    }
    
    /** Method called in a dedicated thread on a configurable interval.
     * @note This is an abstract method that you must override.
     */
    public void controllerLoop ()
    {
        DEVICE_CONTROLER_STATE_ENUM currentState;
        ARDrone3State localState;
         
        stateLock.lock();
        currentState = state;
        stateLock.unlock();
        
        switch (currentState)
        {
            case DEVICE_CONTROLLER_STATE_STARTED:
                
                // Make a copy of the drone state.
                droneStateLock.lock();
                localState = (ARDrone3State) droneState.clone();
                droneStateLock.unlock();
                
                ARDrone3DeviceController_SendPilotingPCMD (getNetConfig().getC2dNackId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte)(localState.pilotingData.active ? 1 : 0), (byte)(localState.pilotingData.roll * 100.f), (byte)(localState.pilotingData.pitch * 100.f), (byte)(localState.pilotingData.yaw * 100.f), (byte)(localState.pilotingData.gaz * 100.f), localState.pilotingData.heading);
                ARDrone3DeviceController_SendCameraOrientation (getNetConfig().getC2dNackId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte)(localState.cameraData.tilt), (byte)(localState.cameraData.pan));
                
                break;
                
            case DEVICE_CONTROLLER_STATE_STOPPING:
            case DEVICE_CONTROLLER_STATE_STARTING:
            case DEVICE_CONTROLLER_STATE_STOPPED:
            default:
                // DO NOT SEND DATA
                break;
        }
    }
    
    /**
     * Request a stopped controller to start.
     * @note This is an abstract method that you must override.
     */
    public void start ()
    {
        startThread();
    }
    
    /**
     * Request a started controller to stop.
     * @note This is an abstract method that you must override.
     */
    public void stop ()
    {
        stopThread();
    }
    
    /**
     * Request a started controller to pause.
     * @note This is an abstract method that you must override.
     */
    public void pause (boolean pause)
    {
    }
    
    /**
     * Get the current state of the controller.
     * @return current state
     */
    public DEVICE_CONTROLER_STATE_ENUM getState ()
    {
        return state;
    }

    @Override
    public void networkDidSendFrame(NetworkNotificationData notificationData)
    {
        
    }

    @Override
    public void networkDidReceiveAck(NetworkNotificationData notificationData)
    {
        if (notificationData != null)
        {
            notificationData.notificationRun();
        }
    }

    @Override
    public void networkTimeoutOccurred(NetworkNotificationData notificationData)
    {
        
    }

    @Override
    public void networkDidCancelFrame(NetworkNotificationData notificationData)
    {
        if (notificationData != null)
        {
            notificationData.notificationRun();
        }
        
    }
    
    @Override
    boolean doStart()
    {
        boolean failed = !super.doStart();
        
        if (!failed)
        {
            videoRecordController = new ARDrone3VideoRecordController(this.getApplicationContext());
            videoRecordController.setDeviceController(this);
            photoRecordController = new ARDrone3PhotoRecordController(this.getApplicationContext());
            photoRecordController.setDeviceController(this);
        }
        return !failed;
    }
    
    @Override
    void doStop()
    {
        if (videoRecordController != null)
        {
            videoRecordController.setDelegate(null);
            videoRecordController.setDeviceController(null);
            videoRecordController = null;
        }
        if (photoRecordController != null)
        {
            photoRecordController.setDelegate(null);
            photoRecordController.setDeviceController(null);
            photoRecordController = null;
        }
        super.doStop();
    }
    
    public ARDrone3VideoRecordController getVideoRecordController()
    {
        return videoRecordController;
    }
    
    public ARDrone3PhotoRecordController getPhotoRecordController()
    {
        return photoRecordController;
    }
    
    /***********************
    /* HUD-called methods.
     ***********************/
    public boolean flyingState ()
    {
        boolean retval;
        droneStateLock.lock();
        retval = droneState.flying;
        droneStateLock.unlock();
        return retval;
    }

    public boolean emergencyState ()
    {
        boolean retval;
        droneStateLock.lock ();
        retval = droneState.emergency;
        droneStateLock.unlock ();
        return retval;
    }

    public int batteryLevel ()
    {
        int retval;
        droneStateLock.lock ();
        retval = droneState.batteryLevel;
        droneStateLock.unlock ();
        return retval;
    }

    public void userCommandsActivationChanged (boolean activated)
    {
        droneStateLock.lock ();
        droneState.pilotingData.active = activated;
        droneStateLock.unlock ();
    }

    public void userGazChanged (float gaz)
    {
        droneStateLock.lock ();
        droneState.pilotingData.gaz = gaz;
        droneStateLock.unlock ();
    }

    public void userPitchChanged (float pitch)
    {
        droneStateLock.lock ();
        droneState.pilotingData.pitch = pitch;
        droneStateLock.unlock ();
    }

    public void userRollChanged (float roll)
    {
        droneStateLock.lock ();
        droneState.pilotingData.roll = roll;
        droneStateLock.unlock ();
    }

    public void userYawChanged (float yaw)
    {
        droneStateLock.lock ();
        droneState.pilotingData.yaw = yaw;
        droneStateLock.unlock ();
    }

    public void userHeadingChanged (float heading)
    {
        droneStateLock.lock ();
        droneState.pilotingData.heading = heading;
        droneStateLock.unlock ();
    }

    public void userChangedCameraTilt (float tilt)
    {
        droneStateLock.lock ();
        droneState.cameraData.tilt = tilt;
        droneStateLock.unlock ();
    }

    public void userChangedCameraPan (float pan)
    {
        droneStateLock.lock ();
        droneState.cameraData.pan = pan;
        droneStateLock.unlock ();
    }

    public void userRequestedPilotingSettingsMaxAltitude(float maxAltitude)
    {
        ARDrone3DeviceController_SendPilotingSettingsMaxAltitude(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxAltitude);
    }

    public void userRequestedPilotingSettingsMaxTilt(float maxTilt)
    {
        ARDrone3DeviceController_SendPilotingSettingsMaxTilt(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxTilt);
    }

    public void userRequestedPilotingSettingsAbsoluteControl(boolean absoluteControl)
    {
        ARDrone3DeviceController_SendPilotingSettingsAbsolutControl(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ((byte) (absoluteControl ? 1 : 0)));
    }

    public void userRequestedEmergency ()
    {
        droneStateLock.lock();
        droneState.emergency = true;
        droneState.flying = false;
        
        // Send the emergency command
        ARDrone3DeviceController_SendPilotingEmergency (getNetConfig().getC2dEmergencyId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null);
        
        // Send notifications.
        postEmergencyStateNotification ();
        postFlyingStateNotification ();
        
        droneStateLock.unlock();
    }

    public void userRequestedTakeOff ()
    {
        droneStateLock.lock ();
        droneState.emergency = false;
        droneState.flying = true;
        
        // Send the emergency command
        ARDrone3DeviceController_SendPilotingTakeOff (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
        
        // Send notifications.
        postEmergencyStateNotification ();
        postFlyingStateNotification ();
        
        droneStateLock.unlock ();
    }

    public void userRequestedLanding ()
    {
        droneStateLock.lock ();
        if (!droneState.emergency)
        {
            droneState.flying = false;
            
            // Send the emergency command
            ARDrone3DeviceController_SendPilotingLanding (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
            
            // Send notifications.
            postFlyingStateNotification ();
        }
        droneStateLock.unlock ();
    }

    public void userRequestedFlatTrim ()
    {
        ARDrone3DeviceController_SendPilotingFlatTrim (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestFlip (ARCOMMANDS_ARDRONE3_ANIMATIONS_FLIP_DIRECTION_ENUM flipDirection)
    {
        ARDrone3DeviceController_SendAnimationsFlip (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, flipDirection);
    }
    
    public void userRequestRecordPicture (byte massStorageId)
    {
        ARDrone3DeviceController_SendMediaRecordPicture (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, massStorageId);
    }
    
    public void userRequestRecordVideoStart (byte massStorageId)
    {
        ARDrone3DeviceController_SendMediaRecordVideo (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_ENUM.ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_START, massStorageId);
    }
    
    public void userRequestRecordVideoStop (byte massStorageId)
    {
        ARDrone3DeviceController_SendMediaRecordVideo (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_ENUM.ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_STOP, massStorageId);
    }

    public void userRequestedSpeedSettingsMaxVerticalSpeed(float maxSpeed)
    {
        ARDrone3DeviceController_SendSpeedSettingsMaxVerticalSpeed(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxSpeed);
    }

    public void userRequestedSpeedSettingsMaxRotationSpeed(float maxSpeed)
    {
        ARDrone3DeviceController_SendSpeedSettingsMaxRotationSpeed(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxSpeed);
    }

    public void userRequestedSpeedSettingsHullProtection(boolean hullProtection)
    {
        ARDrone3DeviceController_SendSpeedSettingsHullProtection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ((byte) (hullProtection ? 1 : 0)));
    }

    public void userRequestedSpeedSettingsOutdoor(boolean outdoor)
    {
        ARDrone3DeviceController_SendSpeedSettingsOutdoor(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ((byte) (outdoor ? 1 : 0)));
    }

    public void userRequestedPictureSettingsSaturation(float saturationValue)
    {
        ARDrone3DeviceController_SendPictureSettingsSaturationSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, saturationValue);
    }

    public void userRequestedPictureSettingsExposition(float expositionValue)
    {
        ARDrone3DeviceController_SendPictureSettingsExpositionSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, expositionValue);
    }

    public void userRequestedPictureSettingsWhiteBalance(ARCOMMANDS_ARDRONE3_PICTURESETTINGS_AUTOWHITEBALANCESELECTION_TYPE_ENUM wb)
    {
        ARDrone3DeviceController_SendPictureSettingsAutoWhiteBalanceSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, wb);
    }

    public void userRequestedPictureSettingsPictureFormat(ARCOMMANDS_ARDRONE3_PICTURESETTINGS_PICTUREFORMATSELECTION_TYPE_ENUM format)
    {
        ARDrone3DeviceController_SendPictureSettingsPictureFormatSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, format);
    }

    public void userRequestedPictureSettingsVideoAutorecordSelection(boolean enabled, byte massStorageId)
    {
        ARDrone3DeviceController_SendPictureSettingsVideoAutorecordSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte) (enabled ? 1 : 0), massStorageId);
    }

    public void userRequestedPictureSettingsTimelapsePictureFormat(boolean enabled, float interval)
    {
        ARDrone3DeviceController_SendPictureSettingsTimelapseSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte) (enabled ? 1 : 0), interval);
    }

    public void userRequestedReturnHome(boolean start)
    {
        ARDrone3DeviceController_SendPilotingNavigateHome(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte)(start ? 1 : 0));
    }

    public void userRequestedUseDrone2Battery(boolean drone2Battery)
    {
        ARDrone3DeviceController_SendBatteryDebugSettingsUseDrone2Battery(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte) (drone2Battery ? 1 : 0));
    }

    public void userRequestedSettingsWifiAutoCountry(boolean isAutomatic)
    {
        byte automatic = (byte) (isAutomatic ? 1 : 0);
        DeviceController_SendSettingsAutoCountry(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, automatic);
    }

    public void userRequestedSettingsWifiCountry(String country)
    {
        DeviceController_SendSettingsCountry(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, country);
    }

    public void userRequestedSettingsWifiOutdoor(boolean isOutdoor)
    {
        byte outdoor = (byte) (isOutdoor ? 1 : 0);
        DeviceController_SendWifiSettingsOutdoorSetting(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, outdoor);
    }

    // This command is not autogenerated, so send it manually.
    public void userEnteredPilotingHud(boolean inHud)
    {
        
            ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
            boolean sentStatus = false;
            ARCommand cmd = new ARCommand();
            
            cmdError = cmd.setCommonControllerStateIsPilotingChanged(inHud ? (byte)1 : (byte)0);
            if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
            {
                /** send the command */
                sentStatus = sendData (cmd, getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null);
                cmd.dispose();
            }
            
            if (sentStatus == false)
            {
                ARSALPrint.e(TAG, "Failed to send isPilotingChanged command.");
            }
            

    }

    public void userRequestedSettingsNetworkWifiType (ARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_TYPE_ENUM type, ARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_BAND_ENUM band, byte channel)
    {
        ARDrone3DeviceController_SendNetworkSettingsWifiSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, type, band, channel);
    }

    public void userRequestedSettingsWifiAuthChannel()
    {
        ARDrone3DeviceController_SendNetworkWifiAuthChannel(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestedSettingsNetworkWifiScan (ARCOMMANDS_ARDRONE3_NETWORK_WIFISCAN_BAND_ENUM band)
    {
        ARDrone3DeviceController_SendNetworkWifiScan(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, band);
    }
    
    /********************
     * Overridden from generated code (bug fixes)
     */
    
    /**
     * Called when a command <code>WifiAuthChannelListChanged</code> of class <code>NetworkState</code> in project <code>ARDrone3</code> is decoded
     * @param band The band of this channel : 2.4 GHz or 5 GHz
     * @param channel The authorized channel.
     * @param in_or_out Bit 0 is 1 if channel is authorized outside (0 otherwise) ; Bit 1 is 1 if channel is authorized inside (0 otherwise)
     */
    @Override
    public synchronized void onARDrone3NetworkStateWifiAuthChannelListChangedUpdate (ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_ENUM band, byte channel, byte in_or_out)
    {
        /* dictionary of update */
        Bundle updateDictionary = new Bundle();
        Bundle notificationBundle = new Bundle();
        notificationBundle.putInt(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationBandKey, (band != null) ? band.getValue() : ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_ENUM.ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_MAX.getValue());
        if (band == null)
        {
            ARSALPrint.e(TAG, "Bad value for argument `band` in WifiAuthChannelListChanged command from the device.");
        }
        notificationBundle.putByte(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationChannelKey, channel);
        notificationBundle.putByte(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationIn_or_outKey, in_or_out);
        
        Bundle listDictionary = notificationDictionary.getBundle( ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        if(listDictionary == null)
        {
            listDictionary = new Bundle();
        }
        listDictionary.putBundle(String.format("%s", listDictionary.size()), notificationBundle);
        notificationBundle = listDictionary;
        
        updateDictionary.putBundle(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification, notificationBundle);
        
        /* update the NotificationDictionary */
        notificationDictionary.putBundle(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification, notificationBundle);
        
        /* send NotificationDictionaryChanged */
        Intent intentDicChanged = new Intent (DeviceControllerNotificationDictionaryChanged);
        intentDicChanged.putExtras (updateDictionary);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intentDicChanged);
        
        /* send notification dedicated */
        //Intent intent = aRDrone3DeviceControllerAndLibARCommandsIntentCache.get(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        Intent intent = new Intent (ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        intent.putExtras (notificationBundle);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
    }

    public void cleanNetworkStateWifiAuthChannelListChangedNotificationDictionary()
    {
        notificationDictionary.remove(ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
    }
    
    /**
     * Called when a command <code>WifiScanListChanged</code> of class <code>NetworkState</code> in project <code>ARDrone3</code> is decoded
     * @param ssid SSID of the AP
     * @param rssi RSSI of the AP in dbm (negative value)
     * @param band The band : 2.4 GHz or 5 GHz
     * @param channel Channel of the AP
     */
    @Override
    public synchronized void onARDrone3NetworkStateWifiScanListChangedUpdate (String ssid, short rssi, ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_ENUM band, byte channel)
    {
        /* dictionary of update */
        Bundle updateDictionary = new Bundle();
        Bundle notificationBundle = new Bundle();
        notificationBundle.putString(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationSsidKey, ssid);
        notificationBundle.putShort(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationRssiKey, rssi);
        notificationBundle.putInt(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationBandKey, (band != null) ? band.getValue() : ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_ENUM.ARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_MAX.getValue());
        if (band == null)
        {
            ARSALPrint.e(TAG, "Bad value for argument `band` in WifiScanListChanged command from the device.");
        }
        notificationBundle.putByte(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationChannelKey, channel);
        
        Bundle listDictionary = notificationDictionary.getBundle( ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification);
        if(listDictionary == null)
        {
            listDictionary = new Bundle();
        }
        synchronized (listDictionary)
        {
            listDictionary.putBundle(String.format("%s", listDictionary.size()), notificationBundle);
        }
        notificationBundle = listDictionary;
        
        updateDictionary.putBundle(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification, notificationBundle);
        
        /* update the NotificationDictionary */
        notificationDictionary.putBundle(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification, notificationBundle);
        
        /* send NotificationDictionaryChanged */
        Intent intentDicChanged = new Intent (DeviceControllerNotificationDictionaryChanged);
        intentDicChanged.putExtras (updateDictionary);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intentDicChanged);
        
        /* send notification dedicated */
        //Intent intent = aRDrone3DeviceControllerAndLibARCommandsIntentCache.get(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification);
        Intent intent = new Intent (ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification);
        intent.putExtras (notificationBundle);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
    }

    public void cleanNetworkStateWifiScanListChangedNotificationDictionary()
    {
        notificationDictionary.remove(ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification);
    }
    
    
    
    
    /*********************
     * Send notifications
     *********************/
    private void postEmergencyStateNotification ()
    {
        droneStateLock.lock ();
        
        Intent intent = getARDrone3DeviceControllerIntent(ARDrone3DeviceControllerEmergencyStateChangedNotification);
        if (intent != null)
        {
            intent.putExtra(ARDrone3DeviceControllerEmergencyState, droneState.emergency);
            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
        }
        else
        {
            ARSALPrint.e(TAG, "failed during getIntent");
        }
        
        droneStateLock.unlock ();
    }

    private void postFlyingStateNotification ()
    {
        droneStateLock.lock ();
        
        Intent intent = getARDrone3DeviceControllerIntent(ARDrone3DeviceControllerFlyingStateChangedNotification);
        if (intent != null)
        {
            intent.putExtra(ARDrone3DeviceControllerFlyingState, droneState.flying);
            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
        }
        else
        {
            ARSALPrint.e(TAG, "failed during getIntent");
        }
        
        droneStateLock.unlock ();
    }
    

    /***********************************
     * Miscellaneous private methods.
     ***********************************/

    void initDeviceState ()
    {
        droneStateLock.lock();
        droneState = new ARDrone3State();
        droneStateLock.unlock();
    }

    private class ARDrone3State implements Cloneable
    {
        private ARDrone3PilotingData pilotingData;
        private boolean flying; // Whether the drone is currently flying.
        private boolean emergency; // Whether the drone is in emergency state.
        private int batteryLevel; // Current battery level in percent.
        private ARDrone3CameraData cameraData;
        
        public ARDrone3State ()
        {
            batteryLevel = 0;
            cameraData = new ARDrone3CameraData ();
            pilotingData = new ARDrone3PilotingData ();
            emergency = false;
            flying = false;
        }
        
        public Object clone() 
        {
            ARDrone3State other = null;
            try
            {
                /* get instance with super.clone() */
                other = (ARDrone3State) super.clone();
            }
            catch(CloneNotSupportedException cnse)
            {
                cnse.printStackTrace(System.err);
            }
            
            other.batteryLevel = batteryLevel;
            other.cameraData = (ARDrone3CameraData) cameraData.clone();
            other.pilotingData = (ARDrone3PilotingData) pilotingData.clone();
            other.emergency = emergency;
            other.flying = flying;
            
            return other;
        }
    }
    
    private class ARDrone3PilotingData implements Cloneable
    {
        private boolean active;
        private float roll;
        private float pitch;
        private float yaw;
        private float gaz;
        private float heading;
        
        public ARDrone3PilotingData ()
        {
            active = false;
            roll = 0.0f;
            pitch = 0.0f;
            yaw = 0.0f;
            gaz = 0.0f;
            heading = 0.0f;
        }
        
        public Object clone() 
        {
            ARDrone3PilotingData other = null;
            try
            {
                /* get instance with super.clone() */
                other = (ARDrone3PilotingData) super.clone();
            }
            catch(CloneNotSupportedException cnse)
            {
                cnse.printStackTrace(System.err);
            }
            
            other.active = active;
            other.roll = roll;
            other.pitch = pitch;
            other.yaw = yaw;
            other.gaz = gaz;
            other.heading = heading;
            
            return other;
        }
    }
    
    private class ARDrone3CameraData implements Cloneable
    {
        private float tilt;
        private float pan;
        
        public ARDrone3CameraData ()
        {
            tilt = 0.0f;
            pan = 0.0f;
        }
        
        public Object clone() 
        {
            ARDrone3CameraData other = null;
            try
            {
                /* get instance with super.clone() */
                other = (ARDrone3CameraData) super.clone();
            }
            catch(CloneNotSupportedException cnse)
            {
                cnse.printStackTrace(System.err);
            }
            
            other.tilt = tilt;
            other.pan = pan;
            
            return other;
        }
    }

    @Override
    public boolean supportsVideoStreamingControl()
    {
        boolean retval = false;
        ARBundle dict = this.getNotificationDictionary();
        if (dict.containsKey(ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey))
        {
            retval = true;
        }
        // NO ELSE: Keep the default value (false).
        return retval;
    }

    @Override
    public boolean isVideoStreamingEnabled()
    {
        boolean retval = true;
        ARBundle dict = this.getNotificationDictionary();
        if (dict.containsKey(ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey))
        {
            retval = dict.getBoolean(ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey);
        }
        // NO ELSE: Keep the default value (true).
        return retval;
    }

    @Override
    public void enableVideoStreaming(boolean enable)
    {
        Log.w(TAG, "enableVideoStreaming: getNetConfig():" + getNetConfig());
        
        ARDrone3DeviceController_SendMediaStreamingVideoEnable(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null, (byte)(enable ? 1 : 0));
        
    }

    public void gpsSettingsSetHome(double latitude, double longitude, double altitude)
    {
        ARDrone3DeviceController_SendGPSSettingsSetHome(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, latitude, longitude, altitude);
    }
}
