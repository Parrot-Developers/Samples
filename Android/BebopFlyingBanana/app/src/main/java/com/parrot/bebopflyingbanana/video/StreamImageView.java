package com.parrot.bebopflyingbanana.video;

import android.graphics.Color;
import android.graphics.Point;
import android.view.WindowManager;
import android.widget.ImageView;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.util.AttributeSet;

import static org.bytedeco.javacpp.opencv_core.*;

/**
 * Created by root on 6/27/15.
 */
public class StreamImageView extends ImageView {
    private Paint paint;
    private float scaleX, scaleY, scale;
    private float offsetX = 0, offsetY = 0;
    public static int IMAGE_WIDTH = 640;
    public static int IMAGE_HEIGHT = 368;
    public ARFrame frame;

    public static String TAG = "StreamImageView";

    public StreamImageView(Context context, AttributeSet attrs) {
        super(context, attrs);

        paint = new Paint();
        paint.setColor(Color.GREEN);
        paint.setStrokeWidth(2);
        paint.setStyle(Paint.Style.STROKE);


        Point size = new Point();
        ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getSize(size);
        scaleX = (float) size.x / IMAGE_WIDTH;
        scaleY = (float) size.y / IMAGE_HEIGHT;
        if (scaleX > scaleY) {
            scale = scaleX;
            offsetX = 0;
            offsetY = ((IMAGE_HEIGHT * scale) - size.y ) / 2;
        } else {
            scale = scaleY;
            offsetY = 0;
            offsetX = ((IMAGE_WIDTH * scale) - size.x ) / 2;
        }

    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if (frame != null) {

            // Draw faces
            if (frame.faces != null) {
                int total = frame.faces.total();
                for (int i = 0; i < total; i++) {
                    CvRect r = new CvRect(cvGetSeqElem(frame.faces, i));
                    if (!r.isNull()) {
                        int x = r.x();
                        int y = r.y();
                        int w = r.width();
                        int h = r.height();
                        canvas.drawRect((x - offsetX) * scale, (y - offsetY) * scale, (x + w) * scale, (y + h) * scale, paint);
                    }
                }
            }
        }
    }

    public void setARFrame(ARFrame frame) {
        this.frame = frame;
    }
}
