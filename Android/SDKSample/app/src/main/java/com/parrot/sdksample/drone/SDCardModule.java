package com.parrot.sdksample.drone;

import android.os.Environment;
import android.support.annotation.NonNull;
import android.util.Log;

import com.parrot.arsdk.ardatatransfer.ARDATATRANSFER_ERROR_ENUM;
import com.parrot.arsdk.ardatatransfer.ARDataTransferException;
import com.parrot.arsdk.ardatatransfer.ARDataTransferManager;
import com.parrot.arsdk.ardatatransfer.ARDataTransferMedia;
import com.parrot.arsdk.ardatatransfer.ARDataTransferMediasDownloader;
import com.parrot.arsdk.ardatatransfer.ARDataTransferMediasDownloaderCompletionListener;
import com.parrot.arsdk.ardatatransfer.ARDataTransferMediasDownloaderProgressListener;
import com.parrot.arsdk.arutils.ARUtilsManager;

import java.io.File;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;
import java.util.Locale;

public class SDCardModule {

    private static final String TAG = "SDCardModule";

    private static final String DRONE_MEDIA_FOLDER = "internal_000";
    private static final String MOBILE_MEDIA_FOLDER = "/ARSDKMedias/";

    public interface Listener {
        /**
         * Called before medias will be downloaded
         * Called on a separate thread
         * @param nbMedias the number of medias that will be downloaded
         */
        void onMatchingMediasFound(int nbMedias);

        /**
         * Called each time the progress of a download changes
         * Called on a separate thread
         * @param mediaName the name of the media
         * @param progress the progress of its download (from 0 to 100)
         */
        void onDownloadProgressed(String mediaName, int progress);

        /**
         * Called when a media download has ended
         * Called on a separate thread
         * @param mediaName the name of the media
         */
        void onDownloadComplete(String mediaName);
    }

    private final List<Listener> mListeners;

    private ARDataTransferManager mDataTransferManager;
    private ARUtilsManager mFtpList;
    private ARUtilsManager mFtpQueue;

    private boolean mThreadIsRunning;
    private boolean mIsCancelled;

    private int mNbMediasToDownload;
    private int mCurrentDownloadIndex;

    public SDCardModule(@NonNull ARUtilsManager ftpListManager, @NonNull ARUtilsManager ftpQueueManager) {

        mThreadIsRunning = false;
        mListeners = new ArrayList<>();

        mFtpList = ftpListManager;
        mFtpQueue = ftpQueueManager;

        ARDATATRANSFER_ERROR_ENUM result = ARDATATRANSFER_ERROR_ENUM.ARDATATRANSFER_OK;
        try {
            mDataTransferManager = new ARDataTransferManager();
        } catch (ARDataTransferException e) {
            Log.e(TAG, "Exception", e);
            result = ARDATATRANSFER_ERROR_ENUM.ARDATATRANSFER_ERROR;
        }

        if (result == ARDATATRANSFER_ERROR_ENUM.ARDATATRANSFER_OK) {
            // direct to external directory
            String externalDirectory = Environment.getExternalStorageDirectory().toString().concat(MOBILE_MEDIA_FOLDER);

            // if the directory doesn't exist, create it
            File f = new File(externalDirectory);
            if(!(f.exists() && f.isDirectory())) {
                boolean success = f.mkdir();
                if (!success) {
                    Log.e(TAG, "Failed to create the folder " + externalDirectory);
                }
            }
            try {
                mDataTransferManager.getARDataTransferMediasDownloader().createMediasDownloader(mFtpList, mFtpQueue, DRONE_MEDIA_FOLDER, externalDirectory);
            } catch (ARDataTransferException e) {
                Log.e(TAG, "Exception", e);
                result = e.getError();
            }
        }

        if (result != ARDATATRANSFER_ERROR_ENUM.ARDATATRANSFER_OK) {
            // clean up here because an error happened
            mDataTransferManager.dispose();
            mDataTransferManager = null;
        }
    }

    //region Listener functions
    public void addListener(Listener listener) {
        mListeners.add(listener);
    }

    public void removeListener(Listener listener) {
        mListeners.remove(listener);
    }
    //endregion Listener

    public void getFlightMedias(final String runId) {
        if (!mThreadIsRunning) {
            mThreadIsRunning = true;
            new Thread(new Runnable() {
                @Override
                public void run() {
                    ArrayList<ARDataTransferMedia> mediaList = getMediaList();

                    ArrayList<ARDataTransferMedia> mediasFromRun = null;
                    mNbMediasToDownload = 0;
                    if ((mediaList != null) && !mIsCancelled) {
                        mediasFromRun = getRunIdMatchingMedias(mediaList, runId);
                        mNbMediasToDownload = mediasFromRun.size();
                    }

                    notifyMatchingMediasFound(mNbMediasToDownload);

                    if ((mediasFromRun != null) && (mNbMediasToDownload != 0) && !mIsCancelled) {
                        downloadMedias(mediasFromRun);
                    }

                    mThreadIsRunning = false;
                    mIsCancelled = false;
                }
            }).start();
        }
    }

    public void getTodaysFlightMedias() {
        if (!mThreadIsRunning) {
            mThreadIsRunning = true;
            new Thread(new Runnable() {
                @Override
                public void run() {
                    ArrayList<ARDataTransferMedia> mediaList = getMediaList();

                    ArrayList<ARDataTransferMedia> mediasFromDate = null;
                    mNbMediasToDownload = 0;
                    if ((mediaList != null) && !mIsCancelled) {
                        GregorianCalendar today = new GregorianCalendar();
                        mediasFromDate = getDateMatchingMedias(mediaList, today);
                        mNbMediasToDownload = mediasFromDate.size();
                    }

                    notifyMatchingMediasFound(mNbMediasToDownload);

                    if ((mediasFromDate != null) && (mNbMediasToDownload != 0) && !mIsCancelled) {
                        downloadMedias(mediasFromDate);
                    }

                    mThreadIsRunning = false;
                    mIsCancelled = false;
                }
            }).start();
        }
    }

    public void cancelGetFlightMedias() {
        if (mThreadIsRunning) {
            mIsCancelled = true;
            ARDataTransferMediasDownloader mediasDownloader = null;
            if (mDataTransferManager != null) {
                mediasDownloader = mDataTransferManager.getARDataTransferMediasDownloader();
            }

            if (mediasDownloader != null) {
                mediasDownloader.cancelQueueThread();
            }
        }
    }

    private ArrayList<ARDataTransferMedia> getMediaList() {
        ArrayList<ARDataTransferMedia> mediaList = null;

        ARDataTransferMediasDownloader mediasDownloader = null;
        if (mDataTransferManager != null)
        {
            mediasDownloader = mDataTransferManager.getARDataTransferMediasDownloader();
        }

        if (mediasDownloader != null)
        {
            try
            {
                int mediaListCount = mediasDownloader.getAvailableMediasSync(false);
                mediaList = new ArrayList<>(mediaListCount);
                for (int i = 0; ((i < mediaListCount) && !mIsCancelled) ; i++)
                {
                    ARDataTransferMedia currentMedia = mediasDownloader.getAvailableMediaAtIndex(i);
                    mediaList.add(currentMedia);
                }
            }
            catch (ARDataTransferException e)
            {
                Log.e(TAG, "Exception", e);
                mediaList = null;
            }
        }
        return mediaList;
    }

    private @NonNull ArrayList<ARDataTransferMedia> getRunIdMatchingMedias(
            ArrayList<ARDataTransferMedia> mediaList,
            String runId) {
        ArrayList<ARDataTransferMedia> matchingMedias = new ArrayList<>();
        for (ARDataTransferMedia media : mediaList) {
            if (media.getName().contains(runId)) {
                matchingMedias.add(media);
            }

            // exit if the async task is cancelled
            if (mIsCancelled) {
                break;
            }
        }

        return matchingMedias;
    }

    private ArrayList<ARDataTransferMedia> getDateMatchingMedias(ArrayList<ARDataTransferMedia> mediaList,
                                                                 GregorianCalendar matchingCal) {
        ArrayList<ARDataTransferMedia> matchingMedias = new ArrayList<>();
        Calendar mediaCal = new GregorianCalendar();
        SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd'T'HHmmss", Locale.getDefault());
        for (ARDataTransferMedia media : mediaList) {
            // convert date in string to calendar
            String dateStr = media.getDate();
            try {
                Date mediaDate = dateFormatter.parse(dateStr);
                mediaCal.setTime(mediaDate);

                // if the date are the same day
                if ((mediaCal.get(Calendar.DAY_OF_MONTH) == (matchingCal.get(Calendar.DAY_OF_MONTH))) &&
                        (mediaCal.get(Calendar.MONTH) == (matchingCal.get(Calendar.MONTH))) &&
                        (mediaCal.get(Calendar.YEAR) == (matchingCal.get(Calendar.YEAR)))) {
                    matchingMedias.add(media);
                }
            } catch (ParseException e) {
                Log.e(TAG, "Exception", e);
            }

            // exit if the async task is cancelled
            if (mIsCancelled) {
                break;
            }
        }

        return matchingMedias;
    }

    private void downloadMedias(@NonNull ArrayList<ARDataTransferMedia> matchingMedias) {
        mCurrentDownloadIndex = 1;

        ARDataTransferMediasDownloader mediasDownloader = null;
        if (mDataTransferManager != null)
        {
            mediasDownloader = mDataTransferManager.getARDataTransferMediasDownloader();
        }

        if (mediasDownloader != null)
        {
            for (ARDataTransferMedia media : matchingMedias) {
                try {
                    mediasDownloader.addMediaToQueue(media, mDLProgressListener, null, mDLCompletionListener, null);
                } catch (ARDataTransferException e) {
                    Log.e(TAG, "Exception", e);
                }

                // exit if the async task is cancelled
                if (mIsCancelled) {
                    break;
                }
            }

            if (!mIsCancelled) {
                mediasDownloader.getDownloaderQueueRunnable().run();
            }
        }
    }

    //region notify listener block
    private void notifyMatchingMediasFound(int nbMedias) {
        List<Listener> listenersCpy = new ArrayList<>(mListeners);
        for (Listener listener : listenersCpy) {
            listener.onMatchingMediasFound(nbMedias);
        }
    }

    private void notifyDownloadProgressed(String mediaName, int progress) {
        List<Listener> listenersCpy = new ArrayList<>(mListeners);
        for (Listener listener : listenersCpy) {
            listener.onDownloadProgressed(mediaName, progress);
        }
    }

    private void notifyDownloadComplete(String mediaName) {
        List<Listener> listenersCpy = new ArrayList<>(mListeners);
        for (Listener listener : listenersCpy) {
            listener.onDownloadComplete(mediaName);
        }
    }
    //endregion notify listener block

    private final ARDataTransferMediasDownloaderProgressListener mDLProgressListener = new ARDataTransferMediasDownloaderProgressListener() {
        private int mLastProgressSent = -1;
        @Override
        public void didMediaProgress(Object arg, ARDataTransferMedia media, float percent) {
            final int progressInt = (int) Math.floor(percent);
            if (mLastProgressSent != progressInt) {
                mLastProgressSent = progressInt;
                notifyDownloadProgressed(media.getName(), progressInt);
            }
        }
    };

    private final ARDataTransferMediasDownloaderCompletionListener mDLCompletionListener = new ARDataTransferMediasDownloaderCompletionListener() {
        @Override
        public void didMediaComplete(Object arg, ARDataTransferMedia media, ARDATATRANSFER_ERROR_ENUM error) {
            notifyDownloadComplete(media.getName());

            // when all download are finished, stop the download runnable
            // in order to get out of the downloadMedias function
            mCurrentDownloadIndex ++;
            if (mCurrentDownloadIndex > mNbMediasToDownload ) {
                ARDataTransferMediasDownloader mediasDownloader = null;
                if (mDataTransferManager != null) {
                    mediasDownloader = mDataTransferManager.getARDataTransferMediasDownloader();
                }

                if (mediasDownloader != null) {
                    mediasDownloader.cancelQueueThread();
                }
            }
        }
    };
}
