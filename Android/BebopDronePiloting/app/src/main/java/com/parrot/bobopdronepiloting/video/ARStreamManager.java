package com.parrot.bobopdronepiloting.video;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.Queue;
import java.io.File;

import android.os.Environment;
import android.util.Log;
import android.graphics.Bitmap;

import com.parrot.arsdk.arsal.ARNativeData;
import com.parrot.arsdk.arstream.ARSTREAM_READER_CAUSE_ENUM;
import com.parrot.arsdk.arstream.ARStreamReader;
import com.parrot.arsdk.arnetwork.ARNetworkManager;
import com.parrot.arsdk.arstream.ARStreamReaderListener;
import com.parrot.bobopdronepiloting.DeviceController;

import org.bytedeco.javacv.AndroidFrameConverter;
import org.bytedeco.javacv.Frame;


/**
 * Created by root on 5/27/15.
 */
public class ARStreamManager {

    public ARStreamReader streamReader;
    public Thread videoRxThread;
    public Thread videoTxThread;
    public ARNativeData data;
    public ARStreamReaderListener listener;
    public static BlockingQueue<ARFrame> frameQueue;


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
        frameQueue = new LinkedBlockingQueue<ARFrame>();
        data = new ARNativeData(40000);
        listener = new ARStreamReaderCallBack(frameQueue);
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

    public Bitmap getFrameWithTimeout(int video_receive_timeout)
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
        ARFrame freeFrame = frameQueue.poll();

        freeFrame.frame = freeFrame.decodeFromVideo();
        String paddedFrameNo = String.format("%05d", freeFrame.frameNo);

        if (freeFrame.frame != null)
        {
            Log.i(TAG, freeFrame.frameNo + ": success");
            // Save to image file to see omg

            AndroidFrameConverter converterToBitmap = new AndroidFrameConverter();
            bitmap = converterToBitmap.convert(freeFrame.frame);

            // Save to image file to see omg
            /*
            String file_path = Environment.getExternalStorageDirectory().getAbsolutePath() + "/BebopDronePiloting";
            File dir = new File(file_path);

            if (!dir.exists()) {
                dir.mkdirs();
            }

            try {
                File file = new File(dir, "image_" + paddedFrameNo + ".png");
                FileOutputStream fOut = new FileOutputStream(file);
                bitmap.compress(Bitmap.CompressFormat.PNG, 85, fOut);
                fOut.flush();
                fOut.close();
            } catch (FileNotFoundException e) {
                Log.e(TAG, "FileNotFoundException");
            } catch (IOException e) {
                Log.e(TAG, "IOException ");
            }
            */
        } else {
            Log.i(TAG, freeFrame.frameNo + ": failed");
        }
        return bitmap;
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

        switch (cause)
        {
            case ARSTREAM_READER_CAUSE_FRAME_COMPLETE:
                ARFrame freeFrame = new ARFrame(currentFrame.getByteData(), currentFrame.getDataSize(), isFlushFrame, count++);
                /*** I-Frame ***/
                if (isFlushFrame) {
                    frameQueue.clear();
                    frameQueue.offer(freeFrame);
                }
                /*** P-Frame ***/
                else {
                    frameQueue.offer(freeFrame);
                }
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