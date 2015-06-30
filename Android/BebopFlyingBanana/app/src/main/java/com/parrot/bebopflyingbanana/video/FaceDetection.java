package com.parrot.bebopflyingbanana.video;

import android.os.Environment;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import org.bytedeco.javacv.Frame;
import org.bytedeco.javacpp.Loader;
import org.bytedeco.javacpp.opencv_objdetect;
import org.bytedeco.javacv.OpenCVFrameConverter;

import static org.bytedeco.javacpp.opencv_core.*;
import static org.bytedeco.javacpp.opencv_imgproc.*;
import static org.bytedeco.javacpp.opencv_objdetect.*;

/**
 * Created by root on 6/27/15.
 */
public class FaceDetection {
    public static int IMAGE_WIDTH = 640;
    public static int IMAGE_HEIGHT = 368;

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

            String file_path = Environment.getExternalStorageDirectory().getAbsolutePath() + "/BebopFlyingBanana";
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
