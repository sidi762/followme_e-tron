################################
#|  ___/ ___|  _ \|  _ \ / ___|#
#| |_ | |  _| |_) | |_) | |	   #
#|  _|| |_| |  __/|  _ <| |___ #
#|_|   \____|_|   |_| \_\\____|#
################################

#Initialize the properties here
var AltnHaveSaved2Datalink = 0;
var cduInitialize = func(){
	props.getNode("/",1).setValue("/instrumentation/cdu/display", "IDENT");
	props.getNode("/",1).setValue("/instrumentation/cdu/LATorBRG",0);
	props.getNode("/",1).setValue("/instrumentation/cdu/isARMED",0);
	props.getNode("/",1).setValue("/autopilot/route-manager/cruise/altitude-ft",0);
	props.getNode("/",1).setValue("/instrumentation/cdu/sids/rwyIsSelected", 0);
	props.getNode("/",1).setValue("/instrumentation/cdu/sids/sidIsSelected", 0);
	props.getNode("/",1).setValue("/instrumentation/cdu/appr/apprIsSelected", 0);
	props.getNode("/",1).setValue("/instrumentation/cdu/appr/apprCountEnd", 0);
	props.getNode("/",1).setValue("/instrumentation/cdu/appr/apprCountEndPage", 0);
	props.getNode("/",1).setValue("/instrumentation/cdu/appr/rwyCountLastPage", 1000);
	props.getNode("/",1).setValue("/instrumentation/cdu/StepSize","RVSM");
	props.getNode("/",1).setValue("/instrumentation/fmc/THRLIM","TOGA");
	props.getNode("/",1).setValue("/instrumentation/fmc/CLB_LIM","CLB");
	props.getNode("/",1).setValue("/instrumentation/fmc/isCustomizeFlaps",0);
	props.getNode("/",1).setValue("/instrumentation/fmc/isInputedPos",0);
	props.getNode("/",1).setValue("/autopilot/route-manager/isArmed",-1);
	props.getNode("/",1).setValue("/autopilot/route-manager/isChanged",1);
	props.getNode("/",1).setValue("/instrumentation/fmc/EoAccelHT",1000);
	props.getNode("/",1).setValue("/instrumentation/fmc/AccelHT",1000);
	props.getNode("/",1).setValue("/instrumentation/fmc/Reduction",1000);
	props.getNode("/",1).setValue("/instrumentation/fmc/ref-temperature-degc",-999);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/XTransSPD",250);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/XTransALT",10000);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/RestrSPD",240);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/RestrALT",8000);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/TransALT",18000);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/isChanged",1);
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/cruise/altitude-FL","");
	props.getNode("/",1).setValue("/instrumentation/fmc/VNAV/cruise/altitude-ft",0);
	props.getNode("/",1).setValue("/instrumentation/fmc/isMsg",0);
	props.getNode("/",1).setValue("/instrumentation/fmc/OrgInput","");
	props.getNode("/",1).setValue("/instrumentation/fmc/gate-pos-lat-str","");
	props.getNode("/",1).setValue("/instrumentation/fmc/gate-pos-lon-str","");
	props.getNode("/",1).setValue("/instrumentation/fmc/gate-pos-lat-noformat","");
	props.getNode("/",1).setValue("/instrumentation/fmc/gate-pos-lon-noformat","");
	props.getNode("/",1).setValue("/instrumentation/fmc/sltd-ALTN",1);
	props.getNode("/",1).setValue("/instrumentation/fmc/outputUIContent","");
	props.getNode("/",1).setValue("/instrumentation/fmc/lastOutputUITime",0);
	props.getNode("/",1).setValue("/autopilot/route-manager/route/crtPageNum",1);
	AltnHaveSaved2Datalink = 0
}
cduInitialize();
#Initialize aera end

#print("Thanks for using FlightGear 777 CDU Improvement project by FlightGear China!");
#print(" _____ ____ ____  ____   ____ ");
#print("|  ___/ ___ |  _ \|  _ \  / ___|");
#print("|  |_  | |  _| |_)   | |_) | |    ");
#print("|  _|  | |_|   | __/|  _ < | |___ ");
#print("|_|     \___ |_|   |_| \_\ \____|");
#print("Enjoy your flight and happy landings!");

var input = func(v) {
		setprop("/instrumentation/cdu/input",getprop("/instrumentation/cdu/input")~v);
}

var isFLinit = func(){
	if (getprop("/instrumentation/fmc/VNAV/cruise/altitude-FL") != nil)
		return getprop("/instrumentation/fmc/VNAV/cruise/altitude-FL");
	else
		return "";
}

var armChanges = func(){
	if (getprop("/autopilot/route-manager/departure/newsid") != nil){
		setprop("/autopilot/route-manager/departure/sid", getprop("/autopilot/route-manager/departure/newsid"));
	}

	if (getprop("/autopilot/route-manager/departure/newrunway") != nil){
		setprop("/autopilot/route-manager/departure/runway", getprop("/autopilot/route-manager/departure/newrunway"));
	}
	setprop("/autopilot/route-manager/isArmed",1);
}

var VNAVChanges = func(){
	setprop("/instrumentation/fmc/VNAV/isChanged",0);
	setprop("/autopilot/route-manager/isArmed",1);
}

var del = func(){
	var isMsg = getprop("/instrumentation/fmc/isMsg");
	if(isMsg == 1)
	{
		setprop("/instrumentation/cdu/input","");
	}
	else
	{
		setprop("/instrumentation/cdu/input",left(getprop("/instrumentation/cdu/input"),size(getprop("/instrumentation/cdu/input"))-1));
	}
	isMsg = 0;
	setprop("/instrumentation/fmc/isMsg",isMsg);
}

var plusminus = func {
	var end = size(getprop("/instrumentation/cdu/input"));
	var start = end - 1;
	var lastchar = substr(getprop("/instrumentation/cdu/input"),start,end);
	if (lastchar == "+"){
		me.delete();
		me.input('-');
		}
	if (lastchar == "-"){
		me.delete();
		me.input('+');
		}
	if ((lastchar != "-") and (lastchar != "+")){
		me.input('+');
		}
}
var window = screen.window.new(10, 10, 3, 10);

var outputUI = func(content, timeout = 10){
	window.autoscroll = timeout;
	timeNow = systime();
	if(content != getprop("/instrumentation/fmc/outputUIContent") or (timeNow - timeout) >= getprop("/instrumentation/fmc/lastOutputUITime")){
		window.write(content);
		setprop("/instrumentation/fmc/outputUIContent",content);
		setprop("/instrumentation/fmc/lastOutputUITime",systime());
		#print("Outputed");
	}
}

var i = 0;

var key = func(v) {
		var cduDisplay   = getprop("/instrumentation/cdu/display");
		var serviceable  = getprop("/instrumentation/cdu/serviceable");
		var eicasDisplay = getprop("/instrumentation/eicas/display");
		var cduInput     = getprop("/instrumentation/cdu/input");
		var msg          = getprop("/instrumentation/fmc/isMsg");

		datalink.allAircrafts[0].requestState = "<REQUEST";

		if (serviceable == 1){
			if (v == "LSK1L"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line1/left") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newsid", getprop("/instrumentation/cdu/output/line1/left"));
						setprop("/instrumentation/cdu/sids/sidIsSelected", 1);
						setprop("/autopilot/route-manager/departure/newrunway", getRwyOfSids(getprop("/instrumentation/cdu/output/line1/left")));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						setprop("/autopilot/route-manager/departure/sidID", getprop("/instrumentation/cdu/output/line1/left"));
					}
				}#end of RTE1_DEP
				if (cduDisplay == "DEP_ARR_INDEX"){
					cduDisplay = "RTE1_DEP";
					setprop("/instrumentation/cdu/sids/page", 1);
				}#end of DEP_ARR_INDEX
				if (cduDisplay == "EICAS_MODES"){
					eicasDisplay = "ENG";
				}
				if (cduDisplay == "EICAS_SYN"){
					eicasDisplay = "ELEC";
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "IDENT";
					#fmc.getVSpeeds(getprop("/instrumentation/cdu/ident/engines"));
				}
				if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) > 107 and int(cduInput) < 119) {
				 	 setprop("/instrumentation/nav[0]/frequencies/selected-mhz",cduInput);
					}
					cduInput = "";
				}
				if (cduDisplay == "RTE1_1"){
					setprop("/autopilot/route-manager/departure/airport",cduInput);
					cduInput = "";
				}
				if (cduDisplay == "RTE1_LEGS"){
					if (cduInput == "DELETE"){
						setprop("/autopilot/route-manager/input","@DELETE1");
						cduInput = "";
					}else{
						setprop("/autopilot/route-manager/input","@INSERT2:"~cduInput);
					}
				}
				if (cduDisplay == "TO_REF"){
					setprop("/instrumentation/fmc/to-flap",cduInput);
					setprop("/instrumentation/fmc/isCustomizeFlaps",1);
					cduInput = "";
				}
				if (cduDisplay == "POS_REF_0"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "POS_REF"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "VNAV"){
					cduInput = crzAltCDUInput();
					if(cduInput != "INVALID ENTRY"){
						VNAVChanges();
					}
				}
				if (cduDisplay == "FMC_COMM"){
					cduDisplay = "RTE1_1";
				}
				if (cduDisplay == "ALTN")
				{
					setprop("/instrumentation/fmc/sltd-ALTN",1);
				}
			}
			if (v == "LSK1R"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line1/right") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newrunway", getprop("/instrumentation/cdu/output/line1/right"));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);

					}
				}
				if (cduDisplay == "RTE1_ARR"){
					if (getprop("/instrumentation/cdu/output/line1/right") != ""){
						setprop("/autopilot/route-manager/isArmed",1);
						setprop("/autopilot/route-manager/destination/newApproach", getprop("/instrumentation/cdu/output/line1/right"));
						setprop("/instrumentation/cdu/appr/apprIsSelected", 1);
					}
				}
				if (cduDisplay == "EICAS_MODES"){
					eicasDisplay = "FUEL";
				}
				if (cduDisplay == "EICAS_SYN"){
					eicasDisplay = "HYD";
				}
				if (cduDisplay == "POS_INIT"){
					cduInput = LatDMMunsignal(getprop("/instrumentation/fmc/lastposlat"))~LonDmmUnsignal(getprop("/instrumentation/fmc/lastposlon"));
				}
				if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) > 107 and int(cduInput) < 119) {
						setprop("/instrumentation/nav[1]/frequencies/selected-mhz",cduInput);
					}
					cduInput = "";
				}
				if (cduDisplay == "RTE1_1"){
					setprop("/autopilot/route-manager/destination/airport",cduInput);
					cduInput = "";
				}
				if (cduDisplay == "RTE1_LEGS"){
					setprop("/autopilot/route-manager/route/wp[1]/altitude-ft",cduInput);
					if (substr(cduInput,0,2) == "FL"){
						setprop("/autopilot/route-manager/route/wp[1]/altitude-ft",substr(cduInput,2)*100);
					}
					cduInput = "";
				}
				if (cduDisplay == "POS_REF_0"){
					if (getprop("/instrumentation/cdu/isARMED") == 0){
						setprop("/instrumentation/cdu/isARMED",1);
					}else if(getprop("/instrumentation/cdu/isARMED") == 1){
						setprop("/instrumentation/cdu/isARMED",0);
					}
				}
				if (cduDisplay == "FMC_COMM"){
					cduInput = "IN DEVELOPMENT";
					msg = 1;
				}
				if (cduDisplay == "PERF_INIT"){
					cduInput = crzAltCDUInput();
					if (cduInput == "INVALID ENTRY")
					{msg = 1;}
					setprop("/autopilot/route-manager/cruise/altitude-FL",getprop("/instrumentation/fmc/VNAV/cruise/altitude-FL"));
					setprop("/autopilot/route-manager/cruise/altitude-ft",getprop("/instrumentation/fmc/VNAV/cruise/altitude-ft"));
				}#end of PERF_INIT
				if (cduDisplay == "TO_REF"){
					if (cduInput == ""){
						setprop("/instrumentation/fmc/V1checked",1);
					} else if (num(cduInput) != nil){
						setprop("/instrumentation/fmc/vspeeds/V1", cduInput);
						setprop("/instrumentation/fmc/V1checked",1);
						cduInput = "";
					}else{
						setprop("/instrumentation/fmc/V1checked",1);
					}
				}#end of TO_REF
			}
			if (v == "LSK2L"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line2/left") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newsid", getprop("/instrumentation/cdu/output/line2/left"));
						setprop("/instrumentation/cdu/sids/sidIsSelected", 1);
						setprop("/autopilot/route-manager/departure/newrunway", getRwyOfSids(getprop("/instrumentation/cdu/output/line2/left")));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						setprop("/autopilot/route-manager/departure/sidID", getprop("/instrumentation/cdu/output/line2/left"));
					}
				}
				if (cduDisplay == "EICAS_MODES"){
					eicasDisplay = "STAT";
				}
				if (cduDisplay == "EICAS_SYN"){
					eicasDisplay = "ECS";
				}
				if (cduDisplay == "POS_INIT"){
					setprop("/instrumentation/fmc/ref-airport",cduInput);
					var RefApt = airportinfo(getprop("/instrumentation/fmc/ref-airport"));
					setprop("/instrumentation/fmc/ref-airport-poslat",RefApt.lat);
					setprop("/instrumentation/fmc/ref-airport-poslon",RefApt.lon);
					setprop("/instrumentation/fmc/gate", "");
					cduInput = "";
				}
				if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) < 360) {
						setprop("/instrumentation/nav[0]/radials/selected-deg",cduInput);
					}
					cduInput = "";
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "POS_INIT";
				}
				if (cduDisplay == "RTE1_1"){
					if (getprop("/autopilot/route-manager/departure/airport") == ""){
						cduInput = cduInput;
					}else{
						setprop("/autopilot/route-manager/departure/newrunway",cduInput);
						cduInput = "";
					}
				}
				if (cduDisplay == "RTE1_LEGS"){
					if (cduInput == "DELETE"){
						setprop("/autopilot/route-manager/input","@DELETE2");
						cduInput = "";
					}
					else{
						setprop("/autopilot/route-manager/input","@INSERT3:"~cduInput);
					}
				}
				if (cduDisplay == "POS_REF_0"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "POS_REF"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/THRLIM","TOGA");
				}
				if (cduDisplay == "FMC_COMM"){
					cduDisplay = "ALTN";
				}
				if (cduDisplay == "ALTN")
				{
					setprop("/instrumentation/fmc/sltd-ALTN",2);
				}
			}
			if (v == "LSK2R"){
				if (cduDisplay == "RTE1_ARR"){
					if (getprop("/instrumentation/cdu/output/line2/right") != ""){
						setprop("/autopilot/route-manager/isArmed",1);
						setprop("/autopilot/route-manager/destination/newApproach", getprop("/instrumentation/cdu/output/line2/right"));
						setprop("/instrumentation/cdu/appr/apprIsSelected", 1);
					}
				}
				if (cduDisplay == "RTE1_DEP"){
					setprop("/autopilot/route-manager/isChanged",1);
					if (getprop("/instrumentation/cdu/output/line2") != ""){
						setprop("/autopilot/route-manager/departure/newrunway", getprop("/instrumentation/cdu/output/line2/right"));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
					}
				}else if (cduDisplay == "DEP_ARR_INDEX")
				{
					cduDisplay = "RTE1_ARR";
					setprop("/instrumentation/cdu/appr/page", 1);
				}
				else if (cduDisplay == "EICAS_MODES"){
					eicasDisplay = "GEAR";
				}
				else if (cduDisplay == "EICAS_SYN"){
					eicasDisplay = "DRS";
				}else if (cduDisplay == "POS_INIT"){
					if(getprop("/instrumentation/fmc/ref-airport") != ""){
						cduInput = LatDMMunsignal(getprop("/instrumentation/fmc/ref-airport-poslat"))~LonDmmUnsignal(getprop("/instrumentation/fmc/ref-airport-poslon"));
					}
				}
				else if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) < 360) {
						setprop("/instrumentation/nav[1]/radials/selected-deg",cduInput);
					}
					cduInput = "";
				}
				else if (cduDisplay == "MENU"){
					eicasDisplay = "EICAS_MODES";
				}
				else if (cduDisplay == "RTE1_LEGS"){
					setprop("/autopilot/route-manager/route/wp[2]/altitude-ft",cduInput);
					if (substr(cduInput,0,2) == "FL"){
						setprop("/autopilot/route-manager/route/wp[2]/altitude-ft",substr(cduInput,2)*100);
					}
					cduInput = "";
				}
				else if (cduDisplay == "RTE1_1"){
					setprop("/instrumentation/fmc/flight-number",cduInput);
					cduInput = "";
				}else if (cduDisplay == "PERF_INIT"){

					if (num(cduInput) != nil){
						if(cduInput >= 0){
							if(cduInput <= 1000){
								setprop("/instrumentation/fmc/COST_INDEX",cduInput);
								cduInput = "";
							}else{cduInput = "INVALID ENTRY";msg = 1;}
						}else{cduInput = "INVALID ENTRY";msg = 1;}
					}else{cduInput = "INVALID ENTRY";msg = 1;}

				}
				else if(cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/CLB_LIM","CLB");
				}
				else if (cduDisplay == "TO_REF"){
					if(cduInput == ""){setprop("/instrumentation/fmc/VRchecked",1);}
					else if(num(cduInput) != nil){
							setprop("/instrumentation/fmc/vspeeds/VR", cduInput);
							setprop("/instrumentation/fmc/VRchecked",1);
							cduInput = "";
					}else{setprop("/instrumentation/fmc/VRchecked",1);}
				}
			}
			if (v == "LSK3L"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line3/left") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newsid", getprop("/instrumentation/cdu/output/line3/left"));
						setprop("/instrumentation/cdu/sids/sidIsSelected", 1);
						setprop("/autopilot/route-manager/departure/newrunway", getRwyOfSids(getprop("/instrumentation/cdu/output/line3/left")));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						setprop("/autopilot/route-manager/departure/sidID", getprop("/instrumentation/cdu/output/line3/left"));
					}
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "PERF_INIT";
				}
				if (cduDisplay == "POS_INIT"){
					if(getprop("/instrumentation/fmc/ref-airport")){
						if(cduInput == ""){
							setprop("/instrumentation/fmc/gate",cduInput);
							cduInput = "";
						}else if(findPosWithGate(gateName = cduInput, airport = getprop("/instrumentation/fmc/ref-airport")) == 404){
							cduInput = "NOT IN DATABASE";
							msg = 1;
						}else{
							setprop("/instrumentation/fmc/gate",cduInput);
							cduInput = "";
							msg = 1;
						}
					}

				}
				if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) > 189 and int(cduInput) < 1751) {
						setprop("/instrumentation/adf[0]/frequencies/selected-khz",cduInput);
					}
					cduInput = "";
				}
				if (cduDisplay == "RTE1_LEGS"){
					if (cduInput == "DELETE"){
						setprop("/autopilot/route-manager/input","@DELETE3");
						cduInput = "";
					}
					else{
						setprop("/autopilot/route-manager/input","@INSERT4:"~cduInput);
					}
				}
				if (cduDisplay == "POS_REF_0"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "POS_REF"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/THRLIM","TO-1");
				}
				if (cduDisplay == "FMC_COMM"){
					cduDisplay = "PERF_INIT";
				}
				if (cduDisplay == "VNAV"){
					#LSK3L，TransALT/SPD
					if(num(cduInput) != nil)
					{
						if(num(cduInput) >= getprop("instrumentation/weu/state/stall-speed") + 5)
						{
							if(num(cduInput) <= getprop("instrumentation/afds/max-airspeed-kts"))
							{
								setprop("/instrumentation/fmc/VNAV/XTransSPD",num(cduInput));
								cduInput = "";
								VNAVChanges();
							}
						}else{cduInput = "INVALID ENTRY";msg = 1;}
					}
					else if(left(cduInput,1) == "/")  #只修改ALT的情况
					{
						if (sum(substr(cduInput,1)) <=42000)
						{
							setprop("/instrumentation/fmc/VNAV/XTransALT",sum(substr(cduInput,1)));
							cduInput = "";
							VNAVChanges();
						}
					}
					else if (num(left(cduInput,3)) != nil)
					{
						if (substr(cduInput,3,1) == "/")
						{
							if(right(cduInput,4) >= 1000)
							{
								if (num((left(cduInput,2))) <= getprop("instrumentation/weu/state/stall-speed") + 5)
								{
									setprop("/instrumentation/fmc/VNAV/XTransSPD",num((left(cduInput,3))));
									setprop("/instrumentation/fmc/VNAV/XTransALT",num(substr(cduInput,4)));
									cduInput = "";
									VNAVChanges();
								}else{cduInput = "INVALID ENTRY";msg = 1;}
							}
						}
					}

					else{cduInput = "INVALID ENTRY";msg = 1;}
				}
				if (cduDisplay == "ALTN"){
					setprop("/instrumentation/fmc/sltd-ALTN",3);
				}
			}
			if (v == "LSK3R"){
				if (cduDisplay == "RTE1_ARR"){
					if (getprop("/instrumentation/cdu/output/line3/right") != ""){
						setprop("/autopilot/route-manager/isArmed",1);
						setprop("/autopilot/route-manager/destination/newApproach", getprop("/instrumentation/cdu/output/line3/right"));
						setprop("/instrumentation/cdu/appr/apprIsSelected", 1);
					}
				}
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line3") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newrunway", getprop("/instrumentation/cdu/output/line3/right"));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						}
					}
				if (cduDisplay == "NAV_RAD"){
					if (int(cduInput) > 189 and int(cduInput) < 1751) {
						setprop("/instrumentation/adf[1]/frequencies/selected-khz",cduInput);
					}
					cduInput = "";
				}
				if (cduDisplay == "RTE1_LEGS"){
					setprop("/autopilot/route-manager/route/wp[3]/altitude-ft",cduInput);
					if (substr(cduInput,0,2) == "FL"){
						setprop("/autopilot/route-manager/route/wp[3]/altitude-ft",substr(cduInput,2)*100);
					}
					cduInput = "";
				}
				if(cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/CLB_LIM","CLB-1");
				}
				if (cduDisplay == "TO_REF"){
					if(cduInput == ""){setprop("/instrumentation/fmc/V2checked",1);}
					else if(num(cduInput) != nil){
							setprop("/instrumentation/fmc/vspeeds/V2", cduInput);
							setprop("/instrumentation/fmc/V2checked",1);
							cduInput = "";
					}else{setprop("/instrumentation/fmc/V2checked",1);}
				}
				if (cduDisplay == "VNAV")
				{
					if (num(cduInput) != nil)
					{
						setprop("/instrumentation/fmc/VNAV/TransALT",cduInput);
						VNAVChanges();
						cduInput = "";
					}
				}
				if(cduDisplay == "POS_INIT"){
					cduInput = getprop("instrumentation/fmc/gate-pos-lat-noformat") ~ getprop("instrumentation/fmc/gate-pos-lon-noformat");
				}
			}
			if (v == "LSK4L"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line4/left") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newsid", getprop("/instrumentation/cdu/output/line4/left"));
						setprop("/instrumentation/cdu/sids/sidIsSelected", 1);
						setprop("/autopilot/route-manager/departure/newrunway", getRwyOfSids(getprop("/instrumentation/cdu/output/line4/left")));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						setprop("/autopilot/route-manager/departure/sidID", getprop("/instrumentation/cdu/output/line4/left"));
					}
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "THR_LIM";
				}
				if (cduDisplay == "RTE1_LEGS"){
					if (cduInput == "DELETE"){
						setprop("/autopilot/route-manager/input","@DELETE4");
						cduInput = "";
					}
					else{
						setprop("/autopilot/route-manager/input","@INSERT5:"~cduInput);
					}
				}
				if (cduDisplay == "POS_REF_0"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}if (cduDisplay == "POS_REF"){
					cduInput = LatDMMunsignal(getprop("/position/latitude-deg"))~LonDmmUnsignal(getprop("/position/longitude-deg"));
				}
				if (cduDisplay == "PERF_INIT"){
					setprop("/instrumentation/cdu/RESERVES",cduInput);
					cduInput = "";
				}
				if (cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/THRLIM","TO-2");
				}
				if (cduDisplay == "FMC_COMM"){
					cduDisplay = "TO_REF";
				}
				if (cduDisplay == "VNAV")
				{
					#LSK4L，TransALT/SPD
					if(num(cduInput) != nil)
					{
						if(int(cduInput) >= getprop("instrumentation/weu/state/stall-speed") + 5)
						{
							if(int(cduInput) <= getprop("instrumentation/afds/max-airspeed-kts"))
							{
								setprop("/instrumentation/fmc/VNAV/RestrSPD",num(cduInput));
								cduInput = "";
								VNAVChanges();
							}
						}else{cduInput = "INVALID ENTRY";msg = 1;}
					}
					else if(left(cduInput,1) == "/")  #只修改ALT的情况
					{
						if (sum(substr(cduInput,1)) <=42000)
						{
							setprop("/instrumentation/fmc/VNAV/RestrALT",sum(substr(cduInput,1)));
							cduInput = "";
							VNAVChanges();
						}
					}
					else if (num(left(cduInput,3)) != nil)
					{
						if (substr(cduInput,3,1) == "/")
						{
							if(right(cduInput,4) >= 1000)
							{
								if (num((left(cduInput,2))) <= getprop("instrumentation/weu/state/stall-speed") + 5)
								{
									setprop("/instrumentation/fmc/VNAV/RestrSPD",num((left(cduInput,3))));
									setprop("/instrumentation/fmc/VNAV/RestrALT",num(substr(cduInput,4)));
									cduInput = "";
									VNAVChanges();
								}else{cduInput = "INVALID ENTRY";msg = 1;}
							}
						}
					}

					else{cduInput = "INVALID ENTRY";msg = 1;}
				}
				if (cduDisplay == "ALTN")
				{
					setprop("/instrumentation/fmc/sltd-ALTN",4);
				}
			}
			if (v == "LSK4R"){
				if (cduDisplay == "RTE1_ARR"){
					if (getprop("/instrumentation/cdu/output/line4/right") != ""){
						setprop("/autopilot/route-manager/isArmed",1);
						setprop("/autopilot/route-manager/destination/newApproach", getprop("/instrumentation/cdu/output/line4/right"));
						setprop("/instrumentation/cdu/appr/apprIsSelected", 1);
					}
				}
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line4") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newrunway", getprop("/instrumentation/cdu/output/line4/right"));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						}
					}
				if (cduDisplay == "POS_INIT"){
					cduInput = LatDMMunsignal(getprop("/instrumentation/fmc/gpsposlat"))~LonDmmUnsignal(getprop("/instrumentation/fmc/gpsposlon"));
				}
				if (cduDisplay == "RTE1_LEGS"){
					setprop("/autopilot/route-manager/route/wp[4]/altitude-ft",cduInput);
					if (substr(cduInput,0,2) == "FL"){
						setprop("/autopilot/route-manager/route/wp[4]/altitude-ft",substr(cduInput,2)*100);
					}
					cduInput = "";
				}
				if(cduDisplay == "THR_LIM"){
					setprop("/instrumentation/fmc/CLB_LIM","CLB-2");
				}
				if (cduDisplay == "TO_REF"){
					if(cduInput == ""){setprop("/instrumentation/fmc/V2checked",1);}
					else if(num(cduInput) != nil){
							setprop("/instrumentation/fmc/vspeeds/V2", cduInput);
							setprop("/instrumentation/fmc/V1checked",2);
							cduInput = "";
					}else{setprop("/instrumentation/fmc/V1checked",1);}
				}
			}
			if (v == "LSK5L"){
				if (cduDisplay == "RTE1_DEP"){
					if (getprop("/instrumentation/cdu/output/line5/left") != ""){
						setprop("/autopilot/route-manager/isChanged",1);
						setprop("/autopilot/route-manager/departure/newsid", getprop("/instrumentation/cdu/output/line5/left"));
						setprop("/instrumentation/cdu/sids/sidIsSelected", 1);
						setprop("/autopilot/route-manager/departure/newrunway", getRwyOfSids(getprop("/instrumentation/cdu/output/line5/left")));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						setprop("/autopilot/route-manager/departure/sidID", getprop("/instrumentation/cdu/output/line5/left"));
					}
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "TO_REF";
				}
				if (cduDisplay == "FMC_COMM"){
					cduInput = "IN DEVELOPMENT";
					msg = 1;
				}
				if (cduDisplay == "RTE1_LEGS"){
					if (cduInput == "DELETE"){
						setprop("/autopilot/route-manager/input","@DELETE5");
						cduInput = "";
					}
					else{
						setprop("/autopilot/route-manager/input","@INSERT6:"~cduInput);
					}
				}
			}
			if (v == "LSK5R"){
				if (cduDisplay == "RTE1_ARR"){
					if (getprop("/instrumentation/cdu/output/line5/right") != ""){
						setprop("/autopilot/route-manager/isArmed",1);
						setprop("/autopilot/route-manager/destination/newApproach", getprop("/instrumentation/cdu/output/line5/right"));
						setprop("/instrumentation/cdu/appr/apprIsSelected", 1);
					}
				}
				if (cduDisplay == "RTE1_DEP"){
					setprop("/autopilot/route-manager/isChanged",1);
					if (getprop("/instrumentation/cdu/output/line5") != ""){
						setprop("/autopilot/route-manager/departure/newrunway", getprop("/instrumentation/cdu/output/line5/right"));
						setprop("/instrumentation/cdu/sids/rwyIsSelected", 1);
						}
					}
				if (cduDisplay == "RTE1_LEGS"){
					setprop("/autopilot/route-manager/route/wp[5]/altitude-ft",cduInput);
					if (substr(cduInput,0,2) == "FL"){
						setprop("/autopilot/route-manager/route/wp[5]/altitude-ft",substr(cduInput,2)*100);
					}
					cduInput = "";
				}
				if (cduDisplay == "POS_INIT"){
					call(func getIRSPos(cduInput), nil, var err2 = []);
					if (size(err2)){
						setprop("/instrumentation/fmc/isInputedPos",0);
						cduInput = "INVALID ENTRY";
						msg = 1;
					}else{
						setprop("/instrumentation/fmc/isInputedPos",1);
						cduInput = "";
					}
				}
				if (cduDisplay == "TO_REF_2")
				{
					setprop("/instrumentation/fmc/ref-temperature-degc",cduInput);
					cduInput = "";
				}
				if (cduDisplay == "PERF_INIT")
				{
					if (cduInput == "0")
					{
						setprop("/instrumentation/cdu/StepSize","INHIBIT");
						cduInput = "";
					}
					else if(cduInput == "R")
					{
						setprop("/instrumentation/cdu/StepSize","RVSM");
						cduInput = "";
					}
					else if(cduInput == "RVSM")
					{
						setprop("/instrumentation/cdu/StepSize","RVSM");
						cduInput = "";
					}
					else if(cduInput == "I")
					{
						setprop("/instrumentation/cdu/StepSize","ICAO");
						cduInput = "";
					}
					else if(cduInput == "ICAO")
					{
						setprop("/instrumentation/cdu/StepSize","ICAO");
						cduInput = "";
					}
				}
			}
			if (v == "LSK6L"){
				if (cduDisplay == "FMC_COMM"){
					cduInput = "IN DEVELOPMENT";
					msg = 1;
				}
				if(cduDisplay == "ALTN"){
					if(datalink.allAircrafts[0].requestState == "<REQUEST" or datalink.allAircrafts[0].requestState == "<REQUEST SENT"){
						datalink.allAircrafts[0].request("ALTNWXR",datalink.allGrounds[0]);
					}
				}
				if (cduDisplay == "INIT_REF"){
					cduDisplay = "APP_REF";
				}else if ((cduDisplay == "APP_REF") or (cduDisplay == "IDENT") or (cduDisplay == "MAINT") or (cduDisplay == "PERF_INIT") or (cduDisplay == "POS_INIT") or (cduDisplay == "POS_REF") or (cduDisplay == "THR_LIM") or (cduDisplay == "TO_REF") or (cduDisplay == "ALTN_LIST")){
					cduDisplay = "INIT_REF";
				}else if (cduDisplay == "RTE1_DEP"){
					if(getprop("/autopilot/route-manager/isChanged") != 0){
						if (getprop("/autopilot/route-manager/departure/sid") != nil){
							setprop("/autopilot/route-manager/departure/newsid", getprop("/autopilot/route-manager/departure/sid"));
						}else{
							setprop("/instrumentation/cdu/sids/sidIsSelected", 0);
						}
						if (getprop("/autopilot/route-manager/departure/runway") != nil){
							setprop("/autopilot/route-manager/departure/newrunway", getprop("/autopilot/route-manager/departure/runway"));
						}else{
							setprop("/instrumentation/cdu/sids/rwyIsSelected", 0);
						}
						setprop("/autopilot/route-manager/isChanged", 0);
						setprop("/autopilot/route-manager/isArmed", -1);
					}else{
						cduDisplay = "DEP_ARR_INDEX";
					}
				}
				if(cduDisplay == "ABOUT_PROJECT"){
					cduDisplay = "MAINT";
				}


			}
			if (v == "LSK6R"){
				if (cduDisplay == "MAINT") {
					cduDisplay = "ABOUT_PROJECT";
				}
				if (cduDisplay == "FMC_COMM"){
					datalink.aircraft1.testConnection();

					#datalink.allAircrafts[0].request("ALTNWXR",datalink.allGrounds[0]);


				}
				if (cduDisplay == "THR_LIM"){
					cduDisplay = "TO_REF";
				}
				else if (cduDisplay == "APP_REF"){
					cduDisplay = "THR_LIM";
				}
				else if ((cduDisplay == "RTE1_1") or (cduDisplay == "RTE1_LEGS")){
					armChanges();
				}
				else if ((cduDisplay == "POS_INIT") or (cduDisplay == "DEP") or (cduDisplay == "RTE1_ARR") or (cduDisplay == "RTE1_DEP")){
					cduDisplay = "RTE1_1";
				}
				else if ((cduDisplay == "IDENT") or (cduDisplay == "TO_REF")){
					cduDisplay = "POS_INIT";
				}
				else if (cduDisplay == "EICAS_SYN"){
					cduDisplay = "EICAS_MODES";
				}
				else if (cduDisplay == "EICAS_MODES"){
					cduDisplay = "EICAS_SYN";
				}
				else if (cduDisplay == "INIT_REF"){
					cduDisplay = "MAINT";
				}
				else if (cduDisplay == "POS_REF_0"){
					if(getprop("/instrumentation/cdu/LATorBRG") == 1)
					{
						setprop("/instrumentation/cdu/LATorBRG",0);
					}
					else if(getprop("/instrumentation/cdu/LATorBRG") == 0)
					{
						setprop("/instrumentation/cdu/LATorBRG",1);
					}
				}
				else if (cduDisplay == "POS_REF"){
					if(getprop("/instrumentation/cdu/LATorBRG") == 1)
					{
						setprop("/instrumentation/cdu/LATorBRG",0);
					}
					else if(getprop("/instrumentation/cdu/LATorBRG") == 0)
					{
						setprop("/instrumentation/cdu/LATorBRG",1);
					}
				}
				else if (cduDisplay == "PERF_INIT")
				{
					cduDisplay = "THR_LIM";
				}
			}
		}

		setprop("/instrumentation/cdu/display",cduDisplay);
		setprop("/instrumentation/cdu/input",cduInput);
		setprop("/instrumentation/fmc/isMsg",msg);

		if (eicasDisplay != nil){
			setprop("/instrumentation/eicas/display",eicasDisplay);
		}
}

var cdu = func{

		var display = getprop("/instrumentation/cdu/display");

		var serviceable = getprop("/instrumentation/cdu/serviceable");
		title = "";		page = "";
		line1l = "";	line2l = "";	line3l = "";	line4l = "";	line5l = "";	line6l = "";
		line1lt = "";	line2lt = "";	line3lt = "";	line4lt = "";	line5lt = "";	line6lt = "";
		line1ls = "";	line2ls = "";	line3ls = "";	line4ls = "";	line5ls = "";	line6ls = "";
		line1c = "";	line2c = "";	line3c = "";	line4c = "";	line5c = "";	line6c = "";
		line1ct = "";	line2ct = "";	line3ct = "";	line4ct = "";	line5ct = "";	line6ct = "";
		line1r = "";	line2r = "";	line3r = "";	line4r = "";	line5r = "";	line6r = "";
		line1rt = "";	line2rt = "";	line3rt = "";	line4rt = "";	line5rt = "";	line6rt = "";
		line1rs = "";	line2rs = "";	line3rs = "";	line4rs = "";	line5rs = "";	line6rs = "";
		line1ctl = "";	line1cl = ""; line1cr = "";
		line2ctl = "";	line2cl = ""; line2cr = "";
		line3ctl = "";	line3cl = ""; line3cr = "";
		line4ctl = "";	line4cl = ""; line4cr = "";
		line5ctl = "";	line5cl = ""; line5cr = "";
		line6ctl = "";	line6cl = ""; line6cr = "";

		var cduDisplayRefresh = func(){
			var cduOutputPath = "/instrumentation/cdu/output/";
			var cduProps = props.getNode(cduOutputPath, 1);


			cduProps.setValue("title", title);
			cduProps.setValue("page", page);
			cduProps.setValue("line1/left", line1l);
			cduProps.setValue("line2/left", line2l);
			cduProps.setValue("line3/left", line3l);
			cduProps.setValue("line4/left", line4l);
			cduProps.setValue("line5/left", line5l);
			cduProps.setValue("line6/left", line6l);
			cduProps.setValue("line1/left-title", line1lt);
			cduProps.setValue("line2/left-title", line2lt);
			cduProps.setValue("line3/left-title", line3lt);
			cduProps.setValue("line4/left-title", line4lt);
			cduProps.setValue("line5/left-title", line5lt);
			cduProps.setValue("line6/left-title", line6lt);
			cduProps.setValue("line1/center", line1c);
			cduProps.setValue("line2/center", line2c);
			cduProps.setValue("line3/center", line3c);
			cduProps.setValue("line4/center", line4c);
			cduProps.setValue("line5/center", line5c);
			cduProps.setValue("line6/center", line6c);
			cduProps.setValue("line1/center-left", line1cl);
			cduProps.setValue("line2/center-left", line2cl);
			cduProps.setValue("line3/center-left", line3cl);
			cduProps.setValue("line4/center-left", line4cl);
			cduProps.setValue("line5/center-left", line5cl);
			cduProps.setValue("line6/center-left", line6cl);
			cduProps.setValue("line1/center-right", line1cr);
			cduProps.setValue("line2/center-right", line2cr);
			cduProps.setValue("line3/center-right", line3cr);
			cduProps.setValue("line4/center-right", line4cr);
			cduProps.setValue("line5/center-right", line5cr);
			cduProps.setValue("line6/center-right", line6cr);
			cduProps.setValue("line1/center-title", line1ct);
			cduProps.setValue("line2/center-title", line2ct);
			cduProps.setValue("line3/center-title", line3ct);
			cduProps.setValue("line4/center-title", line4ct);
			cduProps.setValue("line5/center-title", line5ct);
			cduProps.setValue("line6/center-title", line6ct);
			cduProps.setValue("line1/right", line1r);
			cduProps.setValue("line2/right", line2r);
			cduProps.setValue("line3/right", line3r);
			cduProps.setValue("line4/right", line4r);
			cduProps.setValue("line5/right", line5r);
			cduProps.setValue("line6/right", line6r);
			cduProps.setValue("line1/right-title", line1rt);
			cduProps.setValue("line2/right-title", line2rt);
			cduProps.setValue("line3/right-title", line3rt);
			cduProps.setValue("line4/right-title", line4rt);
			cduProps.setValue("line5/right-title", line5rt);
			cduProps.setValue("line6/right-title", line6rt);
			cduProps.setValue("line1/center-title-large", line1ctl);
			cduProps.setValue("line2/center-title-large", line3ctl);
			cduProps.setValue("line3/center-title-large", line3ctl);
			cduProps.setValue("line4/center-title-large", line4ctl);
			cduProps.setValue("line5/center-title-large", line5ctl);
			cduProps.setValue("line6/center-title-large", line6ctl);
			cduProps.setValue("line1/left-small", line1ls);
			cduProps.setValue("line2/left-small", line2ls);
			cduProps.setValue("line3/left-small", line3ls);
			cduProps.setValue("line4/left-small", line4ls);
			cduProps.setValue("line5/left-small", line5ls);
			cduProps.setValue("line6/left-small", line6ls);
			cduProps.setValue("line1/right-small", line1rs);
			cduProps.setValue("line2/right-small", line2rs);
			cduProps.setValue("line3/right-small", line3rs);
			cduProps.setValue("line4/right-small", line4rs);
			cduProps.setValue("line1/right-small", line1rs);
			cduProps.setValue("line5/right-small", line5rs);
			cduProps.setValue("line6/right-small", line6rs);
		}

		if (display == "MENU") {

			title = "MENU";
			line1l = "<FMC";
			line1rt = "EFIS CP";
			line1r = "SELECT>";
			line2l = "<ACARS";
			line2rt = "EICAS CP";
			line2r = "SELECT>";
			line6l = "<ACMS";
			line6r = "CMC>";
		}
		if (display == "ALTN_NAV_RAD") {

			title = "ALTN NAV RADIO";
		}
		if (display == "APP_REF") {

			title = "APPROACH REF";
			line1lt = "GROSS WT";
			line1cr = "FLAPS";
			line2cr = "20*";
			line3cr = "25*";
			line4cr = "30*";
			line1rt = "VREF";
			if (getprop("/autopilot/route-manager/destination/airport") != nil){
				line4lt = getprop("/autopilot/route-manager/destination/airport");
			}
			if (lbs2tons(getprop("/fdm/yasim/gross-weight-lbs")) != nil){
				line1l = sprintf("%3.2f",lbs2tons(getprop("/yasim/gross-weight-lbs")));
				setprop("/fdm/yasim/gross-weight-tons",lbs2tons(getprop("/yasim/gross-weight-lbs")));

			}
			line6l = "<INDEX";
			line6r = "THRUST LIM>";
		}
		if (display == "DEP_ARR_INDEX") {

			title = "DEP/ARR INDEX";
			line1l = "<DEP";
			line1ct = "RTE 1";
			if (getprop("/autopilot/route-manager/departure/airport") != nil){
				line1c = getprop("/autopilot/route-manager/departure/airport");
			}
			line1r = "ARR>";
			if (getprop("/autopilot/route-manager/destination/airport") != nil){
				line2c = getprop("/autopilot/route-manager/destination/airport");
			}
			line2r = "ARR>";
			line3l = "<DEP";
			line3r = "ARR>";
			line4r = "ARR>";
			line6lt ="DEP";
			line6l = "<----";
			line6c = "OTHER";
			line6rt ="ARR";
			line6r = "---->";
		}
		if (display == "EICAS_MODES") {

			title = "EICAS MODES";
			line1l = "<ENG";
			line1r = "FUEL>";
			line2l = "<STAT";
			line2r = "GEAR>";
			line5l = "<CANC";
			line5r = "RCL>";
			line6r = "SYNOPTICS>";
		}
		if (display == "EICAS_SYN") {

			title = "EICAS SYNOPTICS";
			line1l = "<ELEC";
			line1r = "HYD>";
			line2l = "<ECS";
			line2r = "DOORS>";
			line5l = "<CANC";
			line5r = "RCL>";
			line6r = "MODES>";
		}
		if (display == "FIX_INFO") {

			title = "FIX INFO";
			line1l = sprintf("%3.2f", getprop("/instrumentation/nav[0]/frequencies/selected-mhz-fmt"));
			line1r = sprintf("%3.2f", getprop("/instrumentation/nav[1]/frequencies/selected-mhz-fmt"));
			line2l = sprintf("%3.2f", getprop("/instrumentation/nav[0]/radials/selected-deg"));
			line2r = sprintf("%3.2f", getprop("/instrumentation/nav[1]/radials/selected-deg"));
			line6l = "<ERASE FIX";
		}
		if (display == "IDENT") {

			title = "IDENT";
			line1lt = "MODEL";
			if (getprop("/instrumentation/cdu/ident/model") != nil){
				line1l = getprop("/instrumentation/cdu/ident/model");
			}
			line1rt = "ENGINES";
			line2lt = "NAV DATA";
			if (getprop("/instrumentation/cdu/ident/engines") != nil){
				line1r = string.uc(getprop("/instrumentation/cdu/ident/engines"));
			}
			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = "POS INIT>";
		}
		if (display == "INIT_REF") {

			title = "INIT/REF INDEX";
			line1l = "<IDENT";
			line1r = "NAV DATA>";
			line2l = "<POS";
			line3l = "<PERF";
			line4l = "<THRUST LIM";
			line5l = "<TAKEOFF";
			line6l = "<APPROACH";
			line6r = "MAINT>";
		}
		if (display == "MAINT") {

			title = "MAINTENANCE INDEX";
			line1l = "<CROS LOAD";
			line1r = "BITE>";
			line2l = "<PERF FACTORS";
			line3l = "<IRS MONITOR";
			line6l = "<INDEX";
			line6r = "READ ME>";
		}
		if (display == "ABOUT_PROJECT"){

			title = "FG777CDU IMPROVEMENT PROJECT";
			line1lt = "BROUGHT TO YOU BY FLIGHTGEAR CHINA";
			line1l = "SIDI LIANG YONGFAN LI";
			line2lt = " ________ _______ _______  _______   _______ ";
			line2l = "|  ___/ ___|  _ \|  _ \ / ___|";
			line3l = "| |_ | |  _| |_) | |_) | |    ";
			line4l = "|  _|| |_| |  __/|  _ <| |___ ";
			line5l = "|_|   \____|_|   |_| \_\\____|";
			line6l = "<MAINT";
		}
		if (display == "NAV_RAD") {

			title = "NAV RADIO";
			line1lt = "VOR L";
			line1l = sprintf("%3.2f", getprop("/instrumentation/nav[0]/frequencies/selected-mhz-fmt"));
			line1rt = "VOR R";
			line1r = sprintf("%3.2f", getprop("/instrumentation/nav[1]/frequencies/selected-mhz-fmt"));
			line2lt = "CRS";
			line2ct = "RADIAL";
			line2c = sprintf("%3.2f", getprop("/instrumentation/nav[0]/radials/selected-deg"))~"   "~sprintf("%3.2f", getprop("/instrumentation/nav[1]/radials/selected-deg"));
			line2rt = "CRS";
			line3lt = "ADF L";
			line3l = sprintf("%3.2f", getprop("/instrumentation/adf[0]/frequencies/selected-khz"));
			line3rt = "ADF R";
			line3r = sprintf("%3.2f", getprop("/instrumentation/adf[1]/frequencies/selected-khz"));
		}
		if (display == "PERF_INIT") {

			title = "PERF INIT";
			line1lt = "GR WT";
			line1rt = "CRZ ALT";
			line2rt = "COST INDEX";
			line2r = getprop("instrumentation/fmc/COST_INDEX") or " ";
			line2lt = "FUEL";
			line3lt = "ZFW";
			line3rt = "MIN FUEL TEMP";
			line3r = "-37*C";
			line4lt = "RESERVES";
			line4l = getprop("/instrumentation/cdu/RESERVES") or " ";
			line4rt = "CRZ CG";
			line5rt = "STEP SIZE";
			line5r =  getprop("instrumentation/cdu/StepSize");
			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = "THRUST LIM>";
			if (getprop("/autopilot/route-manager/cruise/altitude-ft") != nil){
				if(getprop("/autopilot/route-manager/cruise/altitude-ft") == 0){
					line1r = "";
				}else if(getprop("/autopilot/route-manager/cruise/altitude-ft") < 10000){
					line1r = sprintf("%2.0f",getprop("/autopilot/route-manager/cruise/altitude-ft"));
				}else if(getprop("/autopilot/route-manager/cruise/altitude-ft") > 10000){
					line1r = getprop("/autopilot/route-manager/cruise/altitude-FL");
				}
			}
		}
		if (display == "POS_INIT") {

			title = "POS INIT";
			page = "1/3";
			line1rt = "LAST POS";
			line1r = getLastPos();
			line2lt = "REF AIRPORT";
			var getRefApt = func(){
				var aptA_INIT = getprop("/instrumentation/fmc/ref-airport") or "";
				if (aptA_INIT == ""){
					setprop("/instrumentation/fmc/ref-airport-pos", "");
					return "----";
				}else{
					var refAptLat = airportinfo(aptA_INIT).lat;
					var refAptLon = airportinfo(aptA_INIT).lon;
					var refAptPosStr = latdeg2latDMM(refAptLat)~" "~londeg2lonDMM(refAptLon);
					setprop("/instrumentation/fmc/ref-airport-pos", refAptPosStr);
					return aptA_INIT;
				}
			}
			var line2ltmp = call(func getRefApt(), nil, var err = []);
			if (size(err)){
				setprop("/instrumentation/fmc/ref-airport", "");
				setprop("/instrumentation/cdu/input", "NOT IN DATABASE");
				setprop("/instrumentation/fmc/isMsg",1);
			}else{
				line2l = line2ltmp;
			}

			line2r = getprop("/instrumentation/fmc/ref-airport-pos");
			line3lt = "GATE";
			#line3l = getprop("/instrumentation/fmc/gate"); #Temperary code, abandoned April 24 by Sidi Liang, replaced by code below
			if(getprop("/instrumentation/fmc/ref-airport")){
				if(!getprop("/instrumentation/fmc/gate")){
					line3l = "-----";
					line3r = " ";
				}else{
					line3l = getprop("/instrumentation/fmc/gate");
					line3r = getprop("instrumentation/fmc/gate-pos-lat-str") ~" "~getprop("instrumentation/fmc/gate-pos-lon-str");
				}
			}else{
				line3l = " ";
				line3r = " ";
			}
			line4rt = "GPS POS";
			line4r = getGpsPos();
			line4lt = "UTC";
			if(getprop("/instrumentation/clock/indicated-hour") < 10){
				if(getprop("/instrumentation/clock/indicated-min") < 10){
					line4l = "0"~getprop("/instrumentation/clock/indicated-hour")~"0"~getprop("/instrumentation/clock/indicated-min")~"z";
				}else{
					line4l = "0"~getprop("/instrumentation/clock/indicated-hour")~getprop("/instrumentation/clock/indicated-min")~"z";
				}
			}else if(getprop("/instrumentation/clock/indicated-min") < 10){
				line4l = getprop("/instrumentation/clock/indicated-hour")~"0"~getprop("/instrumentation/clock/indicated-min")~"z";
			}else{
				line4l = getprop("/instrumentation/clock/indicated-hour")~getprop("/instrumentation/clock/indicated-min")~"z";
			}
			line5rt = "SET INERTIAL POS";
			if (getprop("/instrumentation/fmc/isInputedPos") == 1){
				line5r = "";
			}else{
				line5r = "   *  .    *  . ";
			}

			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = "ROUTE>";
		}
		if (display == "POS_REF_0") {

			title = "POS REF";
			page = "2/3";
			line1lt = "FMC(GPS)";
			line1ct = "ACTUAL";
			line1rt = "UPDATE";
			line1r = isUpdateArm();
			line2lt = "IRS(3)";
			line2ct = "ACTUAL";
			line2rt = "INERTIAL";
			line3lt = "GPS";
			line3ct = "ACTUAL";
			line3rt = "GPS";
			line4lt = "RADIO";
			line4ct = "ACTUAL";
			lien4rt = "RADIO";
			line5lt = "RNP/ACTUAL";
			line5l = "1.00/0.10";
			line5rt = "DME DME";
			line1l = echoLatBrg();
			line2l = echoLatBrg();
			line3l = echoLatBrg();
			line4l = echoLatBrg();
			line2r = echoUpdateArmed();
			line3r = echoUpdateArmed();
			line4r = echoUpdateArmed();
			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = DisplayLATorBRG();

		}
		if (display == "POS_REF") {

			title = "POS REF";
			page = "3/3";
			line1lt = "GPS L";
			line1rt = "GS";
			line1l = echoLatBrg();
			line1r = sprintf("%3.0f", getprop("/velocities/groundspeed-kt"));
			line2lt = "GPS C";
			line2rt = "GS";
			line2l = echoLatBrg();
			line2r = sprintf("%3.0f", getprop("/velocities/groundspeed-kt"));
			line3lt = "FMC L (PRI)";
			line3rt = "GS";
			line3r = sprintf("%3.0f", getprop("/velocities/groundspeed-kt"));
			line4lt = "FMC R";
			line4rt = "GS";
			line4l = echoLatBrg();
			line4r = sprintf("%3.0f", getprop("/velocities/groundspeed-kt"));
			line3l = echoLatBrg();
			line3r = sprintf("%3.0f", getprop("/velocities/groundspeed-kt"));
			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = DisplayLATorBRG();
		}
		if (display == "RTE1_1") {

			title = "RTE 1";
			page = "1/2";
			line1lt = "ORIGIN";
			if (getprop("/autopilot/route-manager/departure/airport") != nil){
				line1l = getprop("/autopilot/route-manager/departure/airport");
			}
			line1rt = "DEST";
			if (getprop("/autopilot/route-manager/destination/airport") != nil){
				line1r = getprop("/autopilot/route-manager/destination/airport");
			}
			line2lt = "RUNWAY";
			if (getprop("/autopilot/route-manager/departure/newrunway") != nil){
				line2l = getprop("/autopilot/route-manager/departure/newrunway");
			}else{
				if (getprop("/autopilot/route-manager/departure/runway") != nil){
							line2l = getprop("/autopilot/route-manager/departure/runway");
				}
			}
			line2rt = "FLT NO";
			line2r = getprop("/instrumentation/fmc/flight-number") or " ";
			line3rt = "CO ROUTE";
			line5l = "<RTE COPY";
			line6l = "<RTE 2";
			line6r = "ACTIVATE>";
		}
		if (display == "RTE1_2") {

			title = "RTE 1";
			page = "2/2";
			line1lt = "VIA";
			line1rt = "TO";
			if (getprop("/autopilot/route-manager/route/wp[1]/id") != nil){
				line1r = getprop("/autopilot/route-manager/route/wp[1]/id");
				}
			if (getprop("/autopilot/route-manager/route/wp[2]/id") != nil){
				line2r = getprop("/autopilot/route-manager/route/wp[2]/id");
				}
			if (getprop("/autopilot/route-manager/route/wp[3]/id") != nil){
				line3r = getprop("/autopilot/route-manager/route/wp[3]/id");
				}
			if (getprop("/autopilot/route-manager/route/wp[4]/id") != nil){
				line4r = getprop("/autopilot/route-manager/route/wp[4]/id");
				}
			if (getprop("/autopilot/route-manager/route/wp[5]/id") != nil){
				line5r = getprop("/autopilot/route-manager/route/wp[5]/id");
				}
			line6l = "<RTE 2";
			line6r = "ACTIVATE>";
		}

		if (display == "RTE1_ARR") {

			if (getprop("/autopilot/route-manager/destination/airport") != nil){
				title = getprop("/autopilot/route-manager/destination/airport")~" ARRIVALS";
			}
			else{
				title = "ARRIVALS";
			}
			if(getprop("/autopilot/route-manager/isChanged") == 0){
				var selOrAct = "<ACT>";
			    line6l = "<INDEX";
			}else{
				var selOrAct = "<SEL>";
				line6l = "<ERASE(WIP)";# WORK IN PROGRESS
			}
			line1ctl = "RTE 1";
			line1lt = "STARS";
			line1l = "WIP"; # WORK IN PROGRESS
			line1rt = "APPROACHES";

			if(getprop("/instrumentation/cdu/appr/apprIsSelected") == 0){
				line1r = echoAppr(getprop("/instrumentation/cdu/appr/page"))[0];
				line2r = echoAppr(getprop("/instrumentation/cdu/appr/page"))[1];
				line3r = echoAppr(getprop("/instrumentation/cdu/appr/page"))[2];
				line4r = echoAppr(getprop("/instrumentation/cdu/appr/page"))[3];
				line5r = echoAppr(getprop("/instrumentation/cdu/appr/page"))[4];
			}else if(getprop("/instrumentation/cdu/appr/apprIsSelected") == 1){
				line1r = getprop("/autopilot/route-manager/destination/newApproach");
				line1cr = selOrAct;
				line2rt = "TRANS";
				line2 = "WIP";# WORK IN PROGRESS
			}

			if(getprop("/instrumentation/cdu/appr/apprCountEnd") != 0 and getprop("/instrumentation/cdu/appr/apprIsSelected") == 0){
				var rwyTitle = getprop("/instrumentation/cdu/appr/apprCountEnd");
				if(rwyTitle == 1){
					line1rt = "RUNWAYS";
					line1r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[0];
					line2r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[1];
					line3r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[2];
					line4r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[3];
					line5r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[4];
				}
				if(rwyTitle == 2){
					line2rt = "RUNWAYS";
					line2r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[0];
					line3r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[1];
					line4r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[2];
					line5r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[3];
				}
				if(rwyTitle == 3){
					line3rt = "RUNWAYS";
					line3r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[0];
					line4r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[1];
					line5r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[2];
				}
				if(rwyTitle == 4){
					line4rt = "RUNWAYS";
					line4r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[0];
					line5r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[1];
				}
				if(rwyTitle == 5){
					line5rt = "RUNWAYS";
					line5r = echoRwysAppr(getprop("/instrumentation/cdu/appr/page"))[0];
				}
			}


			#if (getprop("/autopilot/route-manager/destination/runway") != nil){
			#	line1r = getprop("/autopilot/route-manager/destination/runway");
			#}

			#line2lt = "TRANS";
			#line3rt = "RUNWAYS";
			#line6l = "<INDEX";
			line6r = "ROUTE>";
			line6ct = "----------------------------------------";
		}

		if (display == "RTE1_DEP") {

				if(getprop("/autopilot/route-manager/isChanged") == 0){
					var selOrAct = "<ACT>";
				    line6l = "<INDEX";
				}else{
					var selOrAct = "<SEL>";
					line6l = "<ERASE";
				}
			if (getprop("/autopilot/route-manager/departure/airport") != nil){
				title = getprop("/autopilot/route-manager/departure/airport")~" DEPARTURES";
			}
			else{
				title = "DEPARTURES";
			}
			line1ctl = "RTE 1";
			line1lt = "SIDS";

			if(getprop("/instrumentation/cdu/sids/sidIsSelected") == 0){
				line1cl = "";
				if(getprop("/instrumentation/cdu/sids/rwyIsSelected") == 0){
					line1l = echoSids(getprop("/instrumentation/cdu/sids/page"))[0];
					line2l = echoSids(getprop("/instrumentation/cdu/sids/page"))[1];
					line3l = echoSids(getprop("/instrumentation/cdu/sids/page"))[2];
					line4l = echoSids(getprop("/instrumentation/cdu/sids/page"))[3];
					line5l = echoSids(getprop("/instrumentation/cdu/sids/page"))[4];
				}else{
					line1l = echoSids(getprop("/instrumentation/cdu/sids/page"), getprop("/autopilot/route-manager/departure/newrunway"))[0];
					line2l = echoSids(getprop("/instrumentation/cdu/sids/page"), getprop("/autopilot/route-manager/departure/newrunway"))[1];
					line3l = echoSids(getprop("/instrumentation/cdu/sids/page"), getprop("/autopilot/route-manager/departure/newrunway"))[2];
					line4l = echoSids(getprop("/instrumentation/cdu/sids/page"), getprop("/autopilot/route-manager/departure/newrunway"))[3];
					line5l = echoSids(getprop("/instrumentation/cdu/sids/page"), getprop("/autopilot/route-manager/departure/newrunway"))[4];
				}
			}else{
				line1cl = selOrAct;
				line1l = getprop("/autopilot/route-manager/departure/sidID");
				line2l = "";
				line3l = "";
				line4l = "";
				line5l = "";
			}

			if (getprop("/autopilot/route-manager/departure/newrunway") == ""){
				setprop("/instrumentation/cdu/sids/rwyIsSelected", 0);
				setprop("/instrumentation/cdu/sids/sidIsSelected", 0);
				setprop("/autopilot/route-manager/departure/sidID", "");
				setprop("/autopilot/route-manager/departure/newsid", "");
			}else{
				if(getprop("/instrumentation/cdu/sids/rwyIsSelected") == 0){
					if(getprop("/instrumentation/cdu/output/line1/right") == getprop("/autopilot/route-manager/departure/newrunway")){
						line1cr = selOrAct;
					}else if(getprop("/instrumentation/cdu/output/line2/right") == getprop("/autopilot/route-manager/departure/newrunway")){
						line2cr = selOrAct;
					}else if(getprop("/instrumentation/cdu/output/line3/right") == getprop("/autopilot/route-manager/departure/newrunway")){
						line3cr = selOrAct;
					}else if(getprop("/instrumentation/cdu/output/line4/right") == getprop("/autopilot/route-manager/departure/newrunway")){
						line4cr = selOrAct;
					}else if(getprop("/instrumentation/cdu/output/line5/right") == getprop("/autopilot/route-manager/departure/newrunway")){
						line5cr = selOrAct;
					}
				}
			}

			if(getprop("/instrumentation/cdu/sids/rwyIsSelected") == 0){
				line1cr = "";
				line1r = echoRwys(getprop("/instrumentation/cdu/sids/page"))[0];
				line2r = echoRwys(getprop("/instrumentation/cdu/sids/page"))[1];
				line3r = echoRwys(getprop("/instrumentation/cdu/sids/page"))[2];
				line4r = echoRwys(getprop("/instrumentation/cdu/sids/page"))[3];
				line5r = echoRwys(getprop("/instrumentation/cdu/sids/page"))[4];
			}else{
				line1cr = selOrAct;
				line1r = getprop("/autopilot/route-manager/departure/newrunway");
				line2r = "";
				line3r = "";
				line4r = "";
				line5r = "";
			}
			line6ct = "----------------------------------------";
			line1rt = "RUNWAYS";
			#if (getprop("/autopilot/route-manager/departure/newrunway") != nil){
			#	line1r = getprop("/autopilot/route-manager/departure/newrunway");
			#}
			#line2lt = "TRANS";
			#if(getprop("/autopilot/route-manager/departure/newsid") != nil){
			#	line6l = "<ERASE";
			#}else{
			#	line6l = "<INDEX";
			#}
			line6r = "ROUTE>";
		}
		if (display == "RTE1_LEGS") {

		}

		if (display == "THR_LIM") {

			title = "THRUST LIM";
			line1lt = "SEL";
			line1ct = "OAT";
			line1c = sprintf("%2.0f", getprop("/environment/temperature-degc"))~"*c";
			line1rt = "TO 1 N1";
			line2l = "<TO";
			line2r = "CLB>";
			line3lt = "TO 1";
			line3l = "<-10%";
			line3r = "CLB 1>";
			line4lt = "TO 2";
			line4l = "<-20%";
			line4r = "CLB 2>";
			line6l = "<INDEX";
			line6r = "TAKEOFF>";
			if (getprop("/instrumentation/fmc/THRLIM") == "TOGA"){line2cl = "<SEL>";}
			else if (getprop("/instrumentation/fmc/THRLIM") == "TO-1"){line3cl = "<SEL>";}
			else if (getprop("/instrumentation/fmc/THRLIM") == "TO-2"){line4cl = "<SEL>";}
			if (getprop("/instrumentation/fmc/CLB_LIM") == "CLB"){line2cr = "<SEL>";}
			else if (getprop("/instrumentation/fmc/CLB_LIM") == "CLB-1"){line3cr = "<SEL>";}
			else if (getprop("/instrumentation/fmc/CLB_LIM") == "CLB-2"){line4cr = "<SEL>";}
		}
		if (display == "TO_REF") {

			title = "TAKEOFF REF";
			page = "1/2";

			line6ct = "----------------------------------------";
			line6l = "<INDEX";
			line6r = "POS INIT>";
		}
		if (display == "TO_REF_2"){

			title   = "TAKEOFF REF UPLINK";

			line6ct = "----------------------------------------";
			line6l = "<INDEX";
		}
		if (display == "VNAV") {
			#TODO:Change the page name to sth like "VNAV_CLB" or "VNAV_1".
			var ACTorMOD = "MOD";
			if(getprop("/instrumentation/fmc/VNAV/isChanged") == 0){
				ACTorMOD = "MOD";
			}else{
				ACTorMOD = "ACT";
			}

			var climbSpdMode = "ECON";

			#TODO:To make it actually work._by 0762
			#• ACT ECON CLB      —速度以成本指数为依据
			#• ACT MCP SPD CLB   —表示选择了MCP 速度干预
			#• ACT XXXKT CLB     –选择了固定CAS 爬升速度
			#• ACT M.XXX CLB     –选择了固定马赫爬升速度
			#• ACT LIM SPD CLB   –速度基于包线限制速度

			title   = ACTorMOD~" "~climbSpdMode~" "~"CLB";
			page = "1/3";
			line1lt = "CRZ ALT";
			line1l  = isFLinit();
			line2lt = "ECON SPD";
			line2l  = "INOP"; #TODO:仍然不知道算法
			line3lt = "SPD TRANS";#速度过渡
			line3l  = sprintf("%2.0f",getprop("/instrumentation/fmc/VNAV/XTransSPD"))~"/"~sprintf("%.0f",getprop("/instrumentation/fmc/VNAV/XTransALT"));
			line4lt = "SPD RESTR";#低于此巡航高度的高度速度限制
			line4l  = sprintf("%2.0f",getprop("/instrumentation/fmc/VNAV/RestrSPD"))~"/"~sprintf("%.0f",getprop("/instrumentation/fmc/VNAV/RestrALT"));

			line1rt = "AT"~"";#下一个航点的限高、限速
			line1r  = "WIP";
			line2rt = "ERROR";#误差，如果没有误差的话是没有显示的，所以我懒得做233
			line2r  = "WIP";
			line3rt = "TRANS ALT";
			line3r  = sprintf("%2.0f",getprop("/instrumentation/fmc/VNAV/TransALT"));#Todo:未制作输入_by 0762
			line4rt = "MAX ANGLE";#显示爬升速度的最大角度,不允许输入.
			line4r  = "215";  #算法不明，先留着以后做

			line5ct = "----------------------------------------";

			line5l  = "<ECON";
			line5r  = "ENG OUT>";
			line6r  = "CLB DIR>";
		}
		if (display == "FMC_COMM") {

			title  = "FMC COMM";
			line1l = "<RTE 1";
			line2l = "<ALTN";
			line3l = "<PERF";
			line4l = "<TAKEOFF";
			line5l = "<WIND";
			line6l = "<DES FORECAST";
			line1r = "POS REPORT>";
			line6rt = "DATA LINK";
			line6r = datalink.aircraft1.states; # data link currently not stable


		}
		if (display == "ALTN"){

			nApts = findAirportsWithinNumber(4);

		    title   = "ALTN";
		    page    = "1/2";
		    line1l  = nApts[0].id;
		    line2l  = nApts[1].id;
		    line3l  = nApts[2].id;
		    line4l  = nApts[3].id;

			if (getprop("/instrumentation/fmc/sltd-ALTN") == 1)
			{line1cl = "<SEL>";}
			else if (getprop("/instrumentation/fmc/sltd-ALTN") == 2)
			{line2cl = "<SEL>";}
			else if (getprop("/instrumentation/fmc/sltd-ALTN") == 3)
			{line3cl = "<SEL>";}
			else if (getprop("/instrumentation/fmc/sltd-ALTN") == 4)
			{line4cl = "<SEL>";}

			for(var i = 0; i < datalink.allAircrafts[0].dataNum; i = i + 1){
				if(datalink.allAircrafts[0].dataName[i] == "ALTN" and datalink.allAircrafts[0].data[i]!=nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id){
					datalink.allAircrafts[0].data[i] = nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id;
					AltnHaveSaved2Datalink = 1;
					print("ALTN SAVED 1 "~nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id);
				}
			}
			if(AltnHaveSaved2Datalink == 0){
				append(datalink.allAircrafts[0].data, nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id);
				append(datalink.allAircrafts[0].dataName, "ALTN");
				datalink.allAircrafts[0].dataNum+=1;
				print("ALTN SAVED 2 "~nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id);
				AltnHaveSaved2Datalink = 1;
			}
		    line5lt = "ALTN";
		    line5l  = "<REQUEST";
		    line6lt = "WXR";
		    line6l  = datalink.allAircrafts[0].requestState;
		    line5rt = "ALTN INHIBIT";
		    line5r  = "----/----";
		    line6rt = nApts[getprop("/instrumentation/fmc/sltd-ALTN")-1].id;
		    line6r  = "DIVERT NOW>";
		}
		if(display == "ALTN_LIST"){

			altnApts = findAirportsWithinNumber(16);

            title = "ALTN LIST";
			page = "2/2";

            line1l      = altnApts[0].id;
            line1cl     = altnApts[1].id;
            line1cr     = altnApts[2].id;
            line1r      = altnApts[3].id;
            line2l      = altnApts[4].id;
            line2cl     = altnApts[5].id;
            line2cr     = altnApts[6].id;
            line2r      = altnApts[7].id;
            line3l      = altnApts[8].id;
            line3cl     = altnApts[9].id;
            line3cr     = altnApts[10].id;
            line3r      = altnApts[11].id;
            line4l      = altnApts[12].id;
            line4cl     = altnApts[13].id;
            line4cr     = altnApts[14].id;
            line4r      = altnApts[15].id;
			line5lt     = "ALTN LIST";
			line5l		= "<REQUEST";
			line5rt		= "ALTN LIST";
			line5r		= "PURGE>";
			line6l		= "<INDEX";
		}

		if (serviceable != 1){

			title    = "";	page    = "";
			line1l   = "";	line2l  = "";	line3l  = "";	line4l  = "";	line5l  = "";	line6l  = "";
			line1lt  = "";	line2lt = "";	line3lt = "";	line4lt = "";	line5lt = "";	line6lt = "";
			line1c   = "";	line2c  = "";	line3c  = "";	line4c  = "";	line5c  = "";	line6c  = "";
			line1ct  = "";	line2ct = "";	line3ct = "";	line4ct = "";	line5ct = "";	line6ct = "";
			line1r   = "";	line2r  = "";	line3r  = "";	line4r  = "";	line5r  = "";	line6r  = "";
			line1rt  = "";	line2rt = "";	line3rt = "";	line4rt = "";	line5rt = "";	line6rt = "";
			line1ctl = "";

			line1cl = "";
			line1cr = "";
			line2cl = "";
			line2cr = "";
			line3cl = "";
			line3cr = "";
			line4cl = "";
			line4cr = "";
			line5cr = "";
			line5cl = "";
			line6cr = "";
			line6cl = "";
			cduDisplayRefresh();
			print("CDU Powered OFF");
			cduTimer.stop();

		}

		cduDisplayRefresh();


}

var cduTimer = maketimer(0.2, cdu);
var cduPowerOnOff = func(){
	if(getprop("/instrumentation/cdu/serviceable") == 1){
		cduInitialize();
		cduTimer.start();
		print("CDU Powered ON");
	}
}
cduPowerOnOff();

setlistener("/instrumentation/cdu/serviceable", cduPowerOnOff);

#_setlistener("/sim/signals/fdm-initialized", cdu);
