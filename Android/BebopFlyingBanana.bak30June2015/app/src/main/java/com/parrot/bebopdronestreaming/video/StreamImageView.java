package com.parrot.bebopdronestreaming.video;

import android.graphics.Color;
import android.graphics.Point;
import android.view.WindowManager;
import android.widget.ImageView;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.util.AttributeSet;

import org.bytedeco.javacpp.opencv_core;

import static org.bytedeco.javacpp.opencv_core.cvGetSeqElem;

/**
 * Created by root on 6/27/15.
 */
public class StreamImageView extends ImageView {
    private Paint paint;
    private float scaleX, scaleY, scale = 1;
    public static int IMAGE_WIDTH = 640;
    public static int IMAGE_HEIGHT = 368;
    public ARFrame frame;

    public StreamImageView(Context context, AttributeSet attrs) {
        super(context, attrs);

        paint = new Paint();
        paint.setColor(Color.GREEN);
        paint.setStrokeWidth(2);
        paint.setStyle(Paint.Style.STROKE);

        /*
        Point size = new Point();
        ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getSize(size);
        scaleX = (float) size.x / IMAGE_WIDTH;
        scaleY = (float) size.y / IMAGE_HEIGHT;
        scale = (scaleX > scaleY) ? scaleX : scaleY;
        */

    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if (frame != null) {
            // Draw video stream
            setImageBitmap(frame.bitmap);

            // Draw faces
            if (frame.faces != null) {
                int total = frame.faces.total();
                for (int i = 0; i < total; i++) {
                    opencv_core.CvRect r = new opencv_core.CvRect(cvGetSeqElem(frame.faces, i));
                    int x = r.x();
                    int y = r.y();
                    int w = r.width();
                    int h = r.height();
                    canvas.drawRect(x*scale, y*scale, (x+w)*scale, (y+h)*scale, paint);
                }
            }
        }
    }

    public void setARFrame(ARFrame frame) {
        this.frame = frame;
    }
}
