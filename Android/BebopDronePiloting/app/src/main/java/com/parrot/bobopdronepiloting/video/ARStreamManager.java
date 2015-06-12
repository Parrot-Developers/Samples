package com.parrot.bobopdronepiloting.video;

import android.util.Log;

import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.arsdk.arstream.ARSTREAM_READER_CAUSE_ENUM;
import com.parrot.arsdk.arstream.ARStreamReader;
import com.parrot.arsdk.arnetwork.ARNetworkManager;
import com.parrot.arsdk.arstream.ARStreamReaderListener;


/**
 * Created by root on 5/27/15.
 */
public class ARStreamManager {

    public ARStreamReader streamReader;
    //public Runnable ackRunnable;
    //public Runnable dataRunnable;
    public Thread videoRxThread;
    public Thread videoTxThread;
    public ARNativeData data;
    public ARStreamReaderListener listener;

    private static String TAG = "ARStreamManager";

    public ARStreamManager ()
    {

    }

    public ARStreamManager (ARNetworkManager netManager,
                            int iobufferD2cArstreamData,
                            int iobufferC2dArstreamAck,
                            int videoFragmentSize,
                            int videoMaxAckInterval)
    {
        //TODO
        data = new ARNativeData(40000);
        listener = new ARStreamReaderCallBack();
        streamReader = new ARStreamReader(netManager, iobufferD2cArstreamData,
                iobufferC2dArstreamAck, data, listener, videoFragmentSize, videoMaxAckInterval);
    }

    public void startStream()
    {
        /* Create and start videoTx and videoRx threads */
        videoRxThread = new Thread (streamReader.getDataRunnable());
        videoRxThread.start();
        videoTxThread = new Thread (streamReader.getAckRunnable());
        videoTxThread.start();
    }

    public ARFrame getFrameWithTimeout(int video_receive_timeout)
    {
        ARFrame frame = null;
        //TODO
        // assuming that data will come into ARNativeData data, print out and observe
        Log.i(TAG, "getFrameWithTimeout video");
        //listener.didUpdateFrameStatus();
        return frame;
    }

    public void freeFrame(ARFrame frame)
    {
        //TODO
    }

    public void stopStream()
    {
        streamReader.stop();
    }
}

class ARStreamReaderCallBack implements ARStreamReaderListener
{
    private static String TAG = "ARStreamReaderCallBack";

    /*** This method will be called by the system ***/
    @Override
    public ARNativeData didUpdateFrameStatus(ARSTREAM_READER_CAUSE_ENUM cause,
                                             ARNativeData currentFrame,
                                             boolean isFlushFrame,
                                             int nbSkippedFrames,
                                             int newBufferCapacity) {
        Log.i(TAG, "didUpdateFrameStatus");
        Log.i(TAG, "ARSTREAM_READER_CAUSE_ENUM: " + cause);
        Log.i(TAG, "ARNativeData: " + currentFrame);
        Log.i(TAG, "isFlushFrame: " + isFlushFrame);
        Log.i(TAG, "nbSkippedFrames: " + nbSkippedFrames);
        Log.i(TAG, "newBufferCapacity: " + newBufferCapacity);

        switch (cause)
        {
            case ARSTREAM_READER_CAUSE_FRAME_COMPLETE:
                ARFrame freeFrame = new ARFrame(currentFrame, isFlushFrame);
                // send freeFrame to be decoded
                break;
            case ARSTREAM_READER_CAUSE_FRAME_TOO_SMALL:
                /* This case should not happen, as we've allocated a frame pointer to the maximum possible size. */
                break;
            case ARSTREAM_READER_CAUSE_COPY_COMPLETE:
                /* Same as before ... but return value are ignored, so we just do nothing */
                break;
            case ARSTREAM_READER_CAUSE_CANCEL:
                /* Same as before ... but return value are ignored, so we just do nothing */
                break;
            default:
                break;
        }


        return currentFrame;
    }
}