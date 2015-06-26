package com.parrot.bobopdronepiloting.video;

import android.util.Log;

import java.nio.Buffer;
import java.util.Arrays;

import com.parrot.arsdk.arsal.ARNativeData;

import org.bytedeco.javacpp.DoublePointer;
import org.bytedeco.javacpp.avcodec;
import org.bytedeco.javacpp.avcodec.AVCodec;
import org.bytedeco.javacpp.avcodec.AVCodecContext;
import org.bytedeco.javacpp.avcodec.AVPacket;
import org.bytedeco.javacpp.avcodec.AVPicture;
import org.bytedeco.javacpp.BytePointer;
import org.bytedeco.javacpp.avutil;
import org.bytedeco.javacpp.PointerPointer;
import org.bytedeco.javacpp.avutil.AVFrame;
import org.bytedeco.javacpp.swscale;

import org.bytedeco.javacv.Frame;
import org.bytedeco.javacv.FrameGrabber.ImageMode;

/**
 * Created by root on 5/27/15.
 */
public class ARFrame {
    public static int IMAGE_WIDTH = 640;
    public static int IMAGE_HEIGHT = 368;
    public static int PIXEL_FORMAT = 3;
    public static AVCodecContext video_c = null;
    public static ImageMode IMAGE_MODE = ImageMode.COLOR;
    public static boolean DEINTERLACE = true;

    private static String TAG = "ARFrame";

    /*** data buffer ***/
    public byte[] rawData;
    /*** size of the buffer ***/
    public int size;
    /*** I-frame ***/
    /* Also known as key frames, I-frames are completely self-referential and don't use any information
     * from any other frames. These are the largest frames,  and the highest quality, but the least
     * efficient from a compression perspective. */
    public boolean isFlushFrame;
    /*** P-frame ***/
    /* P-frames are "predicted" frames. When producing a P-frame, the encoder can look backwards to
     * previous I or P-frames for redundant picture information. */

    /*** Frame ***/
    public Frame frame;
    public int frameNo;

    public ARFrame(byte[] rawData, int dataSize, boolean isFlushFrame, int frameNo) {
        this.rawData = rawData;
        this.size = dataSize;
        this.isFlushFrame = isFlushFrame;
        this.frameNo = frameNo;
    }

    public int getImageWidth() {
        return IMAGE_WIDTH;
    }

    public int getImageHeight() {
        return IMAGE_HEIGHT;
    }

    public ImageMode getImageMode() {
        return IMAGE_MODE;
    }

    public int getPixelFormat() { return PIXEL_FORMAT; }

    public Frame decodeFromVideo() {
        frame = new Frame();
        AVFrame picture = null;
        AVFrame picture_rgb = null;
        AVPacket receivedVideoPacket = null;
        swscale.SwsContext img_convert_ctx = null;
        BytePointer[] image_ptr = new BytePointer[] { null };
        Buffer[] image_buf = new Buffer[] { null };

        // Initialize receivedVideoPacket with byte[] rawData
        receivedVideoPacket = new AVPacket(size);
        receivedVideoPacket.data(new BytePointer(rawData));

        //Initialize optional fields of a packet with default values. Excluding data and size information
        avcodec.av_init_packet(receivedVideoPacket);

        //Allocates enough memory for the data array and copies it.
        BytePointer videoData = new BytePointer(rawData);

        /*** I-Frame ***/
        if (isFlushFrame == true) {

            AVCodec codec = avcodec.avcodec_find_decoder(avcodec.AV_CODEC_ID_H264);

            if (codec != null) {

                //Allocate an AVCodecContext and set its fields to default values
                video_c = avcodec.avcodec_alloc_context3(codec);

                video_c.width(getImageWidth());
                video_c.height(getImageHeight());
                //Pixel format, see AV_PIX_FMT_xxx.May be set by the demuxer if known from headers. May be overridden by the decoder if it knows better
                video_c.pix_fmt(avutil.AV_PIX_FMT_YUV420P);
                video_c.codec_type(avutil.AVMEDIA_TYPE_VIDEO);
                video_c.extradata(videoData);
                video_c.extradata_size(videoData.capacity());
                //encoding: Set by user | decoding: Set by user
                video_c.flags2(video_c.flags2() | avcodec.CODEC_FLAG2_CHUNKS);

                //Initialize the AVCodecContext to use the given AVCodec.
                avcodec.avcodec_open2(video_c, codec, (PointerPointer) null);

            } else {
                return null;
            }
        }

        // First I-frame have not been received, exit decoding
        if (video_c == null) {
            return null;
        }

        //old - Allocates an AVFrame and sets its fields to default values
        //Allocate video frame and an AVFrame for the RGB image
        if ((picture = avcodec.avcodec_alloc_frame()) == null) {
            return null;
        }
        if ((picture_rgb = avcodec.avcodec_alloc_frame()) == null) {
            return null;
        }

        int width = getImageWidth();
        int height = getImageHeight();
        int fmt = getPixelFormat();

        //old - Calculate the size in bytes that a picture of the given width and height would occupy if stored in the given picture format
        //Determine required buffer size and allocate buffer
        int size = avcodec.avpicture_get_size(fmt, width, height);
        image_ptr = new BytePointer[] { new BytePointer(avutil.av_malloc(size)).capacity(size)};
        image_buf = new Buffer[] { image_ptr[0].asBuffer() };

        //old - Setup the picture fields based on the specified image parameters and the provided image data buffer.
        //Assign appropriate parts of buffer to image planes in picture rgb
        //Note that picture_rgb is an AVFrame, but AVFrame is a superset of AVPicture
        avcodec.avpicture_fill(new AVPicture(picture_rgb), image_ptr[0], fmt, width, height);
        picture_rgb.format(fmt);
        picture_rgb.width(width);
        picture_rgb.height(height);

        receivedVideoPacket.data(videoData);
        receivedVideoPacket.size(videoData.capacity());

        int decodedFrameLength;
        //Zero if no frame could be decompressed, otherwise, it is nonzero
        int[] isVideoDecoded = new int[1];

        //Decode the video frame of size avpkt->size from avpkt->data into picture.
        //AVCodecContext avContext, AVFrame	picture, int[] got_picture_ptr, AVPacket avpkt
        decodedFrameLength = avcodec.avcodec_decode_video2(video_c,
                picture, isVideoDecoded, receivedVideoPacket);

        // Did we get a video frame?

        if ((decodedFrameLength >= 0) && (isVideoDecoded[0] != 0)) {

            /*** Process image same as javacv ***/
            frame.imageWidth = video_c.width();
            frame.imageHeight = video_c.height();
            frame.imageDepth = Frame.DEPTH_UBYTE;
            // AVFrame -> Frame
            // Convert the image

            // Deinterlace the picture
            /*
            if (DEINTERLACE) {
                AVPicture p = new AVPicture(picture);
                avcodec.avpicture_deinterlace(p, p, video_c.pix_fmt(), video_c.width(), video_c.height());
            }
            */

            // Convert the image into BGR or GRAY format that OpenCV uses
            img_convert_ctx = swscale.sws_getCachedContext(img_convert_ctx, video_c.width(), video_c.height(), video_c.pix_fmt(),
                    frame.imageWidth, frame.imageHeight, getPixelFormat(), swscale.SWS_BILINEAR, null, null, (DoublePointer)null);
            if (img_convert_ctx == null) {
                return null;
            }

            //Convert the image from its native format to RGB or GRAY
            swscale.sws_scale(img_convert_ctx, new PointerPointer(picture), picture.linesize(), 0,
                    video_c.height(), new PointerPointer(picture_rgb), picture_rgb.linesize());
            frame.imageStride = picture_rgb.linesize(0);
            frame.image = image_buf;

            frame.image[0].limit(frame.imageHeight * frame.imageStride);
            frame.imageChannels = frame.imageStride / frame.imageWidth;
        } else {
            return null;
        }
        return frame;
    }
}