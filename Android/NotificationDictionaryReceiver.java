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

import java.util.LinkedList;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;

public class NotificationDictionaryReceiver extends BroadcastReceiver 
{

    private static final HandlerThread NOTIFICATION_HANDLER_THREAD = new HandlerThread("NotificationDictionaryReceiver");

    private static final Handler NOTIFICATION_HANDLER = initHandler();

    private static final Handler initHandler()
    {
        NOTIFICATION_HANDLER_THREAD.start();
        Handler handler = new Handler(NOTIFICATION_HANDLER_THREAD.getLooper());
        return handler;
    }

    private final UpdateRunnable mUpdateRunnable;
    
    public NotificationDictionaryReceiver(NotificationDictionaryReceiverDelegate delegate)
    {
        this.mUpdateRunnable = new UpdateRunnable(delegate);
    }

    @Override
    public void onReceive(Context context, Intent intent)
    {
        Bundle dictionary = intent.getExtras();
        synchronized (this.mUpdateRunnable)
        {
        	this.mUpdateRunnable.dictionaryQueue.add(dictionary);
        }
        NOTIFICATION_HANDLER.post(this.mUpdateRunnable);
    }

    private static class UpdateRunnable implements Runnable
    {

        private LinkedList<Bundle> dictionaryQueue;

        private final NotificationDictionaryReceiverDelegate delegate;

        private UpdateRunnable(NotificationDictionaryReceiverDelegate delegate)
        {
            this.delegate = delegate;
            this.dictionaryQueue = new LinkedList<Bundle>();
        }

        @Override
        public void run()
        {
            if (delegate != null)
            {
                synchronized (this)
                {
                    delegate.onNotificationDictionaryChanged( dictionaryQueue.poll());
                }
            }
        }
    }
}

