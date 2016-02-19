package com.parrot.sdksample.view;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.util.AttributeSet;
import android.widget.ImageView;

import com.parrot.arsdk.arcontroller.ARFrame;

public class JSVideoView extends ImageView{

    private static final String TAG = "JSVideoView";

    private final Handler mHandler;

    private Bitmap mBmp;

    public JSVideoView(Context context) {
        super(context);
        // needed because setImageBitmap should be called on the main thread
        mHandler = new Handler(context.getMainLooper());
        customInit();
    }

    public JSVideoView(Context context, AttributeSet attrs) {
        super(context, attrs);
        // needed because setImageBitmap should be called on the main thread
        mHandler = new Handler(context.getMainLooper());
        customInit();
    }

    public JSVideoView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        // needed because setImageBitmap should be called on the main thread
        mHandler = new Handler(context.getMainLooper());
        customInit();
    }

    private void customInit() {
        setScaleType(ScaleType.CENTER_CROP);
    }

    public void displayFrame(ARFrame frame) {
        byte[] data = frame.getByteData();
        synchronized (this) {
            mBmp = BitmapFactory.decodeByteArray(data, 0, data.length);
        }

        mHandler.post(new Runnable() {
            @Override
            public void run() {
                synchronized (this) {
                    setImageBitmap(mBmp);
                }
            }
        });
    }
}
