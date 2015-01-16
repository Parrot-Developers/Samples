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
/**
 * @file JumpingSumoChangePosture.c
 * @brief This file contains sources about basic arsdk example sending commands to a JumpingSumo for change his posture
 * @date 08/01/2015
 */

/*****************************************
 *
 *             include file :
 *
 *****************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <libARSAL/ARSAL.h>
#include <libARSAL/ARSAL_Print.h>
#include <libARNetwork/ARNetwork.h>
#include <libARNetworkAL/ARNetworkAL.h>
#include <libARCommands/ARCommands.h>
#include <libARDiscovery/ARDiscovery.h>

#include "JumpingSumoChangePosture.h"

/*****************************************
 *
 *             define :
 *
 *****************************************/
#define TAG "JumpingSumoChangePosture"
#define JS_IP_ADDRESS "192.168.2.1"
#define JS_DISCOVERY_PORT 44444
#define JS_C2D_PORT 54321 // should be read from Json
#define JS_D2C_PORT 43210

#define JS_NET_CD_NONACK_ID 10
#define JS_NET_CD_ACK_ID 11
#define JS_NET_CD_VIDEO_ACK_ID 13
#define JS_NET_DC_NONACK_ID 127
#define JS_NET_DC_ACK_ID 126


/*****************************************
 *
 *             implementation :
 *
 *****************************************/

static ARNETWORK_IOBufferParam_t c2dParams[] = {
    {
        .ID = 10,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 5,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 10,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = 11,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    }
};
static const size_t numC2dParams = sizeof(c2dParams) / sizeof(ARNETWORK_IOBufferParam_t);

static ARNETWORK_IOBufferParam_t d2cParams[] = {
    {
        .ID = ((ARNETWORKAL_MANAGER_WIFI_ID_MAX / 2) - 1),
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 10,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = ((ARNETWORKAL_MANAGER_WIFI_ID_MAX / 2) - 2),
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    }
};
static const size_t numD2cParams = sizeof(d2cParams) / sizeof(ARNETWORK_IOBufferParam_t);

int main (int argc, char *argv[])
{
    /* local declarations */
    int failed = 0;
    JS_MANAGER_t *jsManager = malloc(sizeof(JS_MANAGER_t));

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "-- Jumping Sumo Change Posture --");

    if (jsManager != NULL)
    {
        // initialize jsMnager
        jsManager->alManager = NULL;
        jsManager->netManager = NULL;
        jsManager->rxThread = NULL;
        jsManager->txThread = NULL;
        jsManager->d2cPort = JS_D2C_PORT;
        jsManager->c2dPort = JS_C2D_PORT; //jsManager->c2dPort = 0; // should be read from json
    }
    else
    {
        failed = 1;
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "jsManager alloc error !");
    }

    if (!failed)
    {
        failed = ardiscoveryConnect (jsManager);
    }

    if (!failed)
    {
        /* start */
        failed = startNetwork (jsManager);
    }

    if (!failed)
    {
        int cmdSend = 0;
        
        cmdSend = sendPilotingPosture(jsManager, ARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE_KICKER);

        sleep(2);
        
        cmdSend = sendPilotingPosture(jsManager, ARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE_JUMPER);

        sleep(2);
    }

    if (jsManager != NULL)
    {
        /* stop */
        stopNetwork (jsManager);
        
        /* free jsManager */
        free (jsManager);
        jsManager = NULL;
    }

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "-- END --");

    return 0;
}

int ardiscoveryConnect (JS_MANAGER_t *jsManager)
{
    int failed = 0;

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- ARDiscovery Connection");

    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;
    ARDISCOVERY_Connection_ConnectionData_t *discoveryData = ARDISCOVERY_Connection_New (ARDISCOVERY_Connection_SendJsonCallback, ARDISCOVERY_Connection_ReceiveJsonCallback, jsManager, &err);
    if (discoveryData == NULL || err != ARDISCOVERY_OK)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Error while creating discoveryData : %s", ARDISCOVERY_Error_ToString(err));
        failed = 1;
    }

    if (!failed)
    {
        eARDISCOVERY_ERROR err = ARDISCOVERY_Connection_ControllerConnection(discoveryData, JS_DISCOVERY_PORT, JS_IP_ADDRESS);
        if (err != ARDISCOVERY_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Error while opening discovery connection : %s", ARDISCOVERY_Error_ToString(err));
            failed = 1;
        }
    }

    ARDISCOVERY_Connection_Delete(&discoveryData);

    return failed;
}

int startNetwork (JS_MANAGER_t *jsManager)
{
    int failed = 0;
    eARNETWORK_ERROR netError = ARNETWORK_OK;
    eARNETWORKAL_ERROR netAlError = ARNETWORKAL_OK;
    int pingDelay = 0; // 0 means default, -1 means no ping

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- Start ARNetwork");

    // Create the ARNetworkALManager
    jsManager->alManager = ARNETWORKAL_Manager_New(&netAlError);
    if (netAlError != ARNETWORKAL_OK)
    {
        failed = 1;
    }

    if (!failed)
    {
        // Initilize the ARNetworkALManager
        netAlError = ARNETWORKAL_Manager_InitWifiNetwork(jsManager->alManager, JS_IP_ADDRESS, JS_C2D_PORT, JS_D2C_PORT, 1);
        if (netAlError != ARNETWORKAL_OK)
        {
            failed = 1;
        }
    }

    if (!failed)
    {
        // Create the ARNetworkManager.
        jsManager->netManager = ARNETWORK_Manager_New(jsManager->alManager, numC2dParams, c2dParams, numD2cParams, d2cParams, pingDelay, onDisconnectNetwork, jsManager, &netError);
        if (netError != ARNETWORK_OK)
        {
            failed = 1;
        }
    }

    if (!failed)
    {
        // Create and start Tx and Rx threads.
        if (ARSAL_Thread_Create(&(jsManager->rxThread), ARNETWORK_Manager_ReceivingThreadRun, jsManager->netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Rx thread failed.");
            failed = 1;
        }

        if (ARSAL_Thread_Create(&(jsManager->txThread), ARNETWORK_Manager_SendingThreadRun, jsManager->netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Tx thread failed.");
            failed = 1;
        }
    }

    // Print net error
    if (failed)
    {
        if (netAlError != ARNETWORKAL_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNetWorkAL Error : %s", ARNETWORKAL_Error_ToString(netAlError));
        }

        if (netError != ARNETWORK_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNetWork Error : %s", ARNETWORK_Error_ToString(netError));
        }
    }

    return failed;
}

void stopNetwork (JS_MANAGER_t *jsManager)
{
    int failed = 0;
    eARNETWORK_ERROR netError = ARNETWORK_OK;
    eARNETWORKAL_ERROR netAlError = ARNETWORKAL_OK;
    int pingDelay = 0; // 0 means default, -1 means no ping

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- Stop ARNetwork");

    // ARNetwork cleanup
    if (jsManager->netManager != NULL)
    {
        ARNETWORK_Manager_Stop(jsManager->netManager);
        if (jsManager->rxThread != NULL)
        {
            ARSAL_Thread_Join(jsManager->rxThread, NULL);
            ARSAL_Thread_Destroy(&(jsManager->rxThread));
            jsManager->rxThread = NULL;
        }

        if (jsManager->txThread != NULL)
        {
            ARSAL_Thread_Join(jsManager->txThread, NULL);
            ARSAL_Thread_Destroy(&(jsManager->txThread));
            jsManager->txThread = NULL;
        }
    }

    if (jsManager->alManager != NULL)
    {
        ARNETWORKAL_Manager_Unlock(jsManager->alManager);

        ARNETWORKAL_Manager_CloseWifiNetwork(jsManager->alManager);
    }

    ARNETWORK_Manager_Delete(&(jsManager->netManager));
    ARNETWORKAL_Manager_Delete(&(jsManager->alManager));
}

void onDisconnectNetwork (ARNETWORK_Manager_t *manager, ARNETWORKAL_Manager_t *alManager, void *customData)
{
    ARSAL_PRINT(ARSAL_PRINT_DEBUG, TAG, "onDisconnectNetwork ...");
}

int sendPilotingPosture(JS_MANAGER_t *jsManager, eARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE type)
{
    int sentStatus = 1;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;

    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- Send Piloting Posture %d", type);

    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateJumpingSumoPilotingPosture(cmdBuffer, sizeof(cmdBuffer), &cmdSize, type);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        netError = ARNETWORK_Manager_SendData(jsManager->netManager, JS_NET_CD_ACK_ID, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }

    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        ARSAL_PRINT(ARSAL_PRINT_WARNING, TAG, "Failed to send Posture command. cmdError:%d netError:%s", cmdError, ARNETWORK_Error_ToString(netError));
        sentStatus = 0;
    }

    return sentStatus;
}

eARNETWORK_MANAGER_CALLBACK_RETURN arnetworkCmdCallback(int buffer_id, uint8_t *data, void *custom, eARNETWORK_MANAGER_CALLBACK_STATUS cause)
{
    eARNETWORK_MANAGER_CALLBACK_RETURN retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DEFAULT;

    ARSAL_PRINT(ARSAL_PRINT_DEBUG, TAG, "    - arnetworkCmdCallback %d, cause:%d ", buffer_id, cause);

    if (cause == ARNETWORK_MANAGER_CALLBACK_STATUS_TIMEOUT)
    {
        retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP;
    }

    return retval;
}

eARDISCOVERY_ERROR ARDISCOVERY_Connection_SendJsonCallback (uint8_t *dataTx, uint32_t *dataTxSize, void *customData)
{
    JS_MANAGER_t *jsManager = (JS_MANAGER_t *)customData;
    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;

    if ((dataTx != NULL) && (dataTxSize != NULL) && (jsManager != NULL))
    {
        *dataTxSize = sprintf((char *)dataTx, "{ \"%s\": %d,\n \"%s\": \"%s\",\n \"%s\": \"%s\" }",
                              ARDISCOVERY_CONNECTION_JSON_D2CPORT_KEY, jsManager->d2cPort,
                              ARDISCOVERY_CONNECTION_JSON_CONTROLLER_NAME_KEY, "name",
                              ARDISCOVERY_CONNECTION_JSON_CONTROLLER_TYPE_KEY, "type") + 1;
    }
    else
    {
        err = ARDISCOVERY_ERROR;
    }

    return err;
}

eARDISCOVERY_ERROR ARDISCOVERY_Connection_ReceiveJsonCallback (uint8_t *dataRx, uint32_t dataRxSize, char *ip, void *customData)
{
    JS_MANAGER_t *jsManager = (JS_MANAGER_t *)customData;
    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;

    if ((dataRx != NULL) && (dataRxSize != 0) && (jsManager != NULL))
    {
        char *json = malloc(dataRxSize + 1);
        strncpy(json, (char *)dataRx, dataRxSize);
        json[dataRxSize] = '\0';

        ARSAL_PRINT(ARSAL_PRINT_DEBUG, TAG, "    - ReceiveJson:%s ", json);
        
        //normally c2dPort should be read from the json here.

        free(json);
    }
    else
    {
        err = ARDISCOVERY_ERROR;
    }

    return err;
}
