package com.parrot.sdksample.audio;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.media.audiofx.NoiseSuppressor;
import android.util.Log;

import com.parrot.arsdk.arcontroller.ARAudioFrame;
import com.parrot.arsdk.arsal.ARNativeData;


public class AudioRecorder
{
    private static final String TAG = AudioRecorder.class.getSimpleName();

    public interface Listener {

        public void sendFrame(ARNativeData data);
    }

    private static final int AUDIO_RECORDER_SAMPLERATE = 8000;
    private static final int AUDIO_RECORDER_CHANNELS = AudioFormat.CHANNEL_IN_MONO;
    private static final int AUDIO_RECORDER_AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT;

    private final AudioRecord mRecorder;
    private boolean mIsRecording = false;
    private boolean mReleased = false;

    Listener sender;

    public AudioRecorder(Listener listener)
    {
        int bufferSize = AudioRecord.getMinBufferSize(AUDIO_RECORDER_SAMPLERATE, AUDIO_RECORDER_CHANNELS, AUDIO_RECORDER_AUDIO_ENCODING);

        mRecorder = new AudioRecord(MediaRecorder.AudioSource.MIC,
                AUDIO_RECORDER_SAMPLERATE, AUDIO_RECORDER_CHANNELS,
                AUDIO_RECORDER_AUDIO_ENCODING, bufferSize);

        if (mRecorder.getState() == AudioRecord.STATE_UNINITIALIZED)
        {
            Log.e(TAG, "Failed to init micro");
            return;
        }

        sender = listener;

        mRecorder.startRecording();
        mIsRecording = false;
        Thread mRecordingThread = new Thread(new Runnable()
        {
            public void run()
            {
                byte[] buffer = new byte[ARAudioFrame.DATA_SIZE];
                ARNativeData nativeData = new ARNativeData(ARAudioFrame.DATA_SIZE);
                int readSize = 0;
                NoiseSuppressor noiseSuppressor = null;
                if(android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN)
                {
                    noiseSuppressor = NoiseSuppressor.create(mRecorder.getAudioSessionId());
                    Log.d(TAG, "NoiseSuppressor.isAvailable() " + NoiseSuppressor.isAvailable());
                }

                while (!mReleased)
                {
                    if(mIsRecording)
                    {
                        // gets the voice output from microphone to byte format
                        readSize = mRecorder.read(buffer, 0, ARAudioFrame.DATA_SIZE);

                        nativeData.copyByteData(buffer, readSize);

                        sender.sendFrame(nativeData);
                    }
                    else
                    {
                        synchronized (AudioRecorder.this)
                        {
                            try
                            {
                                AudioRecorder.this.wait();
                            }
                            catch (InterruptedException e)
                            {
                            }
                        }
                    }
                }

                nativeData.dispose();

                if(noiseSuppressor != null)
                {
                    noiseSuppressor.release();
                }
            }
        }, "AudioRecorder Thread");
        mRecordingThread.start();
    }

    //need synchronized to call notify
    synchronized public void start()
    {
        mIsRecording = true;
        notify();
    }

    public void stop()
    {
        mIsRecording = false;
    }

    synchronized public void release()
    {
        mIsRecording = false;
        mReleased = true;
        notify();
        mRecorder.release();
    }
}
