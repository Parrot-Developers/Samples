package com.parrot.rollingspiderpiloting;


import android.os.SystemClock;
import android.util.Log;

import java.sql.Date;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

import com.parrot.arsdk.arcommands.ARCOMMANDS_COMMON_MAVLINK_START_TYPE_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_DECODER_ERROR_ENUM;
import com.parrot.arsdk.arcommands.ARCOMMANDS_GENERATOR_ERROR_ENUM;
import com.parrot.arsdk.arcommands.ARCommand;
import com.parrot.arsdk.arcommands.ARCommandCommonCommonStateBatteryStateChangedListener;
import com.parrot.arsdk.arcommands.ARCommandsVersion;
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
import com.parrot.arsdk.arnetworkal.ARNETWORKAL_FRAME_TYPE_ENUM;
import com.parrot.arsdk.arnetworkal.ARNetworkALManager;
import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.arsdk.arsal.ARSALPrint;

public class DeviceController implements ARCommandCommonCommonStateBatteryStateChangedListener
{
    private static String TAG = "DeviceController";

    private static int iobufferC2dNack = 10;
    private static int iobufferC2dAck = 11;
    private static int iobufferC2dEmergency = 12;
    private static int iobufferD2cNavdata = (ARNetworkALManager.ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 1;
    private static int iobufferD2cEvents = (ARNetworkALManager.ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 2;

    private static int ackOffset = (ARNetworkALManager.ARNETWORKAL_MANAGER_BLE_ID_MAX / 2);

    protected static List<ARNetworkIOBufferParam> c2dParams = new ArrayList<ARNetworkIOBufferParam>();
    protected static List<ARNetworkIOBufferParam> d2cParams = new ArrayList<ARNetworkIOBufferParam>();
    protected static int commandsBuffers[] = {};

    protected static int bleNotificationIDs[] = new int[]{iobufferD2cNavdata, iobufferD2cEvents, (iobufferC2dAck + ackOffset) ,(iobufferC2dEmergency + ackOffset) };

    private android.content.Context context;

    private ARNetworkALManager alManager;
    private ARNetworkManager netManager;
    private boolean mediaOpened;

    private int c2dPort;
    private int d2cPort;
    private Thread rxThread;
    private Thread txThread;

    private List<ReaderThread> readerThreads;
    private Semaphore discoverSemaphore;
    private ARDiscoveryConnection discoveryData;

    private LooperThread looperThread;

    private DataPCMD dataPCMD;
    private ARDiscoveryDeviceService deviceService;

    private DeviceControllerListener listener;


    static
    {
        c2dParams.clear();
        c2dParams.add (new ARNetworkIOBufferParam (iobufferC2dNack,
                                                   ARNETWORKAL_FRAME_TYPE_ENUM.ARNETWORKAL_FRAME_TYPE_DATA,
                                                   20,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
                                                   1,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
                                                   true));
        c2dParams.add (new ARNetworkIOBufferParam (iobufferC2dAck,
                                                   ARNETWORKAL_FRAME_TYPE_ENUM.ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
                                                   20,
                                                           500,
                                                           3,
                                                           20,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
                                                   false));
        c2dParams.add (new ARNetworkIOBufferParam (iobufferC2dEmergency,
                                                   ARNETWORKAL_FRAME_TYPE_ENUM.ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
                                                   1,
                                                           100,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
                                                   1,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
                                                   false));

        d2cParams.clear();
        d2cParams.add (new ARNetworkIOBufferParam (iobufferD2cNavdata,
                                                   ARNETWORKAL_FRAME_TYPE_ENUM.ARNETWORKAL_FRAME_TYPE_DATA,
                                                   20,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
                                                   20,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
                                                   false));
        d2cParams.add (new ARNetworkIOBufferParam (iobufferD2cEvents,
                                                   ARNETWORKAL_FRAME_TYPE_ENUM.ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
                                                   20,
                                                           500,
                                                           3,
                                                           20,
                                                   ARNetworkIOBufferParam.ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
                                                   false));

        commandsBuffers = new int[] {
                iobufferD2cNavdata,
                iobufferD2cEvents,
        };

    }

    public DeviceController (android.content.Context context, ARDiscoveryDeviceService service)
    {
        dataPCMD = new DataPCMD();
        deviceService = service;
        this.context = context;
        readerThreads = new ArrayList<ReaderThread>();
    }

    public boolean start()
    {
        Log.d(TAG, "start ...");

        boolean failed = false;

        registerARCommandsListener ();

         failed = startNetwork();

        if (!failed)
        {
            /* start the reader threads */
            startReadThreads();
        }

        if (!failed)
        {
                /* start the looper thread */
            startLooperThread();
        }

        return failed;
    }

    public void stop()
    {
        Log.d(TAG, "stop ...");

        unregisterARCommandsListener();

        /* Cancel the looper thread and block until it is stopped. */
        stopLooperThread();

        /* cancel all reader threads and block until they are all stopped. */
        stopReaderThreads();

        /* ARNetwork cleanup */
        stopNetwork();

    }

    private boolean startNetwork()
    {
        ARNETWORKAL_ERROR_ENUM netALError = ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_OK;
        boolean failed = false;
        int pingDelay = 0; /* 0 means default, -1 means no ping */

        /* Create the looper ARNetworkALManager */
        alManager = new ARNetworkALManager();


        /* setup ARNetworkAL for BLE */

        ARDiscoveryDeviceBLEService bleDevice = (ARDiscoveryDeviceBLEService) deviceService.getDevice();

        netALError = alManager.initBLENetwork(context, bleDevice.getBluetoothDevice(), 1, bleNotificationIDs);

        if (netALError == ARNETWORKAL_ERROR_ENUM.ARNETWORKAL_OK)
        {
            mediaOpened = true;
            pingDelay = -1; /* Disable ping for BLE networks */
        }
        else
        {
            ARSALPrint.e(TAG, "error occured: " + netALError.toString());
            failed = true;
        }

        if (failed == false)
        {
            /* Create the ARNetworkManager */
            netManager = new ARNetworkManagerExtend(alManager, c2dParams.toArray(new ARNetworkIOBufferParam[c2dParams.size()]), d2cParams.toArray(new ARNetworkIOBufferParam[d2cParams.size()]), pingDelay);

            if (netManager.isCorrectlyInitialized() == false)
            {
                ARSALPrint.e (TAG, "new ARNetworkManager failed");
                failed = true;
            }
        }

        if (failed == false)
        {
            /* Create and start Tx and Rx threads */
            rxThread = new Thread (netManager.m_receivingRunnable);
            rxThread.start();

            txThread = new Thread (netManager.m_sendingRunnable);
            txThread.start();
        }

        return failed;
    }

    private void startReadThreads()
    {
        /* Create the reader threads */
        for (int bufferId : commandsBuffers)
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

    private void startLooperThread()
    {
        /* Create the looper thread */
        looperThread = new ControllerLooperThread();

        /* Start the looper thread. */
        looperThread.start();
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

    private void stopNetwork()
    {
        if(netManager != null)
        {
            netManager.stop();

            try
            {
                if (txThread != null)
                {
                    txThread.join();
                }
                if (rxThread != null)
                {
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
                alManager.closeBLENetwork(context);
            }

            mediaOpened = false;
            alManager.dispose();
        }
    }



    protected void registerARCommandsListener ()
    {
        ARCommand.setCommonCommonStateBatteryStateChangedListener(this);
    }

    protected void unregisterARCommandsListener ()
    {
        ARCommand.setCommonCommonStateBatteryStateChangedListener(null);
    }


    private boolean sendPCMD()
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        cmdError = cmd.setMiniDronePilotingPCMD (dataPCMD.flag, dataPCMD.roll, dataPCMD.pitch, dataPCMD.yaw, dataPCMD.gaz, dataPCMD.psi);
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The commands sent in loop should be sent to a buffer not acknowledged ; here iobufferC2dNack
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dNack, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send PCMD command.");
        }

        return sentStatus;
    }

    public boolean sendTakeoff()
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        cmdError = cmd.setMiniDronePilotingTakeOff();
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The commands sent by event should be sent to an buffer acknowledged  ; here iobufferC2dAck
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dAck, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send TakeOff command.");
        }

        return sentStatus;
    }

    public boolean sendLanding()
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        cmdError = cmd.setMiniDronePilotingLanding();
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The commands sent by event should be sent to an buffer acknowledged  ; here iobufferC2dAck
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dAck, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send Landing command.");
        }

        return sentStatus;
    }

    public boolean sendEmergency()
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        cmdError = cmd.setMiniDronePilotingEmergency();
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The command emergency should be sent to its own buffer acknowledged  ; here iobufferC2dEmergency
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dEmergency, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send Emergency command.");
        }

        return sentStatus;
    }

    public boolean sendDate(Date currentDate)
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        SimpleDateFormat formattedDate = new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault());

        cmdError = cmd.setCommonCommonCurrentDate(formattedDate.format(currentDate));
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The command emergency should be sent to its own buffer acknowledged  ; here iobufferC2dAck
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dAck, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send date command.");
        }

        return sentStatus;
    }

    public boolean sendTime(Date currentDate)
    {
        ARCOMMANDS_GENERATOR_ERROR_ENUM cmdError = ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK;
        boolean sentStatus = true;
        ARCommand cmd = new ARCommand();

        SimpleDateFormat formattedTime = new SimpleDateFormat("'T'HHmmssZZZ", Locale.getDefault());

        cmdError = cmd.setCommonCommonCurrentTime(formattedTime.format(currentDate));
        if (cmdError == ARCOMMANDS_GENERATOR_ERROR_ENUM.ARCOMMANDS_GENERATOR_OK)
        {
            /* Send data with ARNetwork */
            // The command emergency should be sent to its own buffer acknowledged  ; here iobufferC2dAck
            ARNETWORK_ERROR_ENUM netError = netManager.sendData (iobufferC2dAck, cmd, null, true);

            if (netError != ARNETWORK_ERROR_ENUM.ARNETWORK_OK)
            {
                ARSALPrint.e(TAG, "netManager.sendData() failed. " + netError.toString());
                sentStatus = false;
            }

            cmd.dispose();
        }

        if (sentStatus == false)
        {
            ARSALPrint.e(TAG, "Failed to send time command.");
        }

        return sentStatus;
    }

    public void setFlag(byte flag)
    {
        dataPCMD.flag = flag;
    }

    public void setGaz(byte gaz)
    {
        dataPCMD.gaz = gaz;
    }

    public void setRoll (byte roll)
    {
        dataPCMD.roll = roll;
    }

    public void setPitch (byte pitch)
    {
        dataPCMD.pitch = pitch;
    }

    public void setYaw (byte yaw)
    {
        dataPCMD.yaw = yaw;
    }

    public void setListener(DeviceControllerListener listener)
    {
        this.listener = listener;
    }

    @Override
    public void onCommonCommonStateBatteryStateChangedUpdate(byte b)
    {
        Log.d(TAG, "onCommonCommonStateBatteryStateChangedUpdate ...");

        if (listener != null)
        {
            listener.onUpdateBattery(b);
        }
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

            if (status == ARNETWORK_MANAGER_CALLBACK_STATUS_ENUM.ARNETWORK_MANAGER_CALLBACK_STATUS_TIMEOUT)
            {
                retVal = ARNETWORK_MANAGER_CALLBACK_RETURN_ENUM.ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP;
            }

            return retVal;
        }

        @Override
        public void onDisconnect(ARNetworkALManager arNetworkALManager)
        {
            Log.d(TAG, "onDisconnect ...");

            if (listener != null)
            {
                listener.onDisconnect();
            }
        }
    }

    private class DataPCMD
    {
        public byte flag;
        public byte roll;
        public byte pitch;
        public byte yaw;
        public byte gaz;
        public float psi;

        public DataPCMD ()
        {
            flag = 0;
            roll = 0;
            pitch = 0;
            yaw = 0;
            gaz = 0;
            psi = 0.0f;
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
                if ((decodeStatus != ARCOMMANDS_DECODER_ERROR_ENUM.ARCOMMANDS_DECODER_OK) && (decodeStatus != ARCOMMANDS_DECODER_ERROR_ENUM.ARCOMMANDS_DECODER_ERROR_NO_CALLBACK) && (decodeStatus != ARCOMMANDS_DECODER_ERROR_ENUM.ARCOMMANDS_DECODER_ERROR_UNKNOWN_COMMAND))
                {
                    ARSALPrint.e(TAG, "ARCommand.decode() failed. " + decodeStatus);
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

            sendPCMD();

            long sleepTime = (SystemClock.elapsedRealtime() + 50) - lastTime;

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
}
