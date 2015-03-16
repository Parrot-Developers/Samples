package com.parrot.bobopdronepiloting;

import com.parrot.arsdk.arcommands.ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_ENUM;

public interface DeviceControllerListener
{
    public void onDisconnect();
    public void onUpdateBattery(final byte percent);
    public void onFlyingStateChanged(ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_ENUM state);
}
