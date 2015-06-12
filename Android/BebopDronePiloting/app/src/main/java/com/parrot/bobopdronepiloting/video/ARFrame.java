package com.parrot.bobopdronepiloting.video;

import com.parrot.arsdk.arsal.ARNativeData;

/**
 * Created by root on 5/27/15.
 */
public class ARFrame {
    public byte[] rawData; /**< data buffer*/
    public int size; /**< size of the buffer */
    public boolean isIframe;

    /*** I-frame ***/

    /*** P-frame ***/
    public byte[] sps; //Sequence Parameter Set
    public byte[] pps; //Picture Parameter Set

    public ARFrame(ARNativeData rawFrame, boolean isFlushFrame)
    {
        this.rawData = rawFrame.getByteData();
        this.size = rawFrame.getDataSize();
        this.isIframe = isFlushFrame;
    }

    public static ARFrame getFrameFromData(ARNativeData currentRawFrame, boolean isFlushFrame)
    {
        // get the frame which has the given data
        ARFrame rawFrame = null;


        /*
        int i = 0;
        for (i = 0; i < deviceManager->rawFramePoolCapacity; i++)
        {
            RawFrame_t *currentRawFrame = deviceManager->freeRawFramePool[i];
            if (currentRawFrame != NULL && currentRawFrame->data != NULL)
            {
                if (currentRawFrame->data == data)
                {
                    rawFrame = currentRawFrame;
                    break;
                }
            }
        }
        ARSAL_Mutex_Unlock (&(deviceManager->mutex));
        */
        return rawFrame;
    }
}
