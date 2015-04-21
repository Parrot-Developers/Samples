//
//  Decoder_Manager.h
//  
//
//  Created by Djavan Bertrand on 14/04/2015.
//
//

#ifndef ____Decoder_Manager__
#define ____Decoder_Manager__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/**
 * @brief Video and audio codecs manager allow to decode video and audio.
 */
typedef struct ARCODECS_Manager_t ARCODECS_Manager_t;

/**
 * @brief libARCodecs errors known.
 */
typedef enum
{
    ARCODECS_OK = 0,                            /**< No error */
    
    ARCODECS_ERROR = -1000,                     /**< Unknown generic error */
    ARCODECS_ERROR_ALLOC,                       /**< Memory allocation error */
    ARCODECS_ERROR_BAD_PARAMETER,               /**< Bad parameters */
    
    
    ARCODECS_ERROR_MANAGER = -2000,             /**< Unknown ARCODECS_Manager error */
    ARCODECS_ERROR_MANAGER_UNKNOWN_TYPE,        /**< Unknown Codec type */
    ARCODECS_ERROR_MANAGER_UNSUPPORTED_CODEC,   /**< Unsupported Codec type */
    ARCODECS_ERROR_MANAGER_DECODING,            /**< Decoding error */
    ARCODECS_ERROR_MANAGER_CODEC_OPENING,       /**< Opening error of the codec */
} eARCODECS_ERROR;


typedef enum
{
    ARCODECS_FORMAT_YUV = 0,
    ARCODECS_FORMAT_RGBA,
} eARCODECS_FORMAT;

/**
 * @brief Component of a frame.
 */
typedef struct _ARCODECS_Manager_Component_t_
{
    uint8_t *data; /**< data buffer*/
    uint32_t lineSize; /**< size of each line of the component */
    uint32_t size; /**< size of the buffer */
} ARCODECS_Manager_Component_t;

/**
 * @brief Video and audio codecs manager allow to decode video and audio.
 */
typedef struct _ARCODECS_Manager_Frame_t_
{
    eARCODECS_FORMAT format;
    uint32_t width;
    uint32_t height;
    uint32_t numberOfComponent;
    ARCODECS_Manager_Component_t *componentArray;
} ARCODECS_Manager_Frame_t;

/**
 * @brief callback use when to get next data
 * @param[in] data pointer on the data
 * @param[in] customData custom data sent to the callback
 * @return number of bytes in buffer dataPtr
 */
typedef int (*ARCODECS_Manager_GetNextDataCallback_t)(uint8_t **data, void *customData);

/**
 * @brief Create a new Manager
 * @warning This function allocate memory
 * @post ARCODECS_Manager_Delete() must be called to delete the codecs manager and free the memory allocated.
 * @param[in] callback callback use when to get next data.
 * @param[in] callbackCustomData custom data sent to the callback.
 * @param[out] error pointer on the error output.
 * @return Pointer on the new Manager
 * @see ARCODECS_Manager_Delete()
 */
ARCODECS_Manager_t* ARCODECS_Manager_New (ARCODECS_Manager_GetNextDataCallback_t callback, void *callbackCustomData, eARCODECS_ERROR *error);

/**
 * @brief decode one frame
 * @warning This function decode video or audio
 * @param[in] Pointer on the new Manager
 * @param[in] Pointer on the error
 * @return Output frame decoded - NULL if decoding error occured with update of error
 */
ARCODECS_Manager_Frame_t* ARCODECS_Manager_Decode (ARCODECS_Manager_t *manager, eARCODECS_ERROR *error);

/**
 * @brief Delete the Manager
 * @warning This function free memory
 * @param manager address of the pointer on the Manager
 * @see ARCODECS_Manager_New()
 */
void ARCODECS_Manager_Delete(ARCODECS_Manager_t **manager);



#endif /* defined(____Decoder_Manager__) */
