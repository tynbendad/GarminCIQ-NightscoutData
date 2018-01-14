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

using Toybox.Background;
using Toybox.Communications;
using Toybox.System as Sys;

// The Service Delegate is the main entry point for background processes
// our onTemporalEvent() method will get run each time our periodic event
// is triggered by the system.

(:background)
class BgbgServiceDelegate extends Toybox.System.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}
	
	function myPrintLn(x) {
		System.println(x);
	}
	
	function onReceive(responseCode, data) {
		myPrintLn("in onReceive()");
		//myPrintLn("response: " + responseCode.toString());
		var bgdata = {};
		if ((responseCode == 200) &&
			(data != null) &&
			!data.isEmpty()) {
				var elapsedMills, bg, direction, delta, rawbg;
	        	elapsedMills = 0;
            	bg = 0;
            	direction = "";
	            delta = "";
	            rawbg = "";

				if (data.hasKey("bgnow")) {
					if (data["bgnow"].hasKey("mills")) {
				        myPrintLn(data["bgnow"]["mills"].toString());
				        elapsedMills = data["bgnow"]["mills"];
			        }
					if (data["bgnow"].hasKey("last")) {
			            myPrintLn(data["bgnow"]["last"].toString());
			            bg = data["bgnow"]["last"];
		            }
					// bg = mmol_or_mgdl(bg);
		            if (data["bgnow"].hasKey("sgvs") &&
		            	(data["bgnow"]["sgvs"].size() > 0) &&
		            	data["bgnow"]["sgvs"][0].hasKey("direction")) {
				        myPrintLn(data["bgnow"]["sgvs"][0]["direction"].toString());
				        direction = data["bgnow"]["sgvs"][0]["direction"].toString();
						var dirSwitch = { "SingleUp" => "Up",
									 	  "DoubleUp" => "Up^2",
									 	  "FortyFiveUp" => "Up/",
									 	  "FortyFiveDown" => "Down\\",
									 	  "SingleDown" => "Down",
									 	  "DoubleDown" => "Down^2",
									 	  "Flat" => "Flat",
									 	  "NONE" => "NONE" };
			        	if (dirSwitch.hasKey(direction)) {
			        		direction = dirSwitch[direction];
			        		myPrintLn(direction);
		        		}
			        }
		        }
				if (data.hasKey("delta") &&
					data["delta"].hasKey("display")) {
		            myPrintLn(data["delta"]["display"].toString());
		            delta = data["delta"]["display"].toString();
	            }

				if (data.hasKey("rawbg") &&
					data["rawbg"].hasKey("mgdl") &&
					data["rawbg"].hasKey("noiseLabel")) {
		            rawbg = "raw:" + data["rawbg"]["mgdl"].toString() + " " + data["rawbg"]["noiseLabel"];
		            myPrintLn(rawbg);
	            }
		        bgdata["str"]=bg.toString() + " " + direction + " " + delta + " " + rawbg;
		        bgdata["elapsedMills"] = elapsedMills;
		        bgdata["bg"] = bg;
		        bgdata["direction"] = direction;
		        bgdata["delta"] = delta;
		        bgdata["rawbg"] = rawbg;
		        Sys.println("bgdata.str"+bgdata["str"]);
        }
        Background.exit(bgdata);
	}		        
	
    function onTemporalEvent() {
    	var thisApp = Application.getApp();
		var url = thisApp.getProperty("nsurl");
		url = url + "/api/v2/properties/bgnow,rawbg,delta";
		myPrintLn("fetching url: " + url);
    	Communications.makeWebRequest(url, {"format" => "json"}, {}, method(:onReceive));
    }
    

}
