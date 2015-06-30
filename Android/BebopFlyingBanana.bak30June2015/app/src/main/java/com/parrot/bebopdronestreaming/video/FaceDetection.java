package com.parrot.bebopdronestreaming.video;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.res.AssetManager;
import android.content.res.XmlResourceParser;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ImageFormat;
import android.graphics.Paint;
import android.hardware.Camera;
import android.hardware.Camera.Size;
import android.os.Bundle;
import android.os.Environment;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.util.Log;
import android.graphics.Bitmap;

import com.parrot.bebopdronestreaming.R;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.nio.ByteBuffer;
import java.util.List;

import org.bytedeco.javacpp.BytePointer;
import org.bytedeco.javacv.Frame;
import org.bytedeco.javacpp.Loader;
import org.bytedeco.javacpp.opencv_objdetect;
import org.bytedeco.javacv.OpenCVFrameConverter;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserFactory;

import static org.bytedeco.javacpp.opencv_core.*;
import static org.bytedeco.javacpp.opencv_imgproc.*;
import static org.bytedeco.javacpp.opencv_objdetect.*;
import static org.bytedeco.javacpp.opencv_highgui.*;

/**
 * Created by root on 6/27/15.
 */
public class FaceDetection {
    public static int IMAGE_WIDTH = 640;
    public static int IMAGE_HEIGHT = 368;
    public static final int SUBSAMPLING_FACTOR = 4;

    private android.content.Context context;
    private static File classifierFile;
    private IplImage image;
    private IplImage grayImage;
    private IplImage smallImage;
    private static CvHaarClassifierCascade classifier;
    private CvMemStorage storage;
    private CvSeq faces;
    private OpenCVFrameConverter.ToIplImage converterToIpl;

    private static String TAG = "FaceDetection";

    public FaceDetection(android.content.Context context) {
        this.context = context;

        // Load the classifier file from Java resources.
        try {
            InputStream input = context.getAssets().open("haarcascade_frontalface_default.xml");

            String file_path = Environment.getExternalStorageDirectory().getAbsolutePath() + "/BebopDroneStreaming";
            File dir = new File(file_path);
            if (!dir.exists()) {
                dir.mkdirs();
            }
            classifierFile = new File(dir, "classifier.xml");
            OutputStream output = new FileOutputStream(classifierFile);
            int read = 0;
            byte[] bytes = new byte[1024];
            while ((read = input.read(bytes)) != -1) {
                output.write(bytes, 0, read);
            }
            input.close();
            output.close();

        } catch (IOException e) {
            Log.e(TAG, "Could not extract the classifier file from Java resource.");
            e.printStackTrace();
        }

        // Preload the opencv_objdetect module to work around a known bug.
        Loader.load(opencv_objdetect.class);
        if (!classifierFile.exists()) {
            Log.e(TAG, "Could not extract the classifier file from Java resource.");
        }
        classifier = new CvHaarClassifierCascade(cvLoad(classifierFile.getAbsolutePath()));
        //classifierFile.delete();
        if (classifier.isNull()) {
            Log.e(TAG, "CCould not load the classifier file.");
        }
        storage = CvMemStorage.create();
        converterToIpl = new OpenCVFrameConverter.ToIplImage();
    }

    public CvSeq detect(Frame frame) {
        /*** Process Image ***/
        image = converterToIpl.convert(frame);
        grayImage = IplImage.create(IMAGE_WIDTH, IMAGE_HEIGHT, IPL_DEPTH_8U, 1);
        //smallImage = IplImage.create(IMAGE_WIDTH / SUBSAMPLING_FACTOR, IMAGE_HEIGHT / SUBSAMPLING_FACTOR, IPL_DEPTH_8U, 1);
        cvClearMemStorage(storage);
        cvCvtColor(image, grayImage, CV_BGR2GRAY);
        //cvResize(grayImage, smallImage, CV_INTER_AREA);
        faces = cvHaarDetectObjects(grayImage, classifier, storage, 1.1, 3, CV_HAAR_DO_CANNY_PRUNING);
        return faces;
    }
}
