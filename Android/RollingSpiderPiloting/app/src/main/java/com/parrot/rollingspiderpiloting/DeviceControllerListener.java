package com.parrot.rollingspiderpiloting;

public interface DeviceControllerListener
{
    public void onDisconnect();
    public void onUpdateBattery(final byte percent);
}
