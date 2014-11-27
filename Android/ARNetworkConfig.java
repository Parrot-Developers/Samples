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

import java.util.ArrayList;
import java.util.List;

import com.parrot.arsdk.arnetwork.ARNetworkIOBufferParam;
import com.parrot.arsdk.arstream.ARStreamReader;

public abstract class ARNetworkConfig
{
    private static final String TAG = "NetworkConfig";
    
    protected static int iobufferC2dNack = -1;
    protected static int iobufferC2dAck = -1;
    protected static int iobufferC2dEmergency = -1;
    protected static int iobufferC2dArstreamAck = -1;
    protected static int iobufferD2cNavdata = -1;
    protected static int iobufferD2cEvents = -1;
    protected static int iobufferD2cArstreamData = -1;
    
    protected static int inboundPort = -1;
    protected static int outboundPort = -1;
    
    protected static List<ARNetworkIOBufferParam> c2dParams = new ArrayList<ARNetworkIOBufferParam>();
    protected static List<ARNetworkIOBufferParam> d2cParams = new ArrayList<ARNetworkIOBufferParam>();
    protected static int commandsBuffers[] = {};
    
    protected static boolean hasVideo = false;
    protected static int videoMaxAckInterval = -1;
    
    protected static int bleNotificationIDs[] = null;
    
    /*
    public static int idToIndex (int id)
    {
        for (int i = 0; i < num_params; i ++)
        {
            if (params[i].ID == id)
            {
                return i;
            }
        }
        return -1;
    }*/
    
    /** Return a boolean indicating whether the device supports video streaming. */
    public boolean hasVideo()
    {
        return hasVideo;
    }
    
    /** Get the controller to device parameters.
     * @note The data shall not be modified nor freed by the user.
     */
    public List<ARNetworkIOBufferParam> getC2dParamsList()
    {
        return c2dParams;
    }
    
    /** Get the device to controller parameters.
     * @note The data shall not be modified nor freed by the user.
     */
    public List<ARNetworkIOBufferParam> getD2cParamsList()
    {
        return d2cParams;
    }
    
    /** Get the controller to device parameters.
     * @note The data shall not be modified nor freed by the user.
     */
    public ARNetworkIOBufferParam[] getC2dParams()
    {
        return c2dParams.toArray(new ARNetworkIOBufferParam[c2dParams.size()]);
    }
    
    /** Get the device to controller parameters.
     * @note The data shall not be modified nor freed by the user.
     */
    public ARNetworkIOBufferParam[] getD2cParams()
    {
        return d2cParams.toArray(new ARNetworkIOBufferParam[d2cParams.size()]);
    }
    
    public int getC2dNackId()
    {
        return iobufferC2dNack;
    }
    
    public int getC2dAckId()
    {
        return iobufferC2dAck;
    }
    
    public int getC2dEmergencyId()
    {
        return iobufferC2dEmergency;
    }
    
    /** Get an array of buffer IDs from which to read commands. */
    public int[] getCommandsIOBuffers()
    {
        return commandsBuffers;
    }
    
    /** Get the buffer ID of the video stream data channel. */
    public int getVideoDataIOBuffer()
    {
        return iobufferD2cArstreamData;
    }
    
    /** Get the buffer ID of the video stream acknowledgment channel. */
    public int getVideoAckIOBuffer()
    {
        return iobufferC2dArstreamAck;
    }
    
    /** Get the buffer ID of the acknowledged channel on which all the common commands will be sent.
     * @warning I insist that it MUST be the ID of an acknowledged IOBuffer. Returning an ID for an
     * unacknowledged IOBuffer will cause the controller to wait for a notification that will never
     * come.
     */
    public int commonCommandsAckedIOBuffer()
    {
        return iobufferC2dAck;
    }
    
    /** Return the inbound port number for WiFi devices.
     * @fixme Remove this and use ARDISCOVERY_Connection instead.
     */
    public int getInboundPort()
    {
        return inboundPort;
    }
    
    /** Return the outbound port number for WiFi devices.
     * @fixme Remove this and use ARDISCOVERY_Connection instead.
     */
    public int getOutboundPort()
    {
        return outboundPort;
    }
    
    /** 
     * specify the ID to notify
     * Android 4.3 BLE can notify only 4 characteristics
     */
    public int[] getBLENotificationIDs()
    {
        return bleNotificationIDs;
    }
    
    public int getDefaultVideoMaxAckInterval()
    {
    	return videoMaxAckInterval;
    }
    
    /** 
     * Add a StreamReader IOBuffer
     * @param maxFragmentSize Maximum size of the fragment to send
     * @param maxNumberOfFragment Maximum number of the fragment to send
     */
    public void addStreamReaderIOBuffer (int maxFragmentSize, int maxNumberOfFragment)
    {
        if ((iobufferC2dArstreamAck != -1) && (iobufferD2cArstreamData != -1))
        {
            /*remove the Stream parameters of the last connection*/
            for(ARNetworkIOBufferParam param : c2dParams)
            {
                if(param.getId() == iobufferC2dArstreamAck)
                {
                    c2dParams.remove(param);
                    
                    break;
                }
            }
            
            for(ARNetworkIOBufferParam param : d2cParams)
            {
                if(param.getId() == iobufferD2cArstreamData)
                {
                    d2cParams.remove(param);
                    
                    break;
                }
            }
            
            /* add the Stream parameters for the new connection */
            c2dParams.add (ARStreamReader.newAckARNetworkIOBufferParam (iobufferC2dArstreamAck));
            d2cParams.add (ARStreamReader.newDataARNetworkIOBufferParam (iobufferD2cArstreamData, maxFragmentSize, maxNumberOfFragment));
        }
    }
}
