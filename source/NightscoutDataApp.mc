/*
 * NightscoutData Garmin Connect IQ data field application
 * Copyright (C) 2017 tynbendad@gmail.com
 * #WeAreNotWaiting
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3 of the License.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   A copy of the GNU General Public License is available at
 *   https://www.gnu.org/licenses/gpl-3.0.txt
 */

using Toybox.Application as App;
using Toybox.Background;
using Toybox.Time;
using Toybox.System as Sys;

// info about whats happening with the background process
var canDoBG=false;
var setupReqd=false;

// cgm sync state
var cgmSynced=true;
var elapsedMinutesMin=0;
var syncCounter=0;
var syncMinTime;
var SYNC_MINUTES=6;
var SYNC_EVENTS=4;

// background data, shared directly with appview
var bgdata;

// keys to the object store data
var OSMINUTESMIN="osminutesmin";
var OSDATA="osdata";

(:background)
class NightscoutDataApp extends App.AppBase {
	var myView;

    function initialize() {
        AppBase.initialize();
        Sys.println("App initialize");
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

	function myPrintLn(x) {
		System.println(x);
	}

    function onSettingsChanged() {
    	myPrintLn("in onSettingsChanged");
    	var thisApp = Application.getApp();
		var nsurl = thisApp.getProperty("nsurl");

		if ((nsurl != null) &&
		    !nsurl.equals("") &&
			Sys.getDeviceSettings().phoneConnected) {
	        Sys.println("onSettingsChanged: set 5 minute event - nsurl=" + nsurl + " elapsedMinutesMin=" + elapsedMinutesMin);
    		Background.registerForTemporalEvent(new Time.Duration(5 * 60));
		} else {
	        Sys.println("onSettingsChanged: invalid nsurl, not starting background process");
	        setupReqd=true;
		}

        //Ui.requestUpdate();
    	myPrintLn("out onSettingsChanged");
    }

    // Return the initial view of your application here
    function getInitialView() {
		//register for temporal events if they are supported
    	if(Toybox.System has :ServiceDelegate) {
    		canDoBG=true;
    		Background.deleteTemporalEvent();
	    	var thisApp = Application.getApp();
	        var temp = thisApp.getProperty(OSMINUTESMIN);
	        if (temp!=null && temp instanceof Number) {elapsedMinutesMin=temp;}
    		onSettingsChanged();
    	} else {
    		Sys.println("****background not available on this device****");
    	}
    	myView = new NightscoutDataView();
        return [ myView ];
    }


    function onBackgroundData(data) {
    	var now=Sys.getClockTime();
    	var ts=now.hour+":"+now.min.format("%02d");
        Sys.println("onBackgroundData="+data+" at "+ts);
		if ((data != null) &&
			data.hasKey("elapsedMills") &&
			(data["elapsedMills"] > 0)) {
	        Sys.println("onBackgroundData: check sync");
	        setupReqd=false;

			var elapsedMills = data["elapsedMills"];
	        var myMoment = new Time.Moment(elapsedMills / 1000);
			var elapsedMinutes = Math.floor(Time.now().subtract(myMoment).value() / 60);
	        Sys.println("onBackgroundData: elapsedMinutes="+elapsedMinutes);

			// unfortunately complicated state machine to find the best time to wake up for new cgm data:
	        if (cgmSynced && (elapsedMinutes <= elapsedMinutesMin)) {
		        Sys.println("onBackgroundData: synced, elapsedMinutesMin=" + elapsedMinutesMin);
	    		Background.registerForTemporalEvent(new Time.Duration(5 * 60));
	    		syncCounter = SYNC_EVENTS;
			} else {
				if (cgmSynced) {
					--syncCounter;
					if (syncCounter <= 0) {
						// enter sync state
				        Sys.println("onBackgroundData: set 6 minute event - begin syncing to CGM data creation time");
			    		Background.registerForTemporalEvent(new Time.Duration(SYNC_MINUTES * 60));
			        	cgmSynced = false;
			        	syncCounter = 1;
						elapsedMinutesMin = elapsedMinutes;
						syncMinTime = Time.now();
					} else {
				        Sys.println("onBackgroundData: semi-synced, elapsedMinutesMin=" + elapsedMinutesMin + ", syncCounter=" + syncCounter);
			    		Background.registerForTemporalEvent(new Time.Duration(5 * 60));
					}
		        } else if (syncCounter < SYNC_EVENTS) {
					if (elapsedMinutes < elapsedMinutesMin) {
						elapsedMinutesMin = elapsedMinutes;
						syncMinTime = Time.now();
					}
			        Sys.println("onBackgroundData: syncing, elapsedMinutesMin=" + elapsedMinutesMin + ", syncCounter=" + syncCounter);
					syncCounter++;
		        } else {
					var minutesSinceMin = Math.round(Time.now().subtract(syncMinTime).value() / 60);
					var syncMinutes = 5 + ((5 - (minutesSinceMin % 5)) % 5);
			        Sys.println("onBackgroundData: set " + syncMinutes + " minute event - sync complete, elapsedMinutesMin=" + elapsedMinutesMin + ", minutesSinceMin=" + minutesSinceMin);
		    		Background.registerForTemporalEvent(new Time.Duration(syncMinutes * 60));
		    		cgmSynced = true;
		    		if (elapsedMinutesMin > 3) {
		    			elapsedMinutesMin = 3;	// re-sync again if minimum found is greater than 3 minutes
	    			}
			    	App.getApp().setProperty(OSMINUTESMIN, elapsedMinutesMin);
		        }
			}

	        Sys.println("onBackgroundData update property");
	        App.getApp().setProperty(OSDATA,data);
	        bgdata = data;
	        //Ui.requestUpdate();
		}
    }    

    function getServiceDelegate(){
    	var now=Sys.getClockTime();
    	var ts=now.hour+":"+now.min.format("%02d");    
    	Sys.println("getServiceDelegate: "+ts);
        return [new BgbgServiceDelegate()];
    }

}