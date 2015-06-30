package com.parrot.bebopdronestreaming.video;

import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

import android.util.Log;
import android.graphics.Bitmap;

import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.arsdk.arstream.ARSTREAM_READER_CAUSE_ENUM;
import com.parrot.arsdk.arstream.ARStreamReader;
import com.parrot.arsdk.arnetwork.ARNetworkManager;
import com.parrot.arsdk.arstream.ARStreamReaderListener;

import org.bytedeco.javacv.AndroidFrameConverter;


/**
 * Created by root on 5/27/15.
 */
public class ARStreamManager {

    public ARStreamReader streamReader;
    public Thread videoRxThread;
    public Thread videoTxThread;
    public ARNativeData data;
    public ARStreamReaderListener listener;
    private android.content.Context context;
    private FaceDetection faceDetect;
    public static BlockingQueue<ARFrame> frameQueue;

    public static int success = 0;

    private static String TAG = "ARStreamManager";

    public ARStreamManager ()
    {

    }

    public ARStreamManager (android.content.Context context,
                            ARNetworkManager netManager,
                            int iobufferD2cArstreamData,
                            int iobufferC2dArstreamAck,
                            int videoFragmentSize,
                            int videoMaxAckInterval)
    {
        frameQueue = new LinkedBlockingQueue<ARFrame>();
        this.context = context;
        this.data = new ARNativeData(42000);
        this.listener = new ARStreamReaderCallBack(frameQueue);
        this.streamReader = new ARStreamReader(netManager, iobufferD2cArstreamData,
                iobufferC2dArstreamAck, data, listener, videoFragmentSize, videoMaxAckInterval);
        this.faceDetect = new FaceDetection(context);
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
        if (frameQueue.size() == 0) {
            try {
                Thread.sleep(video_receive_timeout);
            } catch (InterruptedException e) {
                Log.e(TAG, "InterruptedException");
            }
            return null;
        }

        Bitmap bitmap = null;
        ARFrame f = frameQueue.poll();

        // Decoded frame
        f.frame = f.decodeFromVideo();

        if (f.frame != null)
        {
            // Detect faces
            f.faces = faceDetect.detect(f.frame);
            AndroidFrameConverter converterToBitmap = new AndroidFrameConverter();
            f.bitmap = converterToBitmap.convert(f.frame);

        } else {
            Log.i(TAG, f.frameNo + ": failed");
            return null;
        }
        return f;
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
    public static BlockingQueue<ARFrame> frameQueue;
    public static int count = 1;

    public ARStreamReaderCallBack () { }

    public ARStreamReaderCallBack (BlockingQueue<ARFrame> frameQueue) {
        this.frameQueue = frameQueue;
    }

    /*** This method will be called by the system ***/
    @Override
    public ARNativeData didUpdateFrameStatus(ARSTREAM_READER_CAUSE_ENUM cause,
                                             ARNativeData currentFrame,
                                             boolean isFlushFrame,
                                             int nbSkippedFrames,
                                             int newBufferCapacity) {
        //Log.i(TAG, "didUpdateFrameStatus");
        //Log.i(TAG, "ARSTREAM_READER_CAUSE_ENUM: " + cause);
        //Log.i(TAG, "ARNativeData: " + currentFrame);
        //Log.i(TAG, "isFlushFrame: " + isFlushFrame);
        //Log.i(TAG, "nbSkippedFrames: " + nbSkippedFrames);
        //Log.i(TAG, "newBufferCapacity: " + newBufferCapacity);
        //Log.i(TAG, "frames received: " + count);
        switch (cause)
        {
            case ARSTREAM_READER_CAUSE_FRAME_COMPLETE:
                ARFrame freeFrame = new ARFrame(currentFrame.getByteData(), currentFrame.getDataSize(), isFlushFrame, count++);

                /*** I-Frame ***/
                if (isFlushFrame) {
                    frameQueue.clear();
                }

                frameQueue.offer(freeFrame);

                return currentFrame;

            case ARSTREAM_READER_CAUSE_FRAME_TOO_SMALL:
                /* This case should not happen, as we've allocated a frame pointer to the maximum possible size. */
                ARNativeData enlargedFrame = new ARNativeData(newBufferCapacity);
                return enlargedFrame;

            case ARSTREAM_READER_CAUSE_COPY_COMPLETE:
                /* Same as before ... but return value are ignored, so we just do nothing */
                return null;

            case ARSTREAM_READER_CAUSE_CANCEL:
                /* Same as before ... but return value are ignored, so we just do nothing */
                return null;

            default:
                return null;
        }
    }
}