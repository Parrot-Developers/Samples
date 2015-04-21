//
//  Decoder_Manager.c
//  
//
//  Created by Djavan Bertrand on 14/04/2015.
//
//

#include "DecoderManager.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

#include <libARSAL/ARSAL_Print.h>

/*****************************************
 *
 *             define :
 *
 *****************************************/
#define ARCODECS_MANAGER_TAG    "ARCODECS_Manager"

typedef struct _ARCODECS_Manager_FFMPEGDecoder_t_
{
    AVCodec *codec;
    AVCodecContext *codecCtx;
    AVFrame *decodedFrame;
    AVPacket avpkt;
    uint8_t *outputData;
    int outputDataSize;
} ARCODECS_Manager_FFMPEGDecoder_t;

/**
 * @brief Video and audio codecs manager structure allow to decode video and audio.
 */
struct ARCODECS_Manager_t
{
    ARCODECS_Manager_GetNextDataCallback_t callback;
    void *callbackCustomData;
    ARCODECS_Manager_FFMPEGDecoder_t *decoder;
    ARCODECS_Manager_Frame_t outputFrame;
};

/**
 * @brief define the components of the format RGBA (also valid for BGRA).
 */
typedef enum
{
    ARCODECS_FORMAT_RGBA_COMPONENT = 0,
    ARCODECS_FORMAT_RGBA_COMPONENT_MAX,
} eARCODECS_FORMAT_RGBA_COMPONENT;

/**
 * @brief define the components of the format YUV
 */
typedef enum
{
    ARCODECS_FORMAT_YUV_COMPONENT_Y = 0,
    ARCODECS_FORMAT_YUV_COMPONENT_U,
    ARCODECS_FORMAT_YUV_COMPONENT_V,
    ARCODECS_FORMAT_YUV_COMPONENT_MAX,
} eARCODECS_FORMAT_YUV_COMPONENT;


/**
 * @brief Initialize the OutputFrame
 * @param manager manager Decoder
 * @param[in] numberOfComponent nubmer of component of the output frame
 * @return error
 */
eARCODECS_ERROR ARCODECS_Manager_InitOutputFrame (ARCODECS_Manager_t *manager, uint32_t numberOfComponent);

/**
 * @brief Create a new FFMPEG decoder
 * @warning This function allocate memory
 * @post ARCODECS_Manager_DeleteFFMPEGDecoder() must be called to delete the codecs manager and free the memory allocated.
 * @param[out] error pointer on the error output.
 * @return Pointer on the new FFMPEG decoder
 * @see ARCODECS_Manager_DeleteFMPEGDecoder()
 */
ARCODECS_Manager_FFMPEGDecoder_t *ARCODECS_Manager_NewFFMPEGDecoder (eARCODECS_ERROR *error);

/**
 * @brief Delete the FFMPEG decoder
 * @warning This function free memory
 * @param ffmpegDecoder the FFMPEG decoder to delete
 * @see ARCODECS_Manager_NewFFMPEGDecoder()
 */
void ARCODECS_Manager_DeleteFFMPEGDecoder (ARCODECS_Manager_FFMPEGDecoder_t **ffmpegDecoder);

/**
 * @brief decode one frame with FFMPEG
 * @warning This function decode video with FFMPEG
 * @param[in] ffmpegDecoder ffmpeg decoder
 * @param[in] data data to decode
 * @param[in] size size of the data to decode
 * @@param[out] outputFrame Output frame decoded - NULL if decoding error occured with update of error
 * @return error
 */
eARCODECS_ERROR ARCODECS_Manager_FFMPEGDecode (ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder, uint8_t *data , int size, ARCODECS_Manager_Frame_t *outputFrame);

/*****************************************
 *
 *             implementation :
 *
 *****************************************/

ARCODECS_Manager_t* ARCODECS_Manager_New (ARCODECS_Manager_GetNextDataCallback_t callback, void *callbackCustomData, eARCODECS_ERROR *error)
{
    ARCODECS_Manager_t *manager = NULL;
    eARCODECS_ERROR err = ARCODECS_OK;
    
    /** Check parameters */
    if(callback == NULL)
    {
        err = ARCODECS_ERROR_BAD_PARAMETER;
    }
    
    if(err == ARCODECS_OK)
    {
        /** Create the Manager */
        manager = malloc (sizeof (ARCODECS_Manager_t));
        if (manager == NULL)
        {
            err = ARCODECS_ERROR_ALLOC;
        }
    }
    
    if(err == ARCODECS_OK)
    {
        /** Initialize to default values */
        manager->callback = callback;
        manager->callbackCustomData = callbackCustomData;
        
        ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder = NULL;
        
        /* Allocate the component array of the outputFrame */
        err = ARCODECS_Manager_InitOutputFrame (manager, ARCODECS_FORMAT_YUV_COMPONENT_MAX);
        
        /* Initialize manager to decode H264 with FFMPEG decoder */
        if (err == ARCODECS_OK)
        {
            ffmpegDecoder = ARCODECS_Manager_NewFFMPEGDecoder (&err);
        }
        /* No else: skipped by an error */
        
        if (err == ARCODECS_OK)
        {
            manager->decoder = ffmpegDecoder;
        }
    }
    
    /** delete the Manager if an error occurred */
    if (err != ARCODECS_OK)
    {
        ARSAL_PRINT (ARSAL_PRINT_ERROR, ARCODECS_MANAGER_TAG, "error: %i", err);
        ARCODECS_Manager_Delete (&manager);
    }
    
    /** return the error */
    if (error != NULL)
    {
        *error = err;
    }
    
    return manager;
}

ARCODECS_Manager_Frame_t* ARCODECS_Manager_Decode(ARCODECS_Manager_t *manager, eARCODECS_ERROR *error)
{
    ARCODECS_Manager_Frame_t *outputFrame = NULL;
    int ret;
    eARCODECS_ERROR err = ARCODECS_OK;
    
    if(manager == NULL)
    {
        err = ARCODECS_ERROR_BAD_PARAMETER;
    }
    
    if(err == ARCODECS_OK)
    {
        ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder = (ARCODECS_Manager_FFMPEGDecoder_t *)(manager->decoder);
        eARCODECS_ERROR error = ARCODECS_OK;
        uint8_t *data = NULL;
        int size = 0;
        
        /* callback to get the frame to decode */
        size = manager->callback((&data), manager->callbackCustomData);

        outputFrame = &manager->outputFrame;
        error = ARCODECS_Manager_FFMPEGDecode (ffmpegDecoder, data, size, outputFrame);
    }
    
    /* return the error */
    if (error != NULL)
    {
        *error = err;
    }
    
    return outputFrame;
}

void ARCODECS_Manager_Delete(ARCODECS_Manager_t **manager)
{
    ARCODECS_Manager_t *managerPtr = NULL;
    
    if (manager)
    {
        managerPtr = *manager;
        if (managerPtr)
        {
            ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder = (ARCODECS_Manager_FFMPEGDecoder_t *)(managerPtr->decoder);
            ARCODECS_Manager_DeleteFFMPEGDecoder (&ffmpegDecoder);
            
            free (managerPtr);
            managerPtr = NULL;
        }
        /* No else: No manager to free */
        
        *manager = NULL;
    }
}



/*****************************************
 *
 *             private implementation :
 *
 *****************************************/

eARCODECS_ERROR ARCODECS_Manager_InitOutputFrame (ARCODECS_Manager_t *manager, uint32_t numberOfComponent)
{
    /* Initialize the OutputFrame */
    
    eARCODECS_ERROR error = ARCODECS_OK;
    
    /* check parameters */
    if (manager == NULL)
    {
        error = ARCODECS_ERROR_BAD_PARAMETER;
    }
    /* No else ; check parameters (setting error to ARCODECS_ERROR_BAD_PARAMETER, stops the processing) */
    
    if (error == ARCODECS_OK)
    {
        /* Initialize the outputFrame */
        memset(&manager->outputFrame, 0, sizeof(ARCODECS_Manager_Frame_t));
        
        /* Allocate the component array of the outputFrame */
        manager->outputFrame.componentArray = calloc (numberOfComponent, sizeof(ARCODECS_Manager_Component_t));
        if (manager->outputFrame.componentArray != NULL)
        {
            manager->outputFrame.numberOfComponent = numberOfComponent;
        }
        else
        {
            error = ARCODECS_ERROR_ALLOC;
        }
        
    }
    /* No else: skipped by an error */
    
    return error;
}

ARCODECS_Manager_FFMPEGDecoder_t *ARCODECS_Manager_NewFFMPEGDecoder (eARCODECS_ERROR *error)
{
    /* -- Create a new FFMPEG decoder -- */
    ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder = NULL;
    eARCODECS_ERROR localError = ARCODECS_OK;
    
    ffmpegDecoder = calloc (1, sizeof(ARCODECS_Manager_FFMPEGDecoder_t));
    if (ffmpegDecoder == NULL)
    {
        localError = ARCODECS_ERROR_ALLOC;
    }
    /* No else: the FFMPEG Decoder is successfully allocated and initialized to "0" */
    if (localError == ARCODECS_OK)
    {
        /* register all the codecs */
        avcodec_register_all();
        
        //av_log_set_level(AV_LOG_WARNING);
        av_log_set_level(AV_LOG_QUIET);
        
        /* get the H264 decoder */
        ffmpegDecoder->codec = avcodec_find_decoder (AV_CODEC_ID_H264);
        if(ffmpegDecoder->codec == NULL)
        {
            localError = ARCODECS_ERROR_MANAGER_UNSUPPORTED_CODEC;
        }
        /* No else: the codec is successfully found */
    }
    /* No else: skipped by an error */
    if(localError == ARCODECS_OK)
    {
        ffmpegDecoder->codecCtx = avcodec_alloc_context3(ffmpegDecoder->codec);
        if(ffmpegDecoder->codecCtx == NULL)
        {
            localError = ARCODECS_ERROR_ALLOC;
        }
        /* No else : the ffmpeg context is successfully allocated */
    }
    /* No else: skipped by an error */
    if(localError == ARCODECS_OK)
    {
        /* initialize the codec context */
        ffmpegDecoder->codecCtx->pix_fmt = PIX_FMT_YUV420P;
        ffmpegDecoder->codecCtx->skip_frame = AVDISCARD_DEFAULT;
        ffmpegDecoder->codecCtx->error_concealment = FF_EC_GUESS_MVS | FF_EC_DEBLOCK;
        ffmpegDecoder->codecCtx->skip_loop_filter = AVDISCARD_DEFAULT;
        ffmpegDecoder->codecCtx->workaround_bugs = FF_BUG_AUTODETECT;
        ffmpegDecoder->codecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
        ffmpegDecoder->codecCtx->codec_id = AV_CODEC_ID_H264;
        ffmpegDecoder->codecCtx->skip_idct = AVDISCARD_DEFAULT;
        
        if (avcodec_open2(ffmpegDecoder->codecCtx, ffmpegDecoder->codec, NULL) < 0)
        {
            localError = ARCODECS_ERROR_MANAGER_CODEC_OPENING;
        }
        /* No else: the codec is not open ; localError is set to ARCODECS_ERROR_MANAGER_CODEC_OPENING ; stops the processing */
    }
    /* No else: skipped by an error */
    if(localError == ARCODECS_OK)
    {
        ffmpegDecoder->decodedFrame = avcodec_alloc_frame();
        if (ffmpegDecoder->decodedFrame == NULL)
        {
            localError = ARCODECS_ERROR_ALLOC;
        }
        /* No else: the decodedFrame is not allocate ; localError is set to ARCODECS_ERROR_ALLOC ; stops the processing */
    }
    /* No else: skipped by an error */
    
    if(localError == ARCODECS_OK)
    {
        av_init_packet(&ffmpegDecoder->avpkt);
    }
    /* No else: skipped by an error */
    
    /* return error*/
    if(error != NULL)
    {
        *error = localError;
    }
    /* No else: the error is not returned */
    
    return ffmpegDecoder;
}

void ARCODECS_Manager_DeleteFFMPEGDecoder (ARCODECS_Manager_FFMPEGDecoder_t **ffmpegDecoder)
{
    /* -- Delete the FFMPEG decoder -- */
    
    if(ffmpegDecoder != NULL)
    {
        if ((*ffmpegDecoder) != NULL)
        {
            if((*ffmpegDecoder)->decodedFrame != NULL)
            {
                avcodec_free_frame (&((*ffmpegDecoder)->decodedFrame));
            }
            /* No else: No decodedFrame to free */
            
            if((*ffmpegDecoder)->codecCtx != NULL)
            {
                avcodec_close((*ffmpegDecoder)->codecCtx);
                av_free((*ffmpegDecoder)->codecCtx);
                (*ffmpegDecoder)->codecCtx = NULL;
            }
            /* No else: No codecCtx to free */
            
            (*ffmpegDecoder)->codec = NULL;
            
            if((*ffmpegDecoder)->outputData != NULL)
            {
                free((*ffmpegDecoder)->outputData);
                (*ffmpegDecoder)->outputData = NULL;
            }
            /* No else: No outputData to free */
            
            (*ffmpegDecoder)->outputDataSize = 0;
            
            free((*ffmpegDecoder));
            (*ffmpegDecoder) = NULL;
        }
        /* No else: check parameters ; stops the processing */
    }
    /* No else: check parameters ; stops the processing */
}

eARCODECS_ERROR ARCODECS_Manager_FFMPEGDecode (ARCODECS_Manager_FFMPEGDecoder_t *ffmpegDecoder, uint8_t *data , int size, ARCODECS_Manager_Frame_t *outputFrame)
{
    /* -- Decode one frame with FFMPEG -- */
    int frameFinished = 0;
    int len = 0;
    eARCODECS_ERROR error = ARCODECS_OK;
    
    /* Check parameters */
    if ((ffmpegDecoder == NULL) || (outputFrame == NULL))
    {
        error = ARCODECS_ERROR_BAD_PARAMETER;
    }
    /* No else ; check parameters (setting error to ARCODECS_ERROR_BAD_PARAMETER, stops the processing) */
    if (error == ARCODECS_OK)
    {
        /* set the frame to decode */
        ffmpegDecoder->avpkt.data = data;
        ffmpegDecoder->avpkt.size = size;
        
        /* reinitialization of the decodedFrame */
        //av_frame_unref (ffmpegDecoder->decodedFrame);
        /* while there are some data to decoding */
        while (ffmpegDecoder->avpkt.size > 0)
        {
            /* decoding */
            len = avcodec_decode_video2 (ffmpegDecoder->codecCtx, ffmpegDecoder->decodedFrame, &frameFinished, &(ffmpegDecoder->avpkt));
            if (len > 0)
            {
                /* if the frame is finished*/
                if (frameFinished)
                {
                    if (error == ARCODECS_OK)
                    {
                        /* set the outputFrame */
                        outputFrame->format = ARCODECS_FORMAT_YUV;
                        
                        outputFrame->width = ffmpegDecoder->decodedFrame->width;
                        outputFrame->height = ffmpegDecoder->decodedFrame->height;
                        
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].data = ffmpegDecoder->decodedFrame->data[0];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].lineSize = ffmpegDecoder->decodedFrame->linesize[0];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].size = (ffmpegDecoder->decodedFrame->linesize[0] * ffmpegDecoder->decodedFrame->height);
                        
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].data = ffmpegDecoder->decodedFrame->data[1];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].lineSize = ffmpegDecoder->decodedFrame->linesize[1];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].size = (ffmpegDecoder->decodedFrame->linesize[1] * (ffmpegDecoder->decodedFrame->height / 2));
                        
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].data = ffmpegDecoder->decodedFrame->data[2];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].lineSize = ffmpegDecoder->decodedFrame->linesize[2];
                        outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].size = (ffmpegDecoder->decodedFrame->linesize[2] * (ffmpegDecoder->decodedFrame->height / 2));
                    }
                    else
                    {
                        ARSAL_PRINT (ARSAL_PRINT_ERROR, ARCODECS_MANAGER_TAG, "the building of output data failed: %i", error);
                    }
                    
                }
                /* No else */
                
                /* progress the data of the size of the data decoded */
                if (ffmpegDecoder->avpkt.data)
                {
                    ffmpegDecoder->avpkt.size -= len;
                    ffmpegDecoder->avpkt.data += len;
                }
                /* No else: */
                
                /*free(data);
                data = NULL;*/
            }
            else
            {
                error = ARCODECS_ERROR_MANAGER_DECODING;
                
                /* break the while loop */
                ffmpegDecoder->avpkt.size  = 0;
                
                /* reset the outputFrame */
                outputFrame->format = ARCODECS_FORMAT_YUV;
                
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].data = NULL;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].lineSize = 0;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_Y].size = 0;
                
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].data = NULL;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].lineSize = 0;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_U].size = 0;
                
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].data = NULL;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].lineSize = 0;
                outputFrame->componentArray[ARCODECS_FORMAT_YUV_COMPONENT_V].size = 0;
            }
        }
    }
    /* No else: skipped by an error */
    
    return error;
}
