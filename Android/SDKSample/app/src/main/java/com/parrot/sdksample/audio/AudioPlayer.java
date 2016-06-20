package com.parrot.sdksample.audio;

import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.util.Log;

import com.parrot.arsdk.arcontroller.ARAudioFrame;
import com.parrot.arsdk.arsal.ARNativeData;

public class AudioPlayer
{
    @SuppressWarnings("unused")
    private static final String TAG = AudioPlayer.class.getSimpleName();

    private static final int AUDIO_SAMPLERATE = 8000;
    private static final int AUDIO_CHANNELS = AudioFormat.CHANNEL_OUT_MONO;
    private static final int AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private static final int AUDIO_BUFFER_SIZE = 4096;

    private AudioTrack mAudioTrack;

    private boolean mPlaying = false;


    public AudioPlayer()
    {
    }

    public synchronized void start()
    {
        if (!mPlaying)
        {
            mPlaying = true;
            if (mAudioTrack != null)
            {
                mAudioTrack.play();
            }
        }
    }

    public synchronized void stop()
    {
        if (mPlaying)
        {
            mPlaying = false;
            if (mAudioTrack != null)
            {
                mAudioTrack.pause();
                mAudioTrack.flush();
            }
        }
    }

    public synchronized void release()
    {
        mPlaying = false;
        if (mAudioTrack != null) mAudioTrack.release();
        mAudioTrack = null;
    }

    public void configureCodec(int sampleRate)
    {
        if (mAudioTrack != null) {
            mAudioTrack.flush();
            synchronized (AudioPlayer.this) {
                mAudioTrack.release();
                mAudioTrack = null;
            }
        }

        mAudioTrack = new AudioTrack(AudioManager.STREAM_MUSIC, sampleRate, AUDIO_CHANNELS, AUDIO_ENCODING, AUDIO_BUFFER_SIZE, AudioTrack.MODE_STREAM);
        synchronized (AudioPlayer.this) {
            if (mPlaying) {
                mAudioTrack.play();
            }
        }
    }

    public void onDataReceived(ARNativeData currentFrame)
    {
        if (mPlaying && mAudioTrack != null)
        {
            mAudioTrack.write(currentFrame.getByteData(), 0, currentFrame.getDataSize());
        }
    }

}
