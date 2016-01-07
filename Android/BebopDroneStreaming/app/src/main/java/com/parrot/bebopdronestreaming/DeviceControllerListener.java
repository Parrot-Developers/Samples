package com.parrot.bebopdronestreaming;

import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_ENUM;
import android.graphics.Bitmap;

public interface DeviceControllerListener
{
    public void onDisconnect();
    public void onUpdateBattery(final byte percent);
    public void onFlyingStateChanged(ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_ENUM state);
    public void onUpdateStream(Bitmap bitmap);
}
