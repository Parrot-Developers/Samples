package com.parrot.bebopdronepilotingnewapi;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.media.MediaCodec;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.parrot.arsdk.arcontroller.ARControllerArgumentDictionary;
import com.parrot.arsdk.arcontroller.ARControllerDictionary;
import com.parrot.arsdk.arcontroller.ARCONTROLLER_DEVICE_STATE_ENUM;
import com.parrot.arsdk.arcontroller.ARCONTROLLER_DICTIONARY_KEY_ENUM;
import com.parrot.arsdk.arcontroller.ARCONTROLLER_ERROR_ENUM;
import com.parrot.arsdk.arcontroller.ARControllerException;
import com.parrot.arsdk.arcontroller.ARDeviceController;
import com.parrot.arsdk.arcontroller.ARDeviceControllerListener;
import com.parrot.arsdk.arcontroller.ARDeviceControllerStreamListener;
import com.parrot.arsdk.arcontroller.ARFrame;
import com.parrot.arsdk.ardiscovery.ARDISCOVERY_PRODUCT_ENUM;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDevice;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceNetService;
import com.parrot.arsdk.ardiscovery.ARDiscoveryException;
import com.parrot.bebopdronepiloting.R;

import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class PilotingActivity extends Activity implements ARDeviceControllerListener, ARDeviceControllerStreamListener, SurfaceHolder.Callback
{
    private static String TAG = PilotingActivity.class.getSimpleName();
    public static String EXTRA_DEVICE_SERVICE = "pilotingActivity.extra.device.service";

    public ARDeviceController deviceController;
    public ARDiscoveryDeviceService service;
    public ARDiscoveryDevice device;

    private Button emergencyBt;
    private Button takeoffBt;
    private Button landingBt;

    private Button gazUpBt;
    private Button gazDownBt;
    private Button yawLeftBt;
    private Button yawRightBt;

    private Button forwardBt;
    private Button backBt;
    private Button rollLeftBt;
    private Button rollRightBt;

    private TextView batteryLabel;

    private AlertDialog alertDialog;

    private RelativeLayout view;

    // video vars
    private static final String VIDEO_MIME_TYPE = "video/avc";
    private static final int VIDEO_DEQUEUE_TIMEOUT = 33000;
    private static final int VIDEO_WIDTH = 640;
    private static final int VIDEO_HEIGHT = 368;
    private SurfaceView sfView;
    private MediaCodec mediaCodec;
    private Lock readyLock;
    private boolean isCodecConfigured = false;
    private ByteBuffer csdBuffer;
    private boolean waitForIFrame = true;
    private ByteBuffer [] buffers;

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_piloting);

        initIHM ();
        initVideoVars();

        Intent intent = getIntent();
        service = intent.getParcelableExtra(EXTRA_DEVICE_SERVICE);

        //create the device
        try
        {
            device = new ARDiscoveryDevice();

            ARDiscoveryDeviceNetService netDeviceService = (ARDiscoveryDeviceNetService) service.getDevice();

            device.initWifi(ARDISCOVERY_PRODUCT_ENUM.ARDISCOVERY_PRODUCT_ARDRONE, netDeviceService.getName(), netDeviceService.getIp(), netDeviceService.getPort());
        }
        catch (ARDiscoveryException e)
        {
            e.printStackTrace();
            Log.e(TAG, "Error: " + e.getError());
        }


        if (device != null)
        {
            try
            {
                //create the deviceController
                deviceController = new ARDeviceController (device);
                deviceController.addListener (this);
                deviceController.addStreamListener(this);
            }
            catch (ARControllerException e)
            {
                e.printStackTrace();
            }
        }
    }

    private void initIHM ()
    {
        view = (RelativeLayout) findViewById(R.id.piloting_view);

        emergencyBt = (Button) findViewById(R.id.emergencyBt);
        emergencyBt.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v)
            {
                if ((deviceController != null) && (deviceController.getFeatureARDrone3() != null))
                {
                    ARCONTROLLER_ERROR_ENUM error = deviceController.getFeatureARDrone3().sendPilotingEmergency();
                }
            }
        });

        takeoffBt = (Button) findViewById(R.id.takeoffBt);
        takeoffBt.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v)
            {
                if ((deviceController != null) && (deviceController.getFeatureARDrone3() != null))
                {
                    //send takeOff
                    ARCONTROLLER_ERROR_ENUM error = deviceController.getFeatureARDrone3().sendPilotingTakeOff();
                }
            }
        });
        landingBt = (Button) findViewById(R.id.landingBt);
        landingBt.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v)
            {
                if ((deviceController != null) && (deviceController.getFeatureARDrone3() != null))
                {
                    //send landing
                    ARCONTROLLER_ERROR_ENUM error = deviceController.getFeatureARDrone3().sendPilotingLanding();
                }
            }
        });

        gazUpBt = (Button) findViewById(R.id.gazUpBt);
        gazUpBt.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDGaz((byte) 50);
                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDGaz((byte)0);

                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        gazDownBt = (Button) findViewById(R.id.gazDownBt);
        gazDownBt.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDGaz((byte)-50);

                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDGaz((byte)0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });
        yawLeftBt = (Button) findViewById(R.id.yawLeftBt);
        yawLeftBt.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDYaw((byte)-50);

                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDYaw((byte) 0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });
        yawRightBt = (Button) findViewById(R.id.yawRightBt);
        yawRightBt.setOnTouchListener(new View.OnTouchListener()
        {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDYaw((byte) 50);

                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDYaw((byte) 0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        forwardBt = (Button) findViewById(R.id.forwardBt);
        forwardBt.setOnTouchListener(new View.OnTouchListener()
        {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDPitch((byte) 50);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte) 1);
                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDPitch((byte) 0);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte) 0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });
        backBt = (Button) findViewById(R.id.backBt);
        backBt.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDPitch((byte)-50);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte)1);
                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDPitch((byte)0);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte)0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });
        rollLeftBt = (Button) findViewById(R.id.rollLeftBt);
        rollLeftBt.setOnTouchListener(new View.OnTouchListener()
        {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDRoll((byte) -50);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte) 1);
                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDRoll((byte) 0);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte) 0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });
        rollRightBt = (Button) findViewById(R.id.rollRightBt);
        rollRightBt.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event)
            {
                switch (event.getAction())
                {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDRoll((byte)50);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte)1);
                        }
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        if (deviceController != null)
                        {
                            deviceController.getFeatureARDrone3().setPilotingPCMDRoll((byte)0);
                            deviceController.getFeatureARDrone3().setPilotingPCMDFlag((byte)0);
                        }
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        batteryLabel = (TextView) findViewById(R.id.batteryLabel);
    }

    @Override
    public void onStart()
    {
        super.onStart();

        //start the deviceController
        if (deviceController != null)
        {
            final AlertDialog.Builder alertDialogBuilder = new AlertDialog.Builder(PilotingActivity.this);

            // set title
            alertDialogBuilder.setTitle("Connecting ...");


            // create alert dialog
            alertDialog = alertDialogBuilder.create();
            alertDialog.show();

            ARCONTROLLER_ERROR_ENUM error = deviceController.start();

            if (error != ARCONTROLLER_ERROR_ENUM.ARCONTROLLER_OK)
            {
                finish();
            }
        }
    }

    private void stopDeviceController()
    {
        if (deviceController != null)
        {
            final AlertDialog.Builder alertDialogBuilder = new AlertDialog.Builder(PilotingActivity.this);

            // set title
            alertDialogBuilder.setTitle("Disconnecting ...");

            // show it
            runOnUiThread(new Runnable()
            {
                @Override
                public void run()
                {
                    // create alert dialog
                    alertDialog = alertDialogBuilder.create();
                    alertDialog.show();

                    ARCONTROLLER_ERROR_ENUM error = deviceController.stop();

                    if (error != ARCONTROLLER_ERROR_ENUM.ARCONTROLLER_OK)
                    {
                        finish();
                    }
                }
            });
            //alertDialog.show();

        }
    }

    @Override
    protected void onStop()
    {
        if (deviceController != null)
        {
            deviceController.stop();
        }

        super.onStop();
    }

    @Override
    public void onBackPressed()
    {
        stopDeviceController();
    }

    public void onUpdateBattery(final int percent)
    {
        runOnUiThread(new Runnable() {
            @Override
            public void run()
            {
                batteryLabel.setText(String.format("%d%%", percent));
            }
        });

    }

    @Override
    public void onStateChanged (ARDeviceController deviceController, ARCONTROLLER_DEVICE_STATE_ENUM newState, ARCONTROLLER_ERROR_ENUM error)
    {
        Log.i(TAG, "onStateChanged ... newState:" + newState+" error: "+ error );

        switch (newState)
        {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
                //The deviceController is started
                Log.i(TAG, "ARCONTROLLER_DEVICE_STATE_RUNNING ....." );
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        //alertDialog.hide();
                        alertDialog.dismiss();
                    }
                });
                deviceController.getFeatureARDrone3().sendMediaStreamingVideoEnable((byte)1);
                break;

            case ARCONTROLLER_DEVICE_STATE_STOPPED:
                //The deviceController is stoped
                Log.i(TAG, "ARCONTROLLER_DEVICE_STATE_STOPPED ....." );

                deviceController.dispose();
                deviceController = null;

                runOnUiThread(new Runnable() {
                    @Override
                    public void run()
                    {
                        //alertDialog.hide();
                        alertDialog.dismiss();
                        finish();
                    }
                });
                break;

            default:
                break;
        }
    }

    @Override
    public void onCommandReceived(ARDeviceController deviceController, ARCONTROLLER_DICTIONARY_KEY_ENUM commandKey, ARControllerDictionary elementDictionary)
    {
        if (elementDictionary != null)
        {
            if (commandKey == ARCONTROLLER_DICTIONARY_KEY_ENUM.ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED)
            {
                ARControllerArgumentDictionary<Object> args = elementDictionary.get(ARControllerDictionary.ARCONTROLLER_DICTIONARY_SINGLE_KEY);

                if (args != null)
                {
                    Integer batValue = (Integer) args.get("arcontroller_dictionary_key_common_commonstate_batterystatechanged_percent");

                    onUpdateBattery(batValue);
                }
            }
        }
        else
        {
            Log.e(TAG, "elementDictionary is null");
        }
    }

    @Override
    public void onFrameReceived(ARDeviceController deviceController, ARFrame frame)
    {
        readyLock.lock();

        if ((mediaCodec != null))
        {
            if (!isCodecConfigured && frame.isIFrame())
            {
                csdBuffer = getCSD(frame);
                if (csdBuffer != null)
                {
                    configureMediaCodec();
                }
            }
            if (isCodecConfigured && (!waitForIFrame || frame.isIFrame()))
            {
                waitForIFrame = false;

                // Here we have either a good PFrame, or an IFrame
                int index = -1;

                try
                {
                    index = mediaCodec.dequeueInputBuffer(VIDEO_DEQUEUE_TIMEOUT);
                }
                catch (IllegalStateException e)
                {
                    Log.e(TAG, "Error while dequeue input buffer");
                }
                if (index >= 0)
                {
                    ByteBuffer b = buffers[index];
                    b.clear();
                    b.put(frame.getByteData(), 0, frame.getDataSize());
                    //ByteBufferDumper.dumpBufferStartEnd("PFRAME", b, 10, 4);
                    int flag = 0;
                    if (frame.isIFrame())
                    {
                        //flag = MediaCodec.BUFFER_FLAG_SYNC_FRAME | MediaCodec.BUFFER_FLAG_CODEC_CONFIG;
                    }

                    try
                    {
                        mediaCodec.queueInputBuffer(index, 0, frame.getDataSize(), 0, flag);
                    }
                    catch (IllegalStateException e)
                    {
                        Log.e(TAG, "Error while queue input buffer");
                    }

                }
                else
                {
                    waitForIFrame = true;
                }
            }

            // Try to display previous frame
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            int outIndex = -1;
            try
            {
                outIndex = mediaCodec.dequeueOutputBuffer(info, 0);

                while (outIndex >= 0)
                {
                    mediaCodec.releaseOutputBuffer(outIndex, true);
                    outIndex = mediaCodec.dequeueOutputBuffer(info, 0);
                }
            }
            catch (IllegalStateException e)
            {
                Log.e(TAG, "Error while dequeue input buffer (outIndex)");
            }
        }


        readyLock.unlock();
    }

    @Override
    public void onFrameTimeout(ARDeviceController deviceController)
    {
        //Log.i(TAG, "onFrameTimeout ..... " );
    }

    //region video
    public void initVideoVars()
    {
        readyLock = new ReentrantLock();
        applySetupVideo();
    }


    private void applySetupVideo()
    {
        String deviceModel = Build.DEVICE;
        Log.d(TAG, "configuring HW video codec for device: [" + deviceModel + "]");
        sfView = new SurfaceView(getApplicationContext());
        sfView.setLayoutParams(new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT));
        sfView.getHolder().addCallback(this);

        view.addView(sfView, 0);
    }

    @SuppressLint("NewApi")
    public void reset()
    {
        /* This will be run either before or after decoding a frame. */
        readyLock.lock();

        view.removeView(sfView);
        sfView = null;

        releaseMediaCodec();

        readyLock.unlock();
    }

    /**
     * Configure and start media codec
     * @param type
     */
    @SuppressLint("NewApi")
    private void initMediaCodec(String type)
    {
        try
        {
            mediaCodec = MediaCodec.createDecoderByType(type);
        }
        catch (IOException e)
        {
            e.printStackTrace();
        }

        if (csdBuffer != null)
        {
            configureMediaCodec();
        }
    }

    @SuppressLint("NewApi")
    private void configureMediaCodec()
    {
        MediaFormat format = MediaFormat.createVideoFormat("video/avc", VIDEO_WIDTH, VIDEO_HEIGHT);
        format.setByteBuffer("csd-0", csdBuffer);

        mediaCodec.configure(format, sfView.getHolder().getSurface(), null, 0);
        mediaCodec.start();

        buffers = mediaCodec.getInputBuffers();

        isCodecConfigured = true;
    }

    @SuppressLint("NewApi")
    private void releaseMediaCodec()
    {
        if ((mediaCodec != null) && (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN))
        {
            if (isCodecConfigured)
            {
                mediaCodec.stop();
                mediaCodec.release();
            }
            isCodecConfigured = false;
            mediaCodec = null;
        }
    }

    public ByteBuffer getCSD(ARFrame frame)
    {
        int spsSize = -1;
        if (frame.isIFrame())
        {
            byte[] data = frame.getByteData();
            int searchIndex = 0;
            // we'll need to search the "00 00 00 01" pattern to find each header size
            // Search start at index 4 to avoid finding the SPS "00 00 00 01" tag
            for (searchIndex = 4; searchIndex <= frame.getDataSize() - 4; searchIndex ++)
            {
                if (0 == data[searchIndex  ] &&
                        0 == data[searchIndex+1] &&
                        0 == data[searchIndex+2] &&
                        1 == data[searchIndex+3])
                {
                    break;  // PPS header found
                }
            }
            spsSize = searchIndex;

            // Search start at index 4 to avoid finding the PSS "00 00 00 01" tag
            for (searchIndex = spsSize+4; searchIndex <= frame.getDataSize() - 4; searchIndex ++)
            {
                if (0 == data[searchIndex  ] &&
                        0 == data[searchIndex+1] &&
                        0 == data[searchIndex+2] &&
                        1 == data[searchIndex+3])
                {
                    break;  // frame header found
                }
            }
            int csdSize = searchIndex;

            byte[] csdInfo = new byte[csdSize];
            System.arraycopy(data, 0, csdInfo, 0, csdSize);
            return ByteBuffer.wrap(csdInfo);
        }
        return null;
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder)
    {
        readyLock.lock();
        initMediaCodec(VIDEO_MIME_TYPE);
        readyLock.unlock();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height)
    {
    }


    @SuppressLint("NewApi")
    @Override
    public void surfaceDestroyed(SurfaceHolder holder)
    {
        readyLock.lock();
        releaseMediaCodec();
        readyLock.unlock();
    }

    //endregion video
}
