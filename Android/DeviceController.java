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

import java.lang.reflect.Method;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import org.json.JSONException;
import org.json.JSONObject;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.os.Binder;
import android.os.Bundle;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.arsdk.arcommands.ARCOMMANDS_COMMON_MAVLINK_START_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_DECODER_ERROR_ENUM;
import com.parrot.arsdk.arcommands.ARCommand;
import com.parrot.arsdk.ardiscovery.ARDISCOVERY_ERROR_ENUM;
import com.parrot.arsdk.ardiscovery.ARDiscoveryConnection;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceBLEService;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceNetService;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.arnetwork.ARNETWORK_ERROR_ENUM;
import com.parrot.arsdk.arnetwork.ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM;
import com.parrot.arsdk.arnetwork.ARNETWORK_MANAGER_CALLBACK_STATUS_ENUM;
import com.parrot.arsdk.arnetwork.ARNetworkIOBufferParam;
import com.parrot.arsdk.arnetwork.ARNetworkManager;
import com.parrot.arsdk.arnetworkal.ARNETWORKAL_ERROR_ENUM;
import com.parrot.arsdk.arnetworkal.ARNetworkALManager;
import com.parrot.arsdk.arrouter.ARRouter;
import com.parrot.arsdk.arrouter.ARRouterDiscoveryConnection;
import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.arsdk.arsal.ARSALPrint;
import com.parrot.freeflight3.utils.DataCollectionUtils;
import com.parrot.freeflight3.utils.DeviceUtils;
import com.parrot.freeflight3.video.ARFrame;
import com.parrot.freeflight3.video.ARStreamManager;
import android.os.SystemClock;

public abstract class DeviceController extends DeviceControllerAndLibARCommands implements NetworkNotificationListener
{
    private static final boolean ENABLE_ARNETWORK_BANWIDTH_MEASURE = false;
    private static final String TAG = DeviceController.class.getSimpleName();
    private static final int DEFAULT_VIDEO_FRAGMENT_SIZE = 1000;
    private static final int DEFAULT_VIDEO_FRAGMENT_MAXIMUM_NUMBER = 128;
    private static final int VIDEO_RECEIVE_TIMEOUT = 500;
    
    public static final String DEVICECONTROLLER_SHARED_PREFERENCES_KEY = "DEVICECONTROLLER_SHARED_PREFERENCES_KEY";
    
    public static final String DeviceControllerWillStartNotification = "DeviceControllerWillStartNotification";
    public static final String DeviceControllerDidStartNotification = "DeviceControllerDidStartNotification";
    public static final String DeviceControllerWillStopNotification = "DeviceControllerWillStopNotification";
    public static final String DeviceControllerDidStopNotification = "DeviceControllerDidStopNotification";
    public static final String DeviceControllerDidFailNotification = "DeviceControllerDidFailNotification";
    public static final String DeviceControllerAllSettingsDidStartNotification = "DeviceControllerAllSettingsDidStartNotification";
    public static final String DeviceControllerAllStatesDidStartNotification = "DeviceControllerAllStatesDidStartNotification";
    public static final String INTENT_EXTRA_DeviceControllerServiceName = "extra_DeviceControllerServiceName";
    public static final String DeviceControllerBLEStackKoNotification = "DeviceControllerBLEStackKoNotification";
    
    public static final String DEVICECONTROLLER_EXTRA_DEVICESERVICE = "com.parrot.freeflight3.DeviceController.extra.deviceservice";
    public static final String DEVICECONTROLLER_EXTRA_FASTRECONNECTION = "com.parrot.freeflight3.DeviceController.extra.fastreconnection";
    public static final String DEVICECONTROLLER_EXTRA_DEVICECONTROLER_BRIDGE = "com.parrot.freeflight3.DeviceController.extra.deviceController.bridge";
    
    private final IBinder binder = new LocalBinder();
    
    protected long loopInterval;
    private DeviceControllerVideoStreamListener videoStreamListener;
    private ARDiscoveryDeviceService deviceService;
    
    private boolean initialized;
    
    private boolean baseControllerStarted;
    protected boolean baseControllerCancelled;
    private boolean allowCommands;
    private ARNetworkConfig netConfig;
    private ARNetworkALManager alManager;
    private ARNetworkManager netManager;
    
    private LooperThread looperThread;
    private VideoThread videoThread;
    
    private List<ReaderThread> readerThreads;
    private Semaphore discoverSemaphore;
    private ARDiscoveryConnection discoveryData;
    private String discoveryIp;
    private int discoveryPort;
    private int c2dPort;
    private int d2cPort;
    private Thread rxThread;
    private Thread txThread;
    private boolean mediaOpened;
    private int videoFragmentSize;
    private int videoFragmentMaximumNumber;
    private int videoMaxAckInterval;
    
    private Thread bwThread;
    //private boolean bwThreadCreated;
    
    /* variables use when sending the final command. */
    private Semaphore disconnectSent;
    
    private Semaphore cmdGetAllSettingsSent;
    private boolean isWaitingAllSettings;
    private Semaphore cmdGetAllStatesSent;
    private boolean isWaitingAllStates;
    private static long INITIAL_TIMEOUT_RETRIEVAL_MS = 5000;
    
    private HashMap<String, Intent> intentCache;

    private boolean routerMustBeInitialized;
    private Semaphore routerInitSem;
    
    private ARRouter router;
    protected ServiceConnection routerConnection = new ServiceConnection()
    {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service)
        {
            router = ((ARRouter.ARBinder) service).getService();

            if(router != null)
            {
                if(routerMustBeInitialized)
                {
                    initiliazeRouter();
                }
                
                if (state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STARTED)
                {
                    router.onConnectionToDeviceCompleted();
                }
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName name)
        {
        }
    };
    
    private boolean bridgeBound = false;
    private Semaphore bridgeConnectionSem;
    private DeviceController deviceControllerBridge;
    protected Class<? extends DeviceController> deviceControllerBridgeClass;
    protected ServiceConnection bridgeConnection = new ServiceConnection()
    {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service)
        {
            deviceControllerBridge = ((DeviceController.LocalBinder) service).getService();
            bridgeConnectionSem.release();
        }

        @Override
        public void onServiceDisconnected(ComponentName name)
        {
            deviceControllerBridge = null;
        }
    };
    
    @Override
    public IBinder onBind(Intent intent)
    {
        return binder;
    }
    
    public class LocalBinder extends Binder
    {
        public DeviceController getService()
        {
            return DeviceController.this;
        }
    }
        
    @Override
    protected void registerARCommandsListener ()
    {
        super.registerARCommandsListener();
    }
    
    @Override
    protected void unregisterARCommandsListener ()
    {
        super.unregisterARCommandsListener();
    }
    
    /**
     * 
     */
    protected void initialize ()
    {
        if(!initialized)
        {
            super.initialize();
            
            stateLock = new ReentrantLock ();
            initDeviceControllerIntents ();
            
            if (DeviceUtils.isSkycontroller())
            {
                bindRouterService();
            }
            
            initialized = true;
        }
    }
    
    protected void setConfigurations (ARNetworkConfig netConfig, ARDiscoveryDeviceService service, double interval, Class<? extends DeviceController> dcBridgeClass)
    {
        //reset the configurations
        state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED;
        
        disconnectSent = new Semaphore (0);
        cmdGetAllSettingsSent = new Semaphore (0);
        cmdGetAllStatesSent = new Semaphore (0);
        isWaitingAllSettings = false;
        isWaitingAllStates = false;
        
        startCancelled = false;
        baseControllerStarted = false;
        baseControllerCancelled = false;
        allowCommands = false;
        
        routerInitSem = new Semaphore (0);
        
        this.netConfig = netConfig;
        this.deviceService = service;
        this.loopInterval = (long) (interval * 1000.0); //TODO: see conversion sec to miliSec
        readerThreads = new ArrayList<ReaderThread>();
        mediaOpened = false;
        
        videoFragmentSize = DEFAULT_VIDEO_FRAGMENT_SIZE;
        videoFragmentMaximumNumber = DEFAULT_VIDEO_FRAGMENT_MAXIMUM_NUMBER;
        videoMaxAckInterval = netConfig.getDefaultVideoMaxAckInterval();
        
        deviceControllerBridgeClass = dcBridgeClass;
    }
    
    private void initDeviceControllerIntents ()
    {
        intentCache = new HashMap<String, Intent>(3);
        intentCache.put(DeviceControllerWillStartNotification, new Intent (DeviceControllerWillStartNotification));
        intentCache.put(DeviceControllerDidStartNotification, new Intent (DeviceControllerDidStartNotification));
        intentCache.put(DeviceControllerWillStopNotification, new Intent (DeviceControllerWillStopNotification));
        intentCache.put(DeviceControllerDidStopNotification, new Intent (DeviceControllerDidStopNotification));
        intentCache.put(DeviceControllerDidFailNotification, new Intent (DeviceControllerDidFailNotification));
        intentCache.put(DeviceControllerAllSettingsDidStartNotification, new Intent (DeviceControllerAllSettingsDidStartNotification));
        intentCache.put(DeviceControllerAllStatesDidStartNotification, new Intent (DeviceControllerAllStatesDidStartNotification));
        intentCache.put(DeviceControllerBLEStackKoNotification, new Intent (DeviceControllerBLEStackKoNotification));
    }
    
    protected Intent getDeviceControllerIntent (String name)
    {
        Intent intent = intentCache.get(name);
        String serviceName = null;
        if (deviceService != null)
        {
            serviceName = deviceService.getName();
        }
        intent.putExtra(INTENT_EXTRA_DeviceControllerServiceName, serviceName);
        //return intentCache.get(name) ;
        return intent;
    }
    
    /**
     * Start the base DeviceController. This method is synchronous.
     * @note This method will block until the controller is started of fails to start.
     * @warning The video listener will be reset to null 
     * @return status code indicates success, any other value gives the reason why the base controller wasn't started.
     */
    protected BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM startBaseController ()
    {
        BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM retval = BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM.BASE_DEVICE_CONTROLLER_START_RETVAL_OK;
        boolean failed = false;
        
        if (baseControllerStarted == false)
        {
            if ((baseControllerCancelled == false)  )
            {
                if(deviceControllerBridgeClass == null)
                {
                    //Classic 
                    failed = startNetwork();
                }
                else
                {
                    //using bridge
                    startBridge();
                }
            }
            
            if ((failed == false) && (baseControllerCancelled == false) && (deviceControllerBridgeClass == null))
            {
                /* start the reader threads */
                startReadThreads();
            }
            
            if ((failed == false) && (baseControllerCancelled == false) && (deviceControllerBridgeClass == null))
            {
                /* start video Thread */
                startVideoThread();
            }
            
            if ((failed == false) && (baseControllerCancelled == false))
            {
                /* start the looper thread */
                startLooperThread();
                
                registerARCommandsListener();
            }
        }
        
        if ((failed == false) && (baseControllerCancelled == false))
        {
            
            baseControllerStarted = true;
            allowCommands = true;
        }
        else
        {
            /* failed to start. Rolling back to clean state. */
            stopBaseController();
        }
        
        /* set the value returned*/
        if(failed)
        {
            retval = BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM.BASE_DEVICE_CONTROLLER_START_RETVAL_FAILD;
        }
        else if (baseControllerCancelled)
        {
            retval = BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM.BASE_DEVICE_CONTROLLER_START_RETVAL_CANCELED;
        }
        
        return retval;
    }
    
    private boolean startNetwork()
    {
        ARNETWORKAL_ERROR_ENUM netALError = ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_OK;
        boolean failed = false;
        int pingDelay = 0; /* 0 means default, -1 means no ping */
        
        /* Create the looper ARNetworkALManager */
        alManager = new ARNetworkALManager();

        if (deviceService.getDevice()  instanceof ARDiscoveryDeviceNetService)
        {
            /* setup ARNetworkAL for wifi */
            
            Log.d(TAG, "alManager.ARDiscoveryDeviceNetService ");
            
            ARDiscoveryDeviceNetService netDevice = (ARDiscoveryDeviceNetService) deviceService.getDevice();
            discoveryIp = netDevice.getIp();
            discoveryPort = netDevice.getPort();
            
            /*  */
            if (!ardiscoveryConnect()) 
            {
                failed = true;
            }
            
            // TODO :  if ardiscoveryConnect ok
            netConfig.addStreamReaderIOBuffer(videoFragmentSize, videoFragmentMaximumNumber);
            
            /* setup ARNetworkAL for wifi */
            netALError = alManager.initWifiNetwork(discoveryIp, c2dPort, d2cPort, 1);
            
            if (netALError == ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_OK)
            {
                mediaOpened = true;
            }
            else
            {
                ARSALPrint.e(TAG, "error occured: " + netALError.toString());
                failed = true;
            }
            
        }
        else if (deviceService.getDevice()  instanceof ARDiscoveryDeviceBLEService)
        {
            /* setup ARNetworkAL for BLE */
            
            Log.d(TAG, "alManager.initBLENetwork netConfig.getBLENotificationIDs(): " +netConfig.getBLENotificationIDs());
            
            ARDiscoveryDeviceBLEService bleDevice = (ARDiscoveryDeviceBLEService) deviceService.getDevice();
            
            netALError = alManager.initBLENetwork(getApplicationContext(), bleDevice.getBluetoothDevice(), 1, netConfig.getBLENotificationIDs());
            
            if (netALError == ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_OK)
            {
                mediaOpened = true;
                pingDelay = -1; /* Disable ping for BLE networks */
            }
            else
            {
                ARSALPrint.e(TAG, "error occured: " + netALError.toString());
                failed = true;
                
                if (netALError == ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_ERROR_BLE_STACK)
                {
                    LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerBLEStackKoNotification));
                }
            }
        }
        else
        {
            ARSALPrint.e (TAG, "Unknow network media type." );
            failed = true;
        }
        
        if ((ENABLE_ARNETWORK_BANWIDTH_MEASURE) && (failed == false) && (baseControllerCancelled == false))
        {
            /* Create and start the bandwidth thread for ARNetworkAL */
            bwThread = new Thread (new Runnable(){
                public void run()
                {
                    //ARNetworkALManager.bandwidthThread();// TODO: add bandwidth JNI
                }
            });
            bwThread.start();
            //bwThreadCreated = true;
        }
        
        if ((failed == false) && (baseControllerCancelled == false))
        {
            /* Create the ARNetworkManager */
            netManager = new ARNetworkManagerExtend(alManager, netConfig.getC2dParams(), netConfig.getD2cParams(), pingDelay);
            
            if (netManager.isCorrectlyInitialized() == false)
            {
                ARSALPrint.e (TAG, "new ARNetworkManager failed");
                failed = true;
            }
        }
        
        if ((failed == false) && (baseControllerCancelled == false))
        {
            /* Create and start Tx and Rx threads */
            rxThread = new Thread (netManager.m_receivingRunnable);
            rxThread.start();
            
            txThread = new Thread (netManager.m_sendingRunnable);
            txThread.start();
        }
        
        /* start rooter for the SkyController */
        if ((failed == false) && (DeviceUtils.isSkycontroller()))
        {
            if(router != null)
            {
                initiliazeRouter();
            }
            else
            {
                routerMustBeInitialized = true;
            }
            
            try
            {
                Boolean routerInitialized = routerInitSem.tryAcquire(INITIAL_TIMEOUT_RETRIEVAL_MS, TimeUnit.MILLISECONDS);
                
                if(!routerInitialized)
                {
                    Log.e(TAG, "failed to initialize router (timeout)" );
                    failed = true;
                }
            }
            catch (InterruptedException e)
            {
                Log.e(TAG, "failed to initialize router" );
                failed = true;
            }
        }
        
        return failed;
    }
    
    private void startReadThreads()
    {
        /* Create the reader threads */
        for (int bufferId : netConfig.getCommandsIOBuffers())
        {
            ReaderThread readerThread = new ReaderThread(bufferId);
            readerThreads.add(readerThread);
        }
        
        /* Mark all reader threads as started */
        for (ReaderThread readerThread : readerThreads)
        {
            readerThread.start();
        }
    }
    
    private void startVideoThread()
    {
        /* Create an ARStreamReader and create the video thread if the target supports video streaming. */
        if (netConfig.hasVideo())
        {
            /* Reset the video listener to prevent forwarding frames to it before we return from this method.*/
            //videoStreamListener = null; //TODO:see
            
            /* create the video thread */
            videoThread = new VideoThread ();
            
            /* Start the video thread. */
            videoThread.start();
        }
    }
    
    private void startLooperThread()
    {
        /* Create the looper thread */
        looperThread = createNewControllerLooperThread();
        
        /* Start the looper thread. */
        looperThread.start();
    }
    
    private void startBridge()
    {
        bridgeConnectionSem = new Semaphore(0);
        
        getApplicationContext().bindService(new Intent(getApplicationContext(), deviceControllerBridgeClass), bridgeConnection, Context.BIND_AUTO_CREATE);
        bridgeBound = true;
        
        try
        {
            //TODO tryAcquire
            bridgeConnectionSem.acquire();
        }
        catch (InterruptedException e)
        {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
    
    private void initiliazeRouter()
    {
        router.setARNetworkControllerToRouterParams(netConfig.getC2dParamsList(), netConfig.getVideoAckIOBuffer());
        router.setARNetworkRouterToControllerParams(netConfig.getD2cParamsList(), netConfig.getVideoDataIOBuffer());
        
        if (router.connect(deviceService))
        {
            routerInitSem.release();
        }
        else
        {
            Log.e(TAG, "Failed to start ARRouter");
        }
    }
     
    public void bindRouterService()
    {
        getApplicationContext().bindService(new Intent(getApplicationContext(), ARRouter.class), routerConnection, Context.BIND_AUTO_CREATE);
    }

    
    /**
     * Stop the base DeviceController.
     * This method is synchronous and will block until the controller is stopped.
     */
    protected void stopBaseController ()
    {
        baseControllerStarted = false;
        
        unregisterARCommandsListener();
        
        /* Cancel the looper thread and block until it is stopped. */
        stopLooperThread();
        
        allowCommands = false;
        
        /* cancel all reader threads and block until they are all stopped. */
        stopReaderThreads();
        
        /* Stop the video streamer */
        stopVideoThread();
        
        /* ARNetwork cleanup */
        stopNetwork();
        
        stopBridge();
        
    }
    
    private void stopLooperThread()
    {
        /* Cancel the looper thread and block until it is stopped. */
        if (null != looperThread)
        {
            looperThread.stopThread();
            try
            {
                looperThread.join();
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
        }
    }
    
    private void stopReaderThreads()
    {
        if(readerThreads != null)
        {
            /* cancel all reader threads and block until they are all stopped. */
            for (ReaderThread thread : readerThreads)
            {
                thread.stopThread();
            }
            for (ReaderThread thread : readerThreads)
            {
                try
                {
                    thread.join();
                }
                catch (InterruptedException e)
                {
                    e.printStackTrace();
                }
            }
            readerThreads.clear();
        }
    }
    
    private void stopVideoThread()
    {
        /* Stop the video streamer */
        if (videoThread != null)
        {
            videoThread.stopThread();
            try
            {
                videoThread.join();
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
        }
    }
    
    private void stopNetwork()
    {
        if (router != null)
        {
            router.disconnect();
        }
        
        if(netManager != null)
        {
            netManager.stop();
            
            try
            {
                if (txThread != null) {
                    txThread.join();
                }
                if (rxThread != null) {
                    rxThread.join();
                }
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
            
            netManager.dispose();
        }
        if ((alManager != null) && (mediaOpened))
        {
            if (deviceService.getDevice() instanceof ARDiscoveryDeviceNetService)
            {
                alManager.closeWifiNetwork();
            }
            else if (deviceService.getDevice() instanceof ARDiscoveryDeviceBLEService)
            {
                alManager.closeBLENetwork(getApplicationContext());
            }
            if ((ENABLE_ARNETWORK_BANWIDTH_MEASURE) && (bwThread != null))
            {
                try
                {
                    bwThread.join();
                }
                catch (InterruptedException e)
                {
                    e.printStackTrace();
                }
            }
            
            mediaOpened = false;
            alManager.dispose();
        }
    }
    
    private void stopBridge()
    {
        if(bridgeBound)
        {
            getApplicationContext().unbindService(this.bridgeConnection);
            bridgeBound = false;
        }
    }
    
    private boolean ardiscoveryConnect()
    {
        boolean ok = true;
        ARDISCOVERY_ERROR_ENUM error = ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_OK;
        discoverSemaphore = new Semaphore (0);
        
        d2cPort = netConfig.getInboundPort();
        if (DeviceUtils.isSkycontroller())
        {
            discoveryData = new ARRouterDiscoveryConnection(getApplicationContext())
            {
                @Override
                protected JSONObject onSendJsonToRouter()
                {
                    /* send a json with the Device to controller port */
                    JSONObject jsonObject = new JSONObject();
                    
                    try
                    {
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_D2CPORT_KEY, d2cPort);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }

                    try
                    {
                        Log.i(TAG, "android.os.Build.MODEL: "+android.os.Build.MODEL);
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_CONTROLLER_NAME_KEY, android.os.Build.DEVICE);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }

                    try
                    {
                        Log.i(TAG, "android.os.Build.DEVICE: "+android.os.Build.DEVICE);
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_CONTROLLER_TYPE_KEY, android.os.Build.MODEL);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }
                    Log.i(TAG, "end onSendJsonToRouter");
                    return jsonObject;
                }
                
                @Override
                protected ARDISCOVERY_ERROR_ENUM onReceiveJsonFromRouter(JSONObject receivedData, String ip)
                {
                    Log.i(TAG, "onReceiveJsonFromRouter");
                    /* Receive a json with the controller to Device port */
                    discoveryIp = ip;
                    ARDISCOVERY_ERROR_ENUM error = ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_OK;
                    try
                    {
                        /* Convert String to json */
                        JSONObject jsonObject = receivedData;

                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_C2DPORT_KEY))
                        {
                            c2dPort = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_C2DPORT_KEY);
                        }

                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_SIZE_KEY))
                        {
                            videoFragmentSize = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_SIZE_KEY);
                        }
                        /* Else: leave it to the default value. */

                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_MAXIMUM_NUMBER_KEY))
                        {
                            videoFragmentMaximumNumber = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_MAXIMUM_NUMBER_KEY);
                        }
                        /* Else: leave it to the default value. */

                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_MAX_ACK_INTERVAL_KEY))
                        {
                            videoMaxAckInterval = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_MAX_ACK_INTERVAL_KEY);
                        }
                        /* Else: leave it to the default value. */
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                        error = ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_ERROR;
                    }
                    Log.i(TAG, "end onReceiveJsonFromRouter");
                    return error;
                }
            };
        }
        else
        {
            discoveryData = new ARDiscoveryConnection()
            {
                @Override
                public String onSendJson ()
                {
                    /* send a json with the Device to controller port */
                    JSONObject jsonObject = new JSONObject();

                    try
                    {
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_D2CPORT_KEY, d2cPort);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }
                    try
                    {
                        Log.e(TAG, "android.os.Build.MODEL: "+android.os.Build.MODEL);
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_CONTROLLER_NAME_KEY, android.os.Build.MODEL);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }
                    try
                    {
                        Log.e(TAG, "android.os.Build.DEVICE: "+android.os.Build.DEVICE);
                        jsonObject.put(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_CONTROLLER_TYPE_KEY, android.os.Build.DEVICE);
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                    }

                    return jsonObject.toString();
                }

                @Override
                public ARDISCOVERY_ERROR_ENUM onReceiveJson (String dataRx, String ip)
                {
                    /* Receive a json with the controller to Device port */
                    ARDISCOVERY_ERROR_ENUM error = ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_OK;
                    try
                    {
                        /* Convert String to json */
                        JSONObject jsonObject = new JSONObject(dataRx);
                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_C2DPORT_KEY))
                        {
                            c2dPort = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_C2DPORT_KEY);
                        }
                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_SIZE_KEY))
                        {
                            videoFragmentSize = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_SIZE_KEY);
                        }
                        /* Else: leave it to the default value. */
                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_MAXIMUM_NUMBER_KEY))
                        {
                            videoFragmentMaximumNumber = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_MAXIMUM_NUMBER_KEY);
                        }
                        /* Else: leave it to the default value. */
                        if (!jsonObject.isNull(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_MAX_ACK_INTERVAL_KEY))
                        {
                            videoMaxAckInterval = jsonObject.getInt(ARDiscoveryConnection.ARDISCOVERY_CONNECTION_JSON_ARSTREAM_MAX_ACK_INTERVAL_KEY);
                        }
                        /* Else: leave it to the default value. */
                    }
                    catch (JSONException e)
                    {
                        e.printStackTrace();
                        error = ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_ERROR;
                    }
                    return error;
                }
            };
        }
        
        if (ok == true)
        {
            /* open the discovery connection data in another thread */
            ConnectionThread connectionThread = new ConnectionThread();
            connectionThread.start();
            /* wait the discovery of the connection data */
            try
            {
                discoverSemaphore.acquire();
                error = connectionThread.getError();
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
            }
            
            /* dispose discoveryData it not needed more */
            discoveryData.dispose();
            discoveryData = null;
        }
        
        return ok && (error == ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_OK);
    }
    
    /**
     * Get the controller loop interval (in seconds).
     * @return loop interval
     */
    protected double getLoopInterval()
    {
        return loopInterval;
    }
    
    /**
     * Set the video listener object. One of its methods will be called for each 
     * received video frame.
     * @param listener
     */
    public void setVideoListener  (DeviceControllerVideoStreamListener listener)
    {
        if (deviceControllerBridgeClass == null)
        {
            videoStreamListener = listener;
        }
        else
        {
            if(deviceControllerBridge != null)
            {
                deviceControllerBridge.setVideoListener(listener);
            }
        }
    }
    
    /**
     * Send raw data through ARNetwork. Optionally notify about delivery status.
     * @Return true if the data was queued, false if it could not.
     */
    @Override
    protected boolean sendData (ARNativeData data, int bufferId, ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM timeoutPolicy, NetworkNotificationData notificationData)
    {
        boolean retVal = true;
        
        if (allowCommands)
        {
            if(deviceControllerBridgeClass != null)
            {
                if(deviceControllerBridge != null)
                {
                    retVal = deviceControllerBridge.sendData (data, bufferId, timeoutPolicy, notificationData);
                }
                else
                {
                    Log.e(TAG, "deviceControllerBridge == null");
                    retVal = false;
                }
            }
            else
            {
                /* prepare sendInfo */
                ARNetworkSendInfo sendInfo = new ARNetworkSendInfo (timeoutPolicy, this, notificationData, this);
                
                /* Send data with ARNetwork */
                ARNETWORK_ERROR_ENUM netError = netManager.sendData (bufferId, data, sendInfo, true);
                
                if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
                {
                    ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                    retVal = false;
                }
            }
        }
        else
        {
//            ARSALPrint.e (TAG, "Cannot send data: Base controller is not startd");
            retVal = false;
        }
        
        return retVal;
    }
    
    protected ARNetworkConfig getNetConfig ()
    {
        return netConfig;
    }
    
    protected void cancelBaseControllerStart()
    {
        if (baseControllerCancelled == false)
        {
            baseControllerCancelled = true;
            if (deviceService.getDevice()  instanceof ARDiscoveryDeviceNetService)
            {
                if (discoveryData != null)
                {
                    discoveryData.ControllerConnectionAbort();
                }
            }
            else if (deviceService.getDevice()  instanceof ARDiscoveryDeviceBLEService)
            {
                alManager.cancelBLENetwork();
            }
            else
            {
                ARSALPrint.e (TAG, "Unknow network media type." );
            }
            cmdGetAllSettingsSent.release();
            cmdGetAllStatesSent.release();
            //TODO see : reset the semaphores or use signals
        }
    }
    
    protected boolean getBaseControllerCancelled()
    {
        return baseControllerCancelled;
    }
    
    protected boolean getInitialSettings()
    {
        /* Attempt to get initial settings */
        boolean successful = true;
        
        isWaitingAllSettings = true;
        if (DeviceController_SendSettingsAllSettings(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null))
        {
            try
            {
                //successful = cmdGetAllSettingsSent.tryAcquire (INITIAL_TIMEOUT_RETRIEVAL_MS, TimeUnit.MILLISECONDS);
                cmdGetAllSettingsSent.acquire();
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
                successful = false;
            }
        }
        else
        {
            successful = false;
        }
        
        isWaitingAllSettings = false;
        
        return successful;
    }
    
    protected boolean getInitialStates()
    {
        /* Attempt to get initial states */
        boolean successful = true;
        
        isWaitingAllStates = true;
        if (DeviceController_SendCommonAllStates(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null))
        {
            try
            {
                //successful = cmdGetAllStatesSent.tryAcquire (INITIAL_TIMEOUT_RETRIEVAL_MS, TimeUnit.MILLISECONDS);
                cmdGetAllStatesSent.acquire();
            }
            catch (InterruptedException e)
            {
                e.printStackTrace();
                successful = false;
            }
        }
        else
        {
            successful = false;
        }
        isWaitingAllStates = false;
        
        return successful;
    }
    
    protected void sendInitialDate(Date currentDate)
    {
        /* Set Date */
        SimpleDateFormat formattedDate = new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault());
        DeviceController_SendCommonCurrentDate(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null, formattedDate.format(currentDate));
    }
    
    protected void sendInitialTime(Date currentDate)
    {
        /* Set Time */
        SimpleDateFormat formattedTime = new SimpleDateFormat("'T'HHmmssZZZ", Locale.getDefault());
        DeviceController_SendCommonCurrentTime(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY, null, formattedTime.format(currentDate));
    }
    
    protected ControllerLooperThread createNewControllerLooperThread()
    {
        return new ControllerLooperThread();
    }
    
    @Override
    public void onCommonSettingsStateAllSettingsChangedUpdate ()
    {
        super.onCommonSettingsStateAllSettingsChangedUpdate();
        if(isWaitingAllSettings)
        {
            cmdGetAllSettingsSent.release();
        }
    }
    
    @Override
    public void onCommonCommonStateAllStatesChangedUpdate ()
    {
        super.onCommonCommonStateAllStatesChangedUpdate();
        if(isWaitingAllStates)
        {
            cmdGetAllStatesSent.release();
        }
    }
    
    public void userRequestedSettingsReset()
    {
        DeviceController_SendSettingsReset(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestedSettingsProductName(String productName)
    {
        DeviceController_SendSettingsProductName(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, productName);
    }
    
    public void userRequestReboot() 
    {
        DeviceController_SendCommonReboot(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    public void userRequestCalibration(byte calibrate)
    {
        DeviceController_SendCalibrationMagnetoCalibration(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, calibrate);
    }
    
    public void userRequestMavlinkPlay(String filepath, ARCOMMANDS_COMMON_MAVLINK_START_TYPE_ENUM type)
    {
        DeviceController_SendMavlinkStart(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null, filepath, type);
    }
    
    public void userRequestMavlinkPause()
    {
    	DeviceController_SendMavlinkPause(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }
    
    public void userRequestMavlinkStop()
    {
    	DeviceController_SendMavlinkStop(getNetConfig().getC2dAckId(), ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP, null);
    }

    protected void registerCurrentProduct()
    {
        SharedPreferences preferences = getSharedPreferences(DEVICECONTROLLER_SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        ARBundle bundle = this.getNotificationDictionary();
        if(bundle != null)
        {
            if (bundle.containsKey(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialHighChangedNotification) &&
                bundle.containsKey(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialLowChangedNotification))
            {
                Bundle settingsStateProductSerialLowChangedNotification = bundle.getBundle(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialLowChangedNotification);
                Bundle settingsStateProductSerialHighChangedNotification = bundle.getBundle(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialHighChangedNotification);
                String lowSerial = settingsStateProductSerialLowChangedNotification.getString(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialLowChangedNotificationLowKey);
                String highSerial = settingsStateProductSerialHighChangedNotification.getString(DeviceControllerAndLibARCommands.DeviceControllerSettingsStateProductSerialHighChangedNotificationHighKey);
                String serial = highSerial + lowSerial;
                
                
                DataCollectionUtils.initiateSerialNumberCollection(this, serial);
                if(preferences.getInt(serial, -1) == -1)
                {
                    SharedPreferences.Editor editor = preferences.edit();
                    editor.putInt(serial, deviceService.getProductID());
                    editor.commit();
                }
            }
        }
    }
    
    /** Method called in a dedicated thread on a configurable interval.
     * @note This is an abstract method that you must override.
     */
    public abstract void controllerLoop ();
    
    /**
     * Request a stopped controller to start.
     * @note This is an abstract method that you must override.
     */
    public abstract void start ();
    
    /**
     * Request a started controller to stop.
     * @note This is an abstract method that you must override.
     */
    public abstract void stop ();
    
    /**
     * Request a started controller to pause.
     * @note This is an abstract method that you must override.
     */
    public abstract void pause (boolean pause);
    
    /**
     * Get the current state of the controller.
     * @return current state
     */
    public abstract DEVICE_CONTROLER_STATE_ENUM getState ();
    
    /**
     * startBaseController status code
     */
    protected enum BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM
    {
        BASE_DEVICE_CONTROLLER_START_RETVAL_OK, /**< The controller started successfully */
        BASE_DEVICE_CONTROLLER_START_RETVAL_CANCELED, /**< The controller start was cancelled */
        BASE_DEVICE_CONTROLLER_START_RETVAL_FAILD; /**< The controller failed to start because an error occurred */
    }
    
    /**
    * Extend of ARNetworkManager implementing the callback
    */
    private class ARNetworkManagerExtend extends ARNetworkManager
    {
        public ARNetworkManagerExtend(ARNetworkALManager osSpecificManager, ARNetworkIOBufferParam[] inputParamArray, ARNetworkIOBufferParam[] outputParamArray, int timeBetweenPingsMs)
        {
            super(osSpecificManager, inputParamArray, outputParamArray, timeBetweenPingsMs);
        }
        
        private static final String TAG = "ARNetworkManagerExtend";
        
        @Override
        public ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM onCallback(int ioBufferId, ARNativeData data, ARNETWORK_MANAGER_CALLBACK_STATUS_ENUM status, Object customData)
        {
            
            ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM retVal = ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DEFAULT;
            ARNetworkSendInfo sendInfo = (ARNetworkSendInfo) customData;
            
            switch (status)
            {
            case ARNETWORK_MANAGER_CALLBACK_STATUS_SENT:
                /* Send notification if requested to. */
                if ((sendInfo != null) && (sendInfo.getNotificationListener() != null))
                {
                    sendInfo.getNotificationListener().networkDidSendFrame (sendInfo.getNotificationData());
                }
                break;
                
            case ARNETWORK_MANAGER_CALLBACK_STATUS_ACK_RECEIVED:
                /* Send notification if requested to. */
                if ((sendInfo != null) &&(sendInfo.getNotificationListener() != null))
                {
                    sendInfo.getNotificationListener().networkDidReceiveAck (sendInfo.getNotificationData());
                }
                break;
                
            case ARNETWORK_MANAGER_CALLBACK_STATUS_TIMEOUT:
                /* Send notification if requested. */
                if ((sendInfo != null) &&(sendInfo.getNotificationListener() != null))
                {
                    sendInfo.getNotificationListener().networkTimeoutOccurred (sendInfo.getNotificationData());
                }
                
                /* Apply sending policy. */
                retVal = sendInfo.getTimeoutPolicy();
                
                break;
                
            case ARNETWORK_MANAGER_CALLBACK_STATUS_CANCEL:
                /* Send notification if requested to. */
                if ((sendInfo != null) && (sendInfo.getNotificationListener() != null))
                {
                    sendInfo.getNotificationListener().networkDidCancelFrame (sendInfo.getNotificationData());
                }
                break;
                
            case ARNETWORK_MANAGER_CALLBACK_STATUS_FREE:
                if (data != null)
                {
                    data.dispose();
                }
                else
                {
                    Log.e (TAG, "no data to free");
                }
                
                break;
                
            case ARNETWORK_MANAGER_CALLBACK_STATUS_DONE:
                break;
                
            default:
                Log.e (TAG, "default case status:"+ status);
                
                break;
            }
            
            return retVal;
        }

        @Override
        public void onDisconnect(ARNetworkALManager alManager)
        {
            Log.w(TAG, "onDisconnect !!!!!");
            DeviceController.this.stop();
        }
    }
    
    private class ConnectionThread extends Thread
    {
        private ARDISCOVERY_ERROR_ENUM error;
        
        public void run()
        {
            error = discoveryData.ControllerConnection(discoveryPort, discoveryIp);
            if (error != ARDISCOVERY_ERROR_ENUM.ARDISCOVERY_OK)
            {
                ARSALPrint.e(TAG, "Error while opening discovery connection : " + error);
            }
            
            /* discoverSemaphore can be disposed */
            discoverSemaphore.release();
        }
        
        public ARDISCOVERY_ERROR_ENUM getError()
        {
            return error;
        }
    }
    
    private class ReaderThread extends LooperThread
    {
        int bufferId;
        ARCommand dataRecv = new ARCommand (128 * 1024);//TODO define
        
        public ReaderThread (int bufferId)
        {
            this.bufferId = bufferId;
            dataRecv = new ARCommand (128 * 1024);//TODO define
        }
        
        @Override
        public void onStart ()
        {
            
        }
        
        @Override
        public void onloop()
        {
            boolean skip = false;
            ARNETWORK_ERROR_ENUM netError = ARNETWORK_ERROR_ENUM.ARNETWORK_OK;
            
            /* read data*/
            netError =  netManager.readDataWithTimeout (bufferId, dataRecv, 1000); //TODO define
            
            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {   
                if(netError != ARNETWORK_ERROR_ENUM.ARNETWORK_ERROR_BUFFER_EMPTY)
                {
//                    ARSALPrint.e (TAG, "ReaderThread readDataWithTimeout() failed. " + netError + " bufferId: " + bufferId);
                }
                
                skip = true;
            }
            
            if (skip == false)
            {
                ARCOMMANDS_DECODER_ERROR_ENUM decodeStatus = dataRecv.decode();
                if ((decodeStatus != ARCOMMANDS_DECODER_ERROR_ENUM.ARCOMMANDS_DECODER_OK) && (decodeStatus != ARCOMMANDS_DECODER_ERROR_ENUM.ARCOMMANDS_DECODER_ERROR_NO_CALLBACK))
                {
                    ARSALPrint.e (TAG, "ARCommand.decode() failed. " + decodeStatus );
                }
            }
        }
        
        @Override
        public void onStop()
        {
            dataRecv.dispose();
            super.onStop();
        }
    }
    
    protected class ControllerLooperThread extends LooperThread
    {
        public ControllerLooperThread()
        {
            
        }
   
        @Override
        public void onloop()
        {
            long lastTime = SystemClock.elapsedRealtime();
            
            controllerLoop();
            
            long sleepTime = (SystemClock.elapsedRealtime() + loopInterval) - lastTime;
            
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
    
    private class VideoThread extends LooperThread
    {
        private ARStreamManager streamManager;
        
        public VideoThread ()
        {
            streamManager = new ARStreamManager (netManager, netConfig.getVideoDataIOBuffer(), netConfig.getVideoAckIOBuffer(), videoFragmentSize, videoMaxAckInterval);
        }
        
        @Override
        public void onStart()
        {
            super.onStart();
            
            streamManager.startStream();
            
        }
        
        @Override
        public void onloop()
        {
            ARFrame frame = streamManager.getFrameWithTimeout(VIDEO_RECEIVE_TIMEOUT);
            
            if (frame != null)
            {
                if (videoStreamListener != null)
                {
                    videoStreamListener.onReceiveFrame (frame);
                }
                streamManager.freeFrame(frame);
            }
        }
        
        @Override
        public void onStop()
        {
            streamManager.stopStream();
            
            super.onStop();
        }
    }
    
    private abstract class LooperThread extends Thread
    {
        private boolean isAlive;
        private boolean isRunning;
        
        public LooperThread ()
        {
            this.isRunning = false;
            this.isAlive = true;
        }
        
        @Override
        public void run()
        {
            this.isRunning = true;
            
            onStart ();
            
            while (this.isAlive)
            {
                onloop();
            }
            onStop();
            
            this.isRunning = false;
        }
        
        public void onStart ()
        {
            
        }
        
        public abstract void onloop ();
        
        public void onStop ()
        {
            
        }
        
        public void stopThread()
        {
            isAlive = false;
        }
        
        public boolean isRunning()
        {
            return this.isRunning;
        }
    }
    
    /**
     * data send to the ARNetworkManager callback
     */
    private class ARNetworkSendInfo
    {
        private ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM timeoutPolicy;
        private NetworkNotificationListener notificationListener;
        private NetworkNotificationData notificationData;
        private DeviceController deviceController;
        
        public ARNetworkSendInfo (ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM timeoutPolicy, NetworkNotificationListener notificationListener, NetworkNotificationData notificationData, DeviceController deviceController)
        {
            this.timeoutPolicy = timeoutPolicy;
            this.notificationListener = notificationListener;
            this.notificationData = notificationData;
            this.deviceController = deviceController;
        }
        
        public ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM getTimeoutPolicy ()
        {
            return this.timeoutPolicy;
        }
        
        public NetworkNotificationListener getNotificationListener ()
        {
            return this.notificationListener;
        }
        
        public NetworkNotificationData getNotificationData ()
        {
            return this.notificationData;
        }
        
        public DeviceController getDeviceController ()
        {
            return this.deviceController;
        }
        
        public void setTimeoutPolicy (ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM timeoutPolicy)
        {
            this.timeoutPolicy = timeoutPolicy; 
        }
        
        public void setNotificationListener (NetworkNotificationListener notificationListener)
        {
            this.notificationListener = notificationListener; 
        }
        
        public void setUserData (NetworkNotificationData notificationData)
        {
            this.notificationData = notificationData; 
        }
        
        public void setDeviceController (DeviceController deviceController)
        {
            this.deviceController = deviceController; 
        }
        
    }

    boolean startCancelled;
    abstract void initDeviceState();
    boolean fastReconnection;

    boolean doStart()
    {
        boolean failed = false;

        /* Initialize initial commands state. */
        initDeviceState();

        if ((!failed) && (!startCancelled))
        {
            failed = (startBaseController() != BASE_DEVICE_CONTROLLER_START_RETVAL_ENUM.BASE_DEVICE_CONTROLLER_START_RETVAL_OK);

            if (failed)
            {
                ARSALPrint.e(TAG, "Failed to start the base controller.");
            }
        }

        if ((!failed) && (!startCancelled))
        {
            Date currentDate = new Date();
            sendInitialDate(currentDate);
            sendInitialTime(currentDate);
        }

        if ((!failed) && (!startCancelled) && (!fastReconnection))
        {
            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerAllSettingsDidStartNotification));
            if (!getInitialSettings())
            {
                ARSALPrint.e(TAG, "Failed to get the initial settings.");
                failed = true;
            }
        }

        if ((!failed) && (!startCancelled))
        {
            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerAllStatesDidStartNotification));
            if (!getInitialStates())
            {
                ARSALPrint.e(TAG, "Failed to get the initial states.");
                failed = true;
            }
        }

        if ((!failed) && (!startCancelled))
        {
            this.registerCurrentProduct();
        }
        
        return (failed == false) && (startCancelled == false);
    }

    void doStop()
    {
        stopBaseController();
    }

    DEVICE_CONTROLER_STATE_ENUM state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED;
    Lock stateLock;

    /**
     * Must be called from start() method.
     */
    public final void startThread()
    {
        stateLock.lock();
        
        if (state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED)
        {
            state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STARTING;

            startCancelled = false;

            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerWillStartNotification));

            /* Asynchronously start the base controller. */
            new Thread(new Runnable()
            {
                public void run()
                {
                    boolean failed = false;
                    if (doStart() == false)
                    {
                        ARSALPrint.e(TAG, "Failed to start the controller.");
                        failed = true;
                    }

                    if ((!failed) && (!startCancelled))
                    {
                        /* Go to the STARTED state and notify. */
                        stateLock.lock();
                        
                        state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STARTED;
                        /*
                         * broadcast the new state of the connection ;
                         * DidStartNotification
                         */
                        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerDidStartNotification));
                        stateLock.unlock();
                        
                        if(router != null)
                        {
                            router.onConnectionToDeviceCompleted();
                        }
                    }
                    else
                    {
                        Log.i(TAG, "failed or start canceld");
                        /*
                         * We failed to start. Go to the STOPPING state and stop
                         * in the background.
                         */
                        stateLock.lock();
                        
                        state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPING;
                        if (failed)
                        {
                            /*
                             * broadcast the new state of the connection ;
                             * DidFailNotification
                             */
                            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerDidFailNotification));
                        }

                        stateLock.unlock();

                        doStop();

                        /* Go to the STOPPED state and notify. */
                        stateLock.lock();
                        state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED;
                        
                        /*
                         * broadcast the new state of the connection ;
                         * DidStopNotification
                         */
                        LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerDidStopNotification));
                        stateLock.unlock();
                    }

                }
            }).start();
        }
        
        stateLock.unlock();
    }

    /**
     * Must be called from stop() method.
     */
    public final void stopThread()
    {
        stateLock.lock();
        if (state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STARTED)
        {
            /* Go to the stopping state. */
            state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPING;

            /* Do the actual stop process in the background. */
            new Thread(new Runnable()
            {
                public void run()
                {
                    LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerWillStopNotification));

                    /* Perform the actual stop. */
                    doStop();
                    /* Go to the STOPPED state and notify. */
                    stateLock.lock();
                    state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPED;
                    
                    /*
                     * broadcast the new state of the connection ;
                     * DidStopNotification
                     */
                    LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerDidStopNotification));
                    stateLock.unlock();
                }
            }).start();
        }
        else if ((state == DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STARTING) && (startCancelled == false))
        {
            /* Go to the stopping state and request cancellation. */
            state = DEVICE_CONTROLER_STATE_ENUM.DEVICE_CONTROLLER_STATE_STOPPING;
            
            startCancelled = true;

            /* Do the actual stop process in the background. */
            new Thread(new Runnable()
            {
                public void run()
                {
                    LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(getDeviceControllerIntent(DeviceControllerWillStopNotification));

                    cancelBaseControllerStart();
                }
            }).start();

        }
        stateLock.unlock();
    }
    
    protected ARDiscoveryDeviceService getDeviceService()
    {
        return deviceService;
    }
    
    protected boolean isInitialized()
    {
        return initialized;
    }
}
