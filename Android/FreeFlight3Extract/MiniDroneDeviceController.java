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

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.arsdk.arcommands.ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_ENUM;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.arnetwork.ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM;
import com.parrot.freeflight3.recordcontrollers.ARDrone3PhotoRecordController;
import com.parrot.freeflight3.recordcontrollers.ARDrone3VideoRecordController;
import com.parrot.freeflight3.recordcontrollers.JumpingSumoPhotoRecordController;
import com.parrot.freeflight3.recordcontrollers.JumpingSumoVideoRecordController;
import com.parrot.freeflight3.recordcontrollers.MiniDronePhotoRecordController;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import android.os.SystemClock;

public class MiniDroneDeviceController extends MiniDroneDeviceControllerAndLibARCommands
{
	private static double MINI_DRONE_DEVICE_CONTROLLER_FLOOD_CONTROL_STEP = 0.1;
    private static double LOOP_INTERVAL = 0.05;
    private boolean isInPause = false; 
    
    private MiniDroneState droneState; // Current MiniDrone state. Lock before use.
    private Lock droneStateLock; // Lock for the MiniDrone state.
    
    private MiniDronePhotoRecordController photoRecordController;
    
    private long mCurrentLoopInterval;
    
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
        }
        
        stateLock.unlock();
        
        return super.onStartCommand (intent, flags, startId);
    }
    
    public void initialize ()
    {
        if(!isInitialized())
        {
            droneStateLock = new ReentrantLock ();
            super.initialize ();
        }
    }
    
    public void setConfigurations (ARDiscoveryDeviceService service, boolean fastReconnection)
    {
        MiniDroneARNetworkConfig netConfig = new MiniDroneARNetworkConfig();
        
        this.fastReconnection = fastReconnection;
        super.setConfigurations ((ARNetworkConfig) netConfig, service, LOOP_INTERVAL, null);
    }
    
    /** Method called in a dedicated thread on a configurable interval.
     * @note This is an abstract method that you must override.
     */
    public void controllerLoop ()
    {
        DEVICE_CONTROLER_STATE_ENUM currentState;
        MiniDroneState localState;
        boolean isRunning;
        
        stateLock.lock();
        currentState = state;
        isRunning = !isInPause;
        stateLock.unlock();
        
        if (isRunning)
        {
            switch (currentState)
            {
                case DEVICE_CONTROLLER_STATE_STARTED:
                    // Make a copy of the drone state.
                    droneStateLock.lock();
                    localState = (MiniDroneState) droneState.clone();
                    droneStateLock.unlock();
                    
                    MiniDroneDeviceController_SendPilotingPCMD (getNetConfig().getC2dNackId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, (byte)(localState.pilotingData.active ? 1 : 0), (byte)(localState.pilotingData.roll * 100.f), (byte)(localState.pilotingData.pitch * 100.f), (byte)(localState.pilotingData.yaw * 100.f), (byte)(localState.pilotingData.gaz * 100.f), localState.pilotingData.heading);
                    break;
                    
                case DEVICE_CONTROLLER_STATE_STOPPING:
                case DEVICE_CONTROLLER_STATE_STARTING:
                case DEVICE_CONTROLLER_STATE_STOPPED:
                default:
                    // DO NOT SEND DATA
                    break;
            }
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
        stateLock.lock();
        isInPause = pause;
        stateLock.unlock();
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
    protected ControllerLooperThread createNewControllerLooperThread()
    {
    	return new MiniDroneControllerLooperThread();
    }
    
    @Override
    boolean doStart()
    {
        boolean failed = !super.doStart();
        if (!failed)
        {
            photoRecordController = new MiniDronePhotoRecordController(this.getApplicationContext());
            photoRecordController.setDeviceController(this);
        }
        return !failed;
    }
    
    @Override
    void doStop()
    {
        if (photoRecordController != null)
        {
            photoRecordController.setDelegate(null);
            photoRecordController.setDeviceController(null);
            photoRecordController = null;
        }
        super.doStop();
    }
    
    public MiniDronePhotoRecordController getPhotoRecordController()
    {
        return photoRecordController;
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
        droneStateLock.unlock();
    }

    public void userPitchChanged (float pitch)
    {
        droneStateLock.lock ();
        droneState.pilotingData.pitch = pitch;
        droneStateLock.unlock();
    }

    public void userRollChanged (float roll)
    {
        droneStateLock.lock ();
        droneState.pilotingData.roll = roll;
        droneStateLock.unlock();
    }

    public void userYawChanged (float yaw)
    {
        droneStateLock.lock ();
        droneState.pilotingData.yaw = yaw;
        droneStateLock.unlock();
    }

    public void userHeadingChanged (float heading)
    {
        droneStateLock.lock ();
        droneState.pilotingData.heading = heading;
        droneStateLock.unlock();
    }

    public void userRequestedEmergency ()
    {
        /* Send the emergency command */
        MiniDroneDeviceController_SendPilotingEmergency(getNetConfig().getC2dEmergencyId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null);
    }

    public void userRequestedTakeOff ()
    {
        /* Send the emergency command */
        MiniDroneDeviceController_SendPilotingTakeOff(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }
    
    public void userRequestSetAutoTakeOffMode (byte state)
    {
        /* Send the emergency command */
        MiniDroneDeviceController_SendPilotingAutoTakeOffMode(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, state);
    }

    public void userRequestedLanding ()
    {
        /* Send the emergency command */
        MiniDroneDeviceController_SendPilotingLanding(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestedFlatTrim ()
    {
        MiniDroneDeviceController_SendPilotingFlatTrim(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestFlip (ARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION_ENUM flipDirection)
    {
        MiniDroneDeviceController_SendAnimationsFlip(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, flipDirection);
    }
    
    public void userRequestCap (short offset)
    {
        MiniDroneDeviceController_SendAnimationsCap(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, offset);
    }

    public void userRequestedPilotingSettingsMaxAltitude(float maxAltitude)
    {
        MiniDroneDeviceController_SendPilotingSettingsMaxAltitude(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxAltitude);
    }

    public void userRequestedPilotingSettingsMaxTilt(float maxTilt)
    {
        MiniDroneDeviceController_SendPilotingSettingsMaxTilt(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxTilt);
    }

    public void userRequestedSpeedSettingsMaxVerticalSpeed(float maxSpeed)
    {
        MiniDroneDeviceController_SendSpeedSettingsMaxVerticalSpeed(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxSpeed);
    }

    public void userRequestedSpeedSettingsMaxRotationSpeed(float maxSpeed)
    {
        MiniDroneDeviceController_SendSpeedSettingsMaxRotationSpeed(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, maxSpeed);
    }

    public void userRequestedSpeedSettingsWheels(boolean wheels)
    {
        MiniDroneDeviceController_SendSpeedSettingsWheels(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ((byte) (wheels ? 1 : 0)));
    }

    public void userRequestRecordPicture (byte massStorageId)
    {
        MiniDroneDeviceController_SendMediaRecordPicture (getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, massStorageId);
    }
    
    public void userRequestedSettingsCutOut(boolean cutOut)
    {
        MiniDroneDeviceController_SendSettingsCutOutMode(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, ((byte) (cutOut ? 1 : 0)));
    }
    
    /***********************************
     * Miscellaneous private methods.
     ***********************************/

    void initDeviceState ()
    {
        droneStateLock.lock();
        droneState = new MiniDroneState();
        droneStateLock.unlock();
    }
    
    private class MiniDroneControllerLooperThread extends DeviceController.ControllerLooperThread
    {
    	public MiniDroneControllerLooperThread()
        {
            mCurrentLoopInterval = loopInterval;
        }
    	
    	@Override
        public void onloop()
        {
            long lastTime = SystemClock.elapsedRealtime();
            
            controllerLoop();
           
            
            if (mCurrentLoopInterval != loopInterval)
            {
            	mCurrentLoopInterval -= (mCurrentLoopInterval * MINI_DRONE_DEVICE_CONTROLLER_FLOOD_CONTROL_STEP);
            	mCurrentLoopInterval = Math.max(mCurrentLoopInterval, loopInterval);
            }
            
            long sleepTime = (SystemClock.elapsedRealtime() + mCurrentLoopInterval) - lastTime;
            
            try
            {
                Thread.sleep(sleepTime);
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
        }
    }

    private class MiniDroneState implements Cloneable
    {
        private MiniDronePilotingData pilotingData;
         
        public MiniDroneState ()
        {
            pilotingData = new MiniDronePilotingData ();
        }
        
        public Object clone() 
        {
            MiniDroneState other = null;
            try
            {
                /* get instance with super.clone() */
                other = (MiniDroneState) super.clone();
            }
            catch(CloneNotSupportedException cnse)
            {
                cnse.printStackTrace(System.err);
            }
            
            other.pilotingData = (MiniDronePilotingData) pilotingData.clone();
            return other;
        }
    }
    
    private class MiniDronePilotingData implements Cloneable
    {
        private boolean active;
        private float roll;
        private float pitch;
        private float yaw;
        private float gaz;
        private float heading;
        
        public MiniDronePilotingData ()
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
            MiniDronePilotingData other = null;
            try
            {
                /* get instance with super.clone() */
                other = (MiniDronePilotingData) super.clone();
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
}
