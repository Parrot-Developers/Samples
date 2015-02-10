package com.parrot.rollingspiderpiloting;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;
import android.support.v7.app.ActionBarActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceBLEService;
import com.parrot.arsdk.ardiscovery.ARDiscoveryDeviceService;
import com.parrot.arsdk.ardiscovery.ARDiscoveryService;
import com.parrot.arsdk.ardiscovery.receivers.ARDiscoveryServicesDevicesListUpdatedReceiver;
import com.parrot.arsdk.ardiscovery.receivers.ARDiscoveryServicesDevicesListUpdatedReceiverDelegate;
import com.parrot.arsdk.arsal.ARSALPrint;

import java.util.ArrayList;
import java.util.List;


public class MainActivity extends ActionBarActivity implements ARDiscoveryServicesDevicesListUpdatedReceiverDelegate
{
    private static String TAG = MainActivity.class.getSimpleName();

    static
    {
        try
        {
            System.loadLibrary("arsal");
            System.loadLibrary("arsal_android");
            System.loadLibrary("arnetworkal");
            System.loadLibrary("arnetworkal_android");
            System.loadLibrary("arnetwork");
            System.loadLibrary("arnetwork_android");
            System.loadLibrary("arcommands");
            System.loadLibrary("arcommands_android");
            System.loadLibrary("ardiscovery");
            System.loadLibrary("ardiscovery_android");

            ARSALPrint.enableDebugPrints();

        }
        catch (Exception e)
        {
            Log.e(TAG, "Oops (LoadLibrary)", e);
        }
    }

    private ListView listView ;
    private List<ARDiscoveryDeviceService> deviceList;
    private String[] deviceNameList;

    private ARDiscoveryService ardiscoveryService;
    private boolean ardiscoveryServiceBound = false;
    private ServiceConnection ardiscoveryServiceConnection;
    public IBinder discoveryServiceBinder;

    private BroadcastReceiver ardiscoveryServicesDevicesListUpdatedReceiver;

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        startServices();
        initBroadcastReceiver();
        initServiceConnection();

        listView = (ListView) findViewById(R.id.list);

        deviceList = new ArrayList<ARDiscoveryDeviceService>();
        deviceNameList = new String[]{};

        ArrayAdapter<String> adapter = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, android.R.id.text1, deviceNameList);


        // Assign adapter to ListView
        listView.setAdapter(adapter);

        // ListView Item Click Listener
        listView.setOnItemClickListener(new AdapterView.OnItemClickListener()
        {

            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id)
            {

                // ListView Clicked item index
                int itemPosition = position;

                // ListView Clicked item value
                String  itemValue = (String) listView.getItemAtPosition(position);

                ARDiscoveryDeviceService service = deviceList.get(position);

                Intent intent = new Intent(MainActivity.this, PilotingActivity.class);
                intent.putExtra(PilotingActivity.EXTRA_DEVICE_SERVICE, service);


                startActivity(intent);
            }

        });
    }

    private void startServices()
    {
        //startService(new Intent(this, ARDiscoveryService.class));
    }

    private void initServices()
    {
        if (discoveryServiceBinder == null)
        {
            Intent i = new Intent(getApplicationContext(), ARDiscoveryService.class);
            getApplicationContext().bindService(i, ardiscoveryServiceConnection, Context.BIND_AUTO_CREATE);
        }
        else
        {
            ardiscoveryService = ((ARDiscoveryService.LocalBinder) discoveryServiceBinder).getService();
            ardiscoveryServiceBound = true;

            ardiscoveryService.start();
        }
    }

    private void closeServices()
    {
        Log.d(TAG, "closeServices ...");

        if (ardiscoveryServiceBound)
        {
            new Thread(new Runnable() {
                @Override
                public void run()
                {
                    ardiscoveryService.stop();

                    getApplicationContext().unbindService(ardiscoveryServiceConnection);
                    ardiscoveryServiceBound = false;
                    discoveryServiceBinder = null;
                    ardiscoveryService = null;
                }
            }).start();


        }
    }

    private void initBroadcastReceiver()
    {
        ardiscoveryServicesDevicesListUpdatedReceiver = new ARDiscoveryServicesDevicesListUpdatedReceiver(this);
    }

    private void initServiceConnection()
    {
        ardiscoveryServiceConnection = new ServiceConnection()
        {
            @Override
            public void onServiceConnected(ComponentName name, IBinder service)
            {
                discoveryServiceBinder = service;
                ardiscoveryService = ((ARDiscoveryService.LocalBinder) service).getService();
                ardiscoveryServiceBound = true;

                ardiscoveryService.start();
            }

            @Override
            public void onServiceDisconnected(ComponentName name)
            {
                ardiscoveryService = null;
                ardiscoveryServiceBound = false;
            }
        };
    }

    private void registerReceivers()
    {
        LocalBroadcastManager localBroadcastMgr = LocalBroadcastManager.getInstance(getApplicationContext());
        localBroadcastMgr.registerReceiver(ardiscoveryServicesDevicesListUpdatedReceiver, new IntentFilter(ARDiscoveryService.kARDiscoveryServiceNotificationServicesDevicesListUpdated));

    }

    private void unregisterReceivers()
    {
        LocalBroadcastManager localBroadcastMgr = LocalBroadcastManager.getInstance(getApplicationContext());
        localBroadcastMgr.unregisterReceiver(ardiscoveryServicesDevicesListUpdatedReceiver);
    }


    @Override
    public void onResume()
    {
        super.onResume();

        Log.d(TAG, "onResume ...");

        onServicesDevicesListUpdated();

        registerReceivers();

        initServices();

    }

    @Override
    public void onPause()
    {
        Log.d(TAG, "onPause ...");

        unregisterReceivers();
        closeServices();

        super.onPause();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu)
    {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item)
    {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings)
        {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onServicesDevicesListUpdated()
    {
        Log.d(TAG, "onServicesDevicesListUpdated ...");

        List<ARDiscoveryDeviceService> list;

        if (ardiscoveryService != null)
        {
            list = ardiscoveryService.getDeviceServicesArray();

            deviceList = new ArrayList<ARDiscoveryDeviceService> ();
            List<String> deviceNames = new ArrayList<String>();

            if(list != null)
            {
                for (ARDiscoveryDeviceService service : list)
                {
                    Log.d(TAG, "service :  "+ service);
                    if (service.getDevice() instanceof ARDiscoveryDeviceBLEService)
                    {
                        deviceList.add(service);
                        deviceNames.add(service.getName());
                    }
                }
            }

            deviceNameList = deviceNames.toArray(new String[deviceNames.size()]);

            ArrayAdapter<String> adapter = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, android.R.id.text1, deviceNameList);

            // Assign adapter to ListView
            listView.setAdapter(adapter);
        }

    }
}
