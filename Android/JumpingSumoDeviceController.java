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

import java.util.HashMap;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.arsdk.arcommands.ARCOMMANDS_GENERATOR_ERROR_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_SIMPLEANIMATION_ID_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_AUDIOSETTINGS_THEME_THEME_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_NETWORK_WIFISCAN_BAND_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCommand;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.arnetwork.ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM;
import com.parrot.arsdk.arsal.ARSALPrint;
import com.parrot.freeflight3.recordcontrollers.ARDrone3PhotoRecordController;
import com.parrot.freeflight3.recordcontrollers.ARDrone3VideoRecordController;
import com.parrot.freeflight3.recordcontrollers.JumpingSumoPhotoRecordController;
import com.parrot.freeflight3.recordcontrollers.JumpingSumoVideoRecordController;

public class JumpingSumoDeviceController extends JumpingSumoDeviceControllerAndLibARCommands implements DeviceControllerVideoStreamControl
{
    private static final String TAG = JumpingSumoDeviceController.class.getSimpleName();
    public static String JumpingSumoDeviceControllerFlyingStateChangedNotification = "JumpingSumoDeviceControllerFlyingStateChangedNotification";
    public static String JumpingSumoDeviceControllerFlyingState = "JumpingSumoDeviceControllerFlyingState";
    public static String JumpingSumoDeviceControllerEmergencyStateChangedNotification = "JumpingSumoDeviceControllerEmergencyStateChangedNotification";
    public static String JumpingSumoDeviceControllerEmergencyState = "JumpingSumoDeviceControllerEmergencyState";
    
    private static double LOOP_INTERVAL = 0.05;
    private static String DEFAULT_SOUND = "default_sound.wav";
    private static double PI_2 = (Math.PI / 2);
    
    private JumpingSumoState jsState; // Current JumpingSumo state. Lock before use.
    private Lock jsStateLock; // Lock for the JumpingSumo state.
    
    private JumpingSumoVideoRecordController videoRecordController;
    private JumpingSumoPhotoRecordController photoRecordController;
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId)
    {
        if(!isInitialized())
        {
            initialize();
        }
        
        stateLock.lock();
        
        if(intent != null)
        {
            if (state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED)
            {
                /** get the deviceService */
                ARDiscoveryDeviceService extraService = (ARDiscoveryDeviceService) intent.getParcelableExtra(DEVICECONTROLLER_EXTRA_DEVICESERVICE);
                boolean fastReconnection = intent.getBooleanExtra(DEVICECONTROLLER_EXTRA_FASTRECONNECTION, false);
                
                setConfigurations (extraService, fastReconnection);
                
                start ();
            }
            else
            {
                Log.w(TAG, "onStartCommand not effective because device controller is not stopped");
            }
        }
        
        stateLock.unlock();
        
        return super.onStartCommand (intent, flags, startId);
    }
    
    public void initialize ()
    {
        if (!isInitialized())
        {
            jsStateLock = new ReentrantLock ();
            super.initialize ();
        }
    }
    
    public void setConfigurations (ARDiscoveryDeviceService service, boolean fastReconnection)
    {
        JumpingSumoARNetworkConfig netConfig = new JumpingSumoARNetworkConfig();
        
        this.fastReconnection = fastReconnection;
        super.setConfigurations ((ARNetworkConfig) netConfig, service, LOOP_INTERVAL, null);
    }

    /** Method called in a dedicated thread on a configurable interval.
     * @note This is an abstract method that you must override.
     */
    public void controllerLoop ()
    {
        DEVICE_CONTROLER_STATE_ENUM currentState;
        JumpingSumoState localState;
        
        stateLock.lock();
        currentState = state;
        stateLock.unlock();
        
        switch (currentState)
        {
            case DEVICE_CONTROLLER_STATE_STARTED:
                // Make a copy of the drone state.
                jsStateLock.lock();
                localState = (JumpingSumoState) jsState.clone();
                jsStateLock.unlock();
                
                JumpingSumoDeviceController_SendPilotingPCMD(getNetConfig().getC2dNackId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte) (localState.screenFlag ? 1 : 0), (byte)(localState.speed * 100.f), (byte)(localState.turnRatio* 100.f));
                
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
            videoRecordController = new JumpingSumoVideoRecordController(this.getApplicationContext());
            videoRecordController.setDeviceController(this);
            photoRecordController = new JumpingSumoPhotoRecordController(this.getApplicationContext());
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
    
    public JumpingSumoVideoRecordController getVideoRecordController()
    {
        return videoRecordController;
    }
    
    public JumpingSumoPhotoRecordController getPhotoRecordController()
    {
        return photoRecordController;
    }
    
    /***********************
    /* HUD-called methods.
     ***********************/

    public void userChangedSpeed (float speed)
    {
        jsStateLock.lock ();
        jsState.speed = speed;
        jsStateLock.unlock ();
    }

    public void userChangedTurnRatio (float turnRatio)
    {
        jsStateLock.lock ();
        jsState.turnRatio = turnRatio;
        jsStateLock.unlock ();
    }

    public void userChangedScreenFlag (boolean flag)
    {
        jsStateLock.lock ();
        jsState.screenFlag = flag;
        jsStateLock.unlock ();
    }

    public void userChangedPosture (ARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE_ENUM posture)
    {
        /* Send a command immediately */
        JumpingSumoDeviceController_SendPilotingPosture(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, posture);
    }

    public void userChangedJumpMotorSpeed(float speed)
    {
        jsStateLock.lock ();
        jsState.dbgJumpMotorSpeed = speed;
        jsStateLock.unlock ();
    }

    public void userRequestedHighJump ()
    {
        JumpingSumoDeviceController_SendAnimationsJump (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_ENUM.ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_HIGH);
    }
    
    public void userRequestedLongJump ()
    {
        JumpingSumoDeviceController_SendAnimationsJump (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_ENUM.ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_LONG);
    }
    
    public void userRequestedJumpCancel ()
    {
        JumpingSumoDeviceController_SendAnimationsJumpCancel (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }
    
    public void userRequestedJumpStop ()
    {
        JumpingSumoDeviceController_SendAnimationsJumpStop (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }
    
    public void userRequestedJumpLoad ()
    {
        JumpingSumoDeviceController_SendAnimationsJumpLoad (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestedSettingsAudioMasterVolume(byte volume)
    {
        JumpingSumoDeviceController_SendAudioSettingsMasterVolume(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, volume);
    }

    public void userRequestedSettingsAudioTheme(ARCOMMANDS_JUMPINGSUMO_AUDIOSETTINGS_THEME_THEME_ENUM theme)
    {
        Log.d("DEVICE CONTROLLER", "SENDING THEME = " + theme.getValue());
        JumpingSumoDeviceController_SendAudioSettingsTheme(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, theme);
    }

    public void userRequestAnimation (ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_SIMPLEANIMATION_ID_ENUM animation)
    {
        JumpingSumoDeviceController_SendAnimationsSimpleAnimation(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, animation);
    }
    
    public void userRequestDefaultSound ()
    {
        JumpingSumoDeviceController_SendAudioPlaySoundWithName(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, DEFAULT_SOUND);
    }
    
    public void userRequestLeft90 ()
    {
        JumpingSumoDeviceController_SendAnimationAddCapOffset(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (float) -PI_2);
    }
    
    public void userRequestRight90 ()
    {
        JumpingSumoDeviceController_SendAnimationAddCapOffset (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (float) PI_2);
    }
    
    public void userRequestTurnBackLeft ()
    {
        JumpingSumoDeviceController_SendAnimationAddCapOffset (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (float) Math.PI);
    }
    
    public void userRequestTurnBackRight ()
    {
        JumpingSumoDeviceController_SendAnimationAddCapOffset (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (float) -Math.PI);
    }
    
    public void userRequestRecordPicture (byte massStorageId)
    {
        JumpingSumoDeviceController_SendMediaRecordPicture (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, massStorageId);
    }
    
    public void userRequestRecordVideoStart (byte massStorageId)
    {
        JumpingSumoDeviceController_SendMediaRecordVideo (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_ENUM.ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_START, massStorageId);    }
    
    public void userRequestRecordVideoStop (byte massStorageId)
    {
        JumpingSumoDeviceController_SendMediaRecordVideo (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_ENUM.ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_STOP, massStorageId);
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
    
    public void userUploadedScript ()
    {
        JumpingSumoDeviceController_SendUserScriptUserScriptUploaded (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestedSettingsNetworkWifiType (ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_TYPE_ENUM type, ARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_BAND_ENUM band, byte channel)
    {
        JumpingSumoDeviceController_SendNetworkSettingsWifiSelection(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, type, band, channel);
    }
    
    public void userRequestedSettingsNetworkWifiScan (ARCOMMANDS_JUMPINGSUMO_NETWORK_WIFISCAN_BAND_ENUM band)
    {
        JumpingSumoDeviceController_SendNetworkWifiScan(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, band);
    }
    
    public void userRequestedSettingsWifiAutoCountry(boolean isAutomatic)
    {
        byte automatic = (byte) (isAutomatic ? 1 : 0);
        DeviceController_SendSettingsAutoCountry(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, automatic);
    }
    
    public void userRequestedSettingsWifiAuthChannel()
    {
        JumpingSumoDeviceController_SendNetworkWifiAuthChannel(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
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

    public void userRequestAskAllScriptsMetadata()
    {
    	Log.d(TAG, "userRequestAskAllScriptsMetada");
    	JumpingSumoDeviceController_SendRoadPlanAllScriptsMetadata (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }
    
    public void userRequestPlayScript(String uuid)
    {
    	JumpingSumoDeviceController_SendRoadPlanPlayScript(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, uuid);
    }
    
    public void userUploadedScript (String uuid)
    {
        JumpingSumoDeviceController_SendRoadPlanScriptUploaded (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, uuid, "0000");
    }
    
    public void userRequestedDeleteScript(String uuid)
    {
        JumpingSumoDeviceController_SendRoadPlanScriptDelete(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, uuid);
    }
    
    /********************
     * Overridden from generated code (bug fixes)
     */

    /**
     * Called when a command <code>WifiAuthChannelListChanged</code> of class <code>NetworkState</code> in project <code>JumpingSumo</code> is decoded
     * @param band The band of this channel : 2.4 GHz or 5 GHz
     * @param channel The authorized channel.
     * @param in_or_out Bit 0 is 1 if channel is authorized outside (0 otherwise) ; Bit 1 is 1 if channel is authorized inside (0 otherwise)
     */
    @Override
    public void onJumpingSumoNetworkStateWifiAuthChannelListChangedUpdate (ARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND_ENUM band, byte channel, byte in_or_out)
    {
        /* dictionary of update */
        Bundle updateDictionary = new Bundle();
        Bundle notificationBundle = new Bundle();
        notificationBundle.putInt(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationBandKey, band.getValue());
        notificationBundle.putByte(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationChannelKey, channel);
        notificationBundle.putByte(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationIn_or_outKey, in_or_out);
        
        Bundle listDictionary = notificationDictionary.getBundle( JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        if(listDictionary == null)
        {
            listDictionary = new Bundle();
        }
        listDictionary.putBundle(String.format("%s", listDictionary.size()), notificationBundle);
        notificationBundle = listDictionary;
        
        updateDictionary.putBundle(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification, notificationBundle);
        
        /* update the NotificationDictionary */
        notificationDictionary.putBundle(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification, notificationBundle);
        
        /* send NotificationDictionaryChanged */
        Intent intentDicChanged = new Intent (DeviceControllerNotificationDictionaryChanged);
        intentDicChanged.putExtras (updateDictionary);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intentDicChanged);
        
        /* send notification dedicated */
        //Intent intent = jumpingSumoDeviceControllerIntentCache.get(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        Intent intent = new Intent (JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
        intent.putExtras (notificationBundle);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
    }
    
    public void cleanNetworkStateWifiAuthChannelListChangedNotificationDictionary() 
    {
        notificationDictionary.remove(JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification);
    }
    
    
    
    /**
     * Called when a command <code>WifiScanListChanged</code> of class <code>NetworkState</code> in project <code>JumpingSumo</code> is decoded
     * @param ssid SSID of the AP
     * @param rssi RSSI of the AP in dbm (negative value)
     * @param band The band : 2.4 GHz or 5 GHz
     * @param channel Channel of the AP
     */
    @Override
    public void onJumpingSumoNetworkStateWifiScanListChangedUpdate (String ssid, short rssi, ARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFISCANLISTCHANGED_BAND_ENUM band, byte channel)
    {
        /* dictionary of update */
        Bundle updateDictionary = new Bundle();
        Bundle notificationBundle = new Bundle();
        notificationBundle.putString(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationSsidKey, ssid);
        notificationBundle.putShort(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationRssiKey, rssi);
        notificationBundle.putInt(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationBandKey, band.getValue());
        notificationBundle.putByte(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationChannelKey, channel);
        
        Bundle listDictionary = notificationDictionary.getBundle( JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification);
        if(listDictionary == null)
        {
            listDictionary = new Bundle();
        }
        listDictionary.putBundle(String.format("%s", listDictionary.size()), notificationBundle);
        notificationBundle = listDictionary;
        
        updateDictionary.putBundle(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification, notificationBundle);
        
        /* update the NotificationDictionary */
        notificationDictionary.putBundle(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification, notificationBundle);
        
        /* send NotificationDictionaryChanged */
        Intent intentDicChanged = new Intent (DeviceControllerNotificationDictionaryChanged);
        intentDicChanged.putExtras (updateDictionary);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intentDicChanged);
        
        /* send notification dedicated */
        //Intent intent = jumpingSumoDeviceControllerAndLibARCommandsIntentCache.get(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification);
        Intent intent = new Intent (JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification);
        intent.putExtras (notificationBundle);
        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(intent);
    }
    
    public void cleanNetworkStateWifiScanListChangedNotificationDictionary() 
    {
        notificationDictionary.remove(JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification);
    }
    
    
    
    
    /*********************
     * Send notifications
     *********************/
    
    /***********************************
     * Miscellaneous private methods.
     ***********************************/
    
    void initDeviceState ()
    {
        jsStateLock.lock();
        jsState = new JumpingSumoState();
        jsStateLock.unlock();
    }

    private class JumpingSumoState implements Cloneable
    {
        /* Screen flag state */
        private boolean screenFlag;
        
        /* Target speed and turn ration. Sent each loop*/
        private float speed;
        private float turnRatio;
        
        /* Jump motor speed (manual override) */
        private float dbgJumpMotorSpeed;
        
        /* Local state we want to set to the remote device */
        /* Nothing yet ... */
        
        public JumpingSumoState ()
        {
            screenFlag = false;
            speed = 0.0f;
            turnRatio = 0.0f;
            dbgJumpMotorSpeed = 0.0f;
            
        }
        
        public Object clone() 
        {
            JumpingSumoState other = null;
            try
            {
                /* get instance with super.clone() */
                other = (JumpingSumoState) super.clone();
            }
            catch(CloneNotSupportedException cnse)
            {
                cnse.printStackTrace(System.err);
            }
            
            other.screenFlag = screenFlag;
            other.speed = speed;
            other.turnRatio = turnRatio;
            other.dbgJumpMotorSpeed = dbgJumpMotorSpeed;
            
            return other;
        }
    }

	@Override
	public boolean supportsVideoStreamingControl()
	{
		boolean retval = false;
		ARBundle dict = this.getNotificationDictionary();
		if (dict.containsKey(JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey))
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
		if (dict.containsKey(JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey))
		{
			retval = dict.getBoolean(JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey);
		}
		// NO ELSE: Keep the default value (true).
		return retval;
	}

	@Override
	public void enableVideoStreaming(boolean enable)
	{
		JumpingSumoDeviceController_SendMediaStreamingVideoEnable(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null, (byte)(enable ? 1 : 0));
		
	}
}
