package com.parrot.sdksample.activity;

import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.parrot.arsdk.arcommands.ARCOMMANDS_JUMPINGSUMO_MEDIARECORDEVENT_PICTUREEVENTCHANGED_ERROR_ENUM;
import com.parrot.arsdk.arcontroller.ARCONTROLLER_DEVICE_STATE_ENUM;
import com.parrot.arsdk.arcontroller.ARCONTROLLER_STREAM_CODEC_TYPE_ENUM;
import com.parrot.arsdk.arcontroller.ARControllerCodec;
import com.parrot.arsdk.arcontroller.ARFrame;
import com.parrot.arsdk.ardiscovery.ARDISCOVERY_PRODUCT_ENUM;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.sdksample.R;
import com.parrot.sdksample.audio.AudioPlayer;
import com.parrot.sdksample.audio.AudioRecorder;
import com.parrot.sdksample.drone.JSDrone;
import com.parrot.sdksample.view.JSVideoView;

public class JSActivity extends AppCompatActivity {
    private static final String TAG = "JSActivity";
    private JSDrone mJSDrone;

    private ProgressDialog mConnectionProgressDialog;
    private ProgressDialog mDownloadProgressDialog;

    private JSVideoView mVideoView;
    private AudioPlayer mAudioPlayer;
    private AudioRecorder mAudioRecorder;

    private TextView mBatteryLabel;

    private int mNbMaxDownload;
    private int mCurrentDownloadIndex;

    private Button mAudioBt;
    private enum AudioState {
        MUTE,
        INPUT,
        BIDIRECTIONAL,
    }
    private AudioState mAudioState = AudioState.MUTE;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_js);

        Intent intent = getIntent();
        ARDiscoveryDeviceService service = intent.getParcelableExtra(DeviceListActivity.EXTRA_DEVICE_SERVICE);

        mJSDrone = new JSDrone(this, service);
        mJSDrone.addListener(mJSListener);

        initIHM();

        mAudioPlayer = new AudioPlayer();
        mAudioRecorder = new AudioRecorder(mAudioListener);
    }

    @Override
    protected void onStart() {
        super.onStart();

        // show a loading view while the JumpingSumo drone is connecting
        if ((mJSDrone != null) && !(ARCONTROLLER_DEVICE_STATE_ENUM.ARCONTROLLER_DEVICE_STATE_RUNNING.equals(mJSDrone.getConnectionState())))
        {
            mConnectionProgressDialog = new ProgressDialog(this, R.style.AppCompatAlertDialogStyle);
            mConnectionProgressDialog.setIndeterminate(true);
            mConnectionProgressDialog.setMessage("Connecting ...");
            mConnectionProgressDialog.show();

            // if the connection to the Jumping fails, finish the activity
            if (!mJSDrone.connect()) {
                finish();
            }
        }
    }

    @Override
    public void onBackPressed() {
        if (mJSDrone != null)
        {
            mConnectionProgressDialog = new ProgressDialog(this, R.style.AppCompatAlertDialogStyle);
            mConnectionProgressDialog.setIndeterminate(true);
            mConnectionProgressDialog.setMessage("Disconnecting ...");
            mConnectionProgressDialog.show();

            if (!mJSDrone.disconnect()) {
                finish();
            }
        }
    }

    @Override
    public void onDestroy()
    {
        mAudioPlayer.stop();
        mAudioPlayer.release();

        mAudioRecorder.stop();
        mAudioRecorder.release();

        mJSDrone.dispose();
        super.onDestroy();
    }

    private void initIHM() {
        mVideoView = (JSVideoView) findViewById(R.id.videoView);

        mAudioBt = (Button) findViewById(R.id.audioBt);
        mAudioBt.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                /*change audio state*/
                switch(mAudioState){
                    case MUTE:
                        setAudioState(AudioState.INPUT);
                        break;

                    case INPUT:
                        if (mJSDrone.hasOutputAudioStream()) {
                            setAudioState(AudioState.BIDIRECTIONAL);
                        } else {
                            setAudioState(AudioState.MUTE);
                        }
                        break;

                    case BIDIRECTIONAL:
                        setAudioState(AudioState.MUTE);
                        break;
                }
            }
        });

        if ((!mJSDrone.hasInputAudioStream()) && (!mJSDrone.hasOutputAudioStream())) {
            findViewById(R.id.audioTxt).setVisibility(View.GONE);
            mAudioBt.setVisibility(View.GONE);
        }

        findViewById(R.id.takePictureBt).setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                mJSDrone.takePicture();
            }
        });

        findViewById(R.id.downloadBt).setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                mJSDrone.getLastFlightMedias();

                mDownloadProgressDialog = new ProgressDialog(JSActivity.this, R.style.AppCompatAlertDialogStyle);
                mDownloadProgressDialog.setIndeterminate(true);
                mDownloadProgressDialog.setMessage("Fetching medias");
                mDownloadProgressDialog.setCancelable(false);
                mDownloadProgressDialog.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        mJSDrone.cancelGetLastFlightMedias();
                    }
                });
                mDownloadProgressDialog.show();
            }
        });

        findViewById(R.id.forwardBt).setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        mJSDrone.setSpeed((byte) 100);
                        mJSDrone.setFlag((byte) 1);
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        mJSDrone.setSpeed((byte) 0);
                        mJSDrone.setFlag((byte) 0);
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        findViewById(R.id.backwardBt).setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        mJSDrone.setSpeed((byte) -100);
                        mJSDrone.setFlag((byte) 1);
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        mJSDrone.setSpeed((byte) 0);
                        mJSDrone.setFlag((byte) 0);
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        findViewById(R.id.leftBt).setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        mJSDrone.setTurn((byte) -50);
                        mJSDrone.setFlag((byte) 1);
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        mJSDrone.setTurn((byte) 0);
                        mJSDrone.setFlag((byte) 0);
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        findViewById(R.id.rightBt).setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        v.setPressed(true);
                        mJSDrone.setTurn((byte) 50);
                        mJSDrone.setFlag((byte) 1);
                        break;

                    case MotionEvent.ACTION_UP:
                        v.setPressed(false);
                        mJSDrone.setTurn((byte) 0);
                        mJSDrone.setFlag((byte) 0);
                        break;

                    default:

                        break;
                }

                return true;
            }
        });

        mBatteryLabel = (TextView) findViewById(R.id.batteryLabel);
    }

    private void setAudioState(AudioState audioState){

        mAudioState = audioState;

        switch(mAudioState){
            case MUTE:
                mAudioBt.setText("MUTE");
                mJSDrone.setAudioStreamEnabled(false, false);
                break;

            case INPUT:
                mAudioBt.setText("INPUT");
                mJSDrone.setAudioStreamEnabled(true, false);
                break;

            case BIDIRECTIONAL:
                mAudioBt.setText("IN/OUTPUT");
                mJSDrone.setAudioStreamEnabled(true, true);
                break;
        }
    }

    private final JSDrone.Listener mJSListener = new JSDrone.Listener() {
        @Override
        public void onDroneConnectionChanged(ARCONTROLLER_DEVICE_STATE_ENUM state) {
            switch (state)
            {
                case ARCONTROLLER_DEVICE_STATE_RUNNING:
                    mConnectionProgressDialog.dismiss();
                    break;

                case ARCONTROLLER_DEVICE_STATE_STOPPED:
                    // if the deviceController is stopped, go back to the previous activity
                    mConnectionProgressDialog.dismiss();
                    finish();
                    break;

                default:
                    break;
            }
        }

        @Override
        public void onBatteryChargeChanged(int batteryPercentage) {
            mBatteryLabel.setText(String.format("%d%%", batteryPercentage));
        }

        @Override
        public void onPictureTaken(ARCOMMANDS_JUMPINGSUMO_MEDIARECORDEVENT_PICTUREEVENTCHANGED_ERROR_ENUM error) {
            Log.i(TAG, "Picture has been taken");
        }

        @Override
        public void configureDecoder(ARControllerCodec codec) {
        }

        @Override
        public void onFrameReceived(ARFrame frame) {
            mVideoView.displayFrame(frame);
        }

        @Override
        public void onAudioStateReceived(boolean inputEnabled, boolean outputEnabled) {
            if (inputEnabled) {
                mAudioPlayer.start();
            } else {
                mAudioPlayer.stop();
            }

            if (outputEnabled) {
                mAudioRecorder.start();
            } else {
                mAudioRecorder.stop();
            }
        }

        @Override
        public void configureAudioDecoder(ARControllerCodec codec) {
            if (codec.getType() == ARCONTROLLER_STREAM_CODEC_TYPE_ENUM.ARCONTROLLER_STREAM_CODEC_TYPE_PCM16LE) {

                ARControllerCodec.PCM16LE codecPCM16le = codec.getAsPCM16LE();

                mAudioPlayer.configureCodec(codecPCM16le.getSampleRate());
            }
        }

        @Override
        public void onAudioFrameReceived(ARFrame frame) {
            mAudioPlayer.onDataReceived(frame);
        }

        @Override
        public void onMatchingMediasFound(int nbMedias) {
            mDownloadProgressDialog.dismiss();

            mNbMaxDownload = nbMedias;
            mCurrentDownloadIndex = 1;

            if (nbMedias > 0) {
                mDownloadProgressDialog = new ProgressDialog(JSActivity.this, R.style.AppCompatAlertDialogStyle);
                mDownloadProgressDialog.setIndeterminate(false);
                mDownloadProgressDialog.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
                mDownloadProgressDialog.setMessage("Downloading medias");
                mDownloadProgressDialog.setMax(mNbMaxDownload * 100);
                mDownloadProgressDialog.setSecondaryProgress(mCurrentDownloadIndex * 100);
                mDownloadProgressDialog.setProgress(0);
                mDownloadProgressDialog.setCancelable(false);
                mDownloadProgressDialog.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        mJSDrone.cancelGetLastFlightMedias();
                    }
                });
                mDownloadProgressDialog.show();
            }
        }

        @Override
        public void onDownloadProgressed(String mediaName, int progress) {
            mDownloadProgressDialog.setProgress(((mCurrentDownloadIndex - 1) * 100) + progress);
        }

        @Override
        public void onDownloadComplete(String mediaName) {
            mCurrentDownloadIndex++;
            mDownloadProgressDialog.setSecondaryProgress(mCurrentDownloadIndex * 100);

            if (mCurrentDownloadIndex > mNbMaxDownload) {
                mDownloadProgressDialog.dismiss();
                mDownloadProgressDialog = null;
            }
        }
    };

    private final AudioRecorder.Listener mAudioListener = new AudioRecorder.Listener() {
        @Override
        public void sendFrame(ARNativeData data) {
            mJSDrone.sendStreamingFrame(data);
        }
    };
}
