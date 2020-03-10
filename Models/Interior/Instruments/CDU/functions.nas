####################################
#   _____ ____ ____  ____   ____   # 
#  |  ___/ ___|  _ \|  _ \ / ___|  #
#  | |_ | |  _| |_) | |_) | |      #
#  |  _|| |_| |  __/|  _ <| |___   #
#  |_|   \____|_|   |_| \_\\____|  #
#							       #
####################################

var echoAppr = func(page,selectedRwy = ""){
	var dest = getprop("/autopilot/route-manager/destination/airport");
	var apt = airportinfo(dest);
	if(dest != ""){
		var allAppr = apt.getApproachList();
		var defaultNum = size(keys(apt.runways));
		var echoedAppr = [];
		var allRwys = keys(apt.runways);
		var echoedRwys = [];
		var rwysTotal = size(allRwys);
		var i = 0;
		var apprNum = size(allAppr);
		var countEnd = 0;
		if(apprNum != 0){
			var countStart = (page - 1) * 5;
			if(countStart > apprNum){
				#setprop("/instrumentation/cdu/appr/page", page - 1);
			}
			count = countStart;
			while(i <= 5){
				if(count <= apprNum-1){
					append(echoedAppr, allAppr[count]);
					i = i + 1;
					count = count + 1;
				}else{
					countEnd = i + 1;
					setprop("/instrumentation/cdu/appr/apprCountEndPage", page);
					var j = i;
					while(j <= 5){
						append(echoedAppr, "");
						j+=1;
					}
					i = 6;
				}
			}
		}else{
			var countStart = (page - 1) * 5;
			if(countStart > apprNum){
				setprop("/instrumentation/cdu/appr/page", page - 1);
			}
			count = countStart;
			while(i <= 5){
				if(count < defaultNum){
					append(echoedAppr, "DEFAULT");
					i = i + 1;
					count = count + 1;
				}else{
					countEnd = i + 1;
					setprop("/instrumentation/cdu/appr/apprCountEndPage", page);
					var j = i;
					while(j <= 5){
						append(echoedAppr, "");
						j+=1;
					}
					i = 6;
				}
			}
		}
				
				
		setprop("/instrumentation/cdu/appr/apprCountEnd", countEnd);		
				
		return echoedAppr;			
			
	}else{
		return ["", "", "", "", ""];
	}
}

var echoRwysAppr = func(pageRwys){
	if(getprop("/autopilot/route-manager/destination/airport") != ""){
		var apt = airportinfo(getprop("/autopilot/route-manager/destination/airport"));
		var allRwys = keys(apt.runways);
		var echoedRwys = [];
		var rwysCount = size(allRwys);
		var listStart = getprop("/instrumentation/cdu/appr/apprCountEnd");
		pageRwys = (pageRwys - getprop("/instrumentation/cdu/appr/apprCountEndPage"))+1;
		var countStart = (pageRwys - 1) * 5;
		var count = countStart;
		
		var i = 0;
		var tag = 5 - listStart;
		if(countStart != 0){
			tag = 5;
		}
		while(i <= tag){
			if(count < rwysCount){
				append(echoedRwys, allRwys[count]);
				i = i + 1;
				count = count + 1;
			}else{
				append(echoedRwys, "");
				i = i + 1;
				setprop("/instrumentation/cdu/appr/rwyCountLastPage", pageRwys);
			}
		}
		
		return echoedRwys;
	}else{
		return ["", "", "", "", ""];
	}
}

var arrNextPge = func(){
	var tmp = getprop("/instrumentation/cdu/appr/page");
	if(tmp + 1 <= getprop("/instrumentation/cdu/appr/rwyCountLastPage")){
		tmp = tmp + 1;
		setprop("/instrumentation/cdu/appr/page", tmp);
	}
}
var arrPrevPge = func(){
	var tmp = getprop("/instrumentation/cdu/appr/page");
	if(tmp - 1 >= 1){
		tmp = tmp - 1;
	}
	setprop("/instrumentation/cdu/appr/page", tmp);
}

###########################################################

var getRwyOfSids = func(sidID){
	var apt = airportinfo(getprop("/autopilot/route-manager/departure/airport"));
	var allRwys = keys(apt.runways);
	if(sidID != "DEFAULT"){
		var rwysCount = size(allRwys);
		for(var i = 0; i < rwysCount; i+=1){
			var allSids = apt.sids(allRwys[i]);
			for(var j = 0; j < size(allSids); j+=1){
				if(sidID == allSids[j]){
					return allRwys[i];
					}
				}
			}
		}else{
			if(getprop("/autopilot/route-manager/departure/newrunway") == ""){
				return allRwys[0];
			}else if(getprop("/autopilot/route-manager/departure/newrunway") == nil){
				return allRwys[0];
			}else{
				return getprop("/autopilot/route-manager/departure/newrunway");
			}
		}
}
var findAirportsWithinNumber = func(num)
{
	var range = 10;
	var nApts = findAirportsWithinRange(range);

	while(size (nApts) <= num)
	{
			range = range + 10;
			nApts = findAirportsWithinRange(range);
	}
		return nApts;	
}
#nApts = findAirportsWithinNumber(4);
#print(nApts[0].id);
var echoSids = func(page,selectedRwy = ""){
	var apt = airportinfo(getprop("/autopilot/route-manager/departure/airport"));
	if(getprop("/autopilot/route-manager/departure/airport") != ""){
		if(selectedRwy != ""){
			var allSids = apt.sids(selectedRwy);
			var defaultNum = 1;
		}else{
			var allSids = apt.sids();
			var allSids = apt.sids();
			var defaultNum = size(keys(apt.runways));
		}
		var echoedSids = [];
		var i = 0;
		var sidsNum = size(allSids);
		if(sidsNum != 0){
			var countStart = (page - 1) * 5;
			if(countStart > sidsNum){
				setprop("/instrumentation/cdu/sids/page", page - 1);
			}
			count = countStart;
			while(i <= 5){
				if(count <= sidsNum-1){
					append(echoedSids, allSids[count]);
					i = i + 1;
					count = count + 1;
				}else{
					append(echoedSids, "");
					i = i + 1;
				}
			}
		}else{
			var countStart = (page - 1) * 5;
			if(countStart > sidsNum){
				setprop("/instrumentation/cdu/sids/page", page - 1);
			}
			count = countStart;
			while(i <= 5){
				if(count < defaultNum){
					append(echoedSids, "DEFAULT");
					i = i + 1;
					count = count + 1;
				}else{
					append(echoedSids, "");
					i = i + 1;
				}
			}
		}
				return echoedSids;
			}else{
				return ["", "", "", "", ""];
			}
}
var echoRwys = func(pageRwys){
	if(getprop("/autopilot/route-manager/departure/airport") != ""){
		var apt = airportinfo(getprop("/autopilot/route-manager/departure/airport"));
		var allRwys = keys(apt.runways);
		var echoedRwys = [];
		var rwysCount = size(allRwys);
	
		    var countStart = (pageRwys - 1) * 5;
			var count = countStart;
			var i = 0;
			while(i <= 5){
				if(count < rwysCount){
					append(echoedRwys, allRwys[count]);
					i = i + 1;
					count = count + 1;
				}else{
						append(echoedRwys, "");
						i = i + 1;
				}
			}
				return echoedRwys;
		}else{
			return ["", "", "", "", ""];
		}
}

var getIRSPos = func(cduInputedPos){
 
 	call(func inputPosLatConversion(cduInputedPos), nil, var err = []);
	if(size(err)){
		setprop("/instrumentation/cdu/input", "INVALID ENTRY");
	}else{
		setprop("/instrumentation/fmc/inertialposlat", inputPosLatConversion(cduInputedPos));
	}
	
	call(func inputPosLonConversion(cduInputedPos), nil, var err1 = []);
	if(size(err1)){
		setprop("/instrumentation/cdu/input", "INVALID ENTRY");
	}else{
		setprop("/instrumentation/fmc/inertialposlon", inputPosLonConversion(cduInputedPos));
	}
	setprop("/instrumentation/fmc/inertialpos", latdeg2latDMM(getprop("/instrumentation/fmc/inertialposlat"))~" "~londeg2lonDMM(getprop("/instrumentation/fmc/inertialposlon")));
}
var getGpsPos = func(){
	var gpsPosGot = latdeg2latDMM(getprop("/position/latitude-deg"))~" "~londeg2lonDMM(getprop("/position/longitude-deg"));
	setprop("/instrumentation/fmc/gpspos", gpsPosGot);
	setprop("/instrumentation/fmc/gpsposlat", getprop("/position/latitude-deg"));
	setprop("/instrumentation/fmc/gpsposlon", getprop("/position/longitude-deg"));
	return gpsPosGot;
}
var getLastPos = func(){
	setprop("/instrumentation/fmc/lastposlat", getprop("/position/latitude-deg"));
	setprop("/instrumentation/fmc/lastposlon", getprop("/position/longitude-deg"));
	var lastPosGot = latdeg2latDMM(getprop("/position/latitude-deg"))~" "~londeg2lonDMM(getprop("/position/longitude-deg"));
	setprop("/instrumentation/fmc/lastpos", lastPosGot);
	return lastPosGot;
}

var execPushed = func(){
	if (getprop("/autopilot/route-manager/isArmed") == 1){
		if(getprop("/autopilot/route-manager/destination/newApproach") != nil){
			setprop("/autopilot/route-manager/destination/approach", getprop("/autopilot/route-manager/destination/newApproach"));
		}
		setprop("/autopilot/route-manager/isChanged",0);
		setprop("/autopilot/route-manager/input","@ACTIVATE");
		setprop("/autopilot/route-manager/isArmed", -1);
	}
	if (getprop("/instrumentation/fmc/VNAV/isChanged") == 0){
		setprop("/autopilot/route-manager/cruise/altitude-FL", getprop("/instrumentation/fmc/VNAV/cruise/altitude-FL"));
		setprop("/autopilot/route-manager/cruise/altitude-ft", getprop("/instrumentation/fmc/VNAV/cruise/altitude-ft"));
		setprop("/autopilot/settings/transition-altitude", getprop("/instrumentation/fmc/VNAV/TransALT"));
		setprop("/instrumentation/fmc/VNAV/isChanged", 1);
	}
}

var sidNextPge = func(){
	var tmp = getprop("/instrumentation/cdu/sids/page");
	tmp = tmp + 1;
	setprop("/instrumentation/cdu/sids/page", tmp);
}
var sidPrevPge = func(){
	var tmp = getprop("/instrumentation/cdu/sids/page");
	if(tmp - 1 >= 1){
		tmp = tmp - 1;
	}
	setprop("/instrumentation/cdu/sids/page", tmp);
}

var DisplayLATorBRG = func(){
	if (getprop("/instrumentation/cdu/LATorBRG") == 0){
		return "LAT/LON>";
	}
	else{
		return "BRG/DIST>";
	}
}
var echoLatBrg = func(){
	if(getprop("/instrumentation/cdu/LATorBRG") == 1){
		return getGpsPos();
	}
	else if(getprop("/instrumentation/cdu/LATorBRG") == 0){
		return "000*/0.0NM";
	}
}

var isUpdateArm = func(){
	if (getprop("/instrumentation/cdu/isARMED") == 0)
	{
		return "ARM";
	}
	else if(getprop("/instrumentation/cdu/isARMED") == 1)
	{
		return "ARMED";
	}
}
var echoUpdateArmed = func(){
	if (getprop("/instrumentation/cdu/isARMED") == 0)
	{
		return " ";
	}
	else if (getprop("/instrumentation/cdu/isARMED") == 1)
	{
		return "NOW>"
	}
}

var crzAltCDUInput = func(){
	var cduInput   = getprop("/instrumentation/cdu/input");
	var msg        = getprop("/instrumentation/fmc/isMsg"); 
	if (find("FL", cduInput) != -1){
		if (size(cduInput) <=5 ){
			if (num(substr(cduInput,2,size(cduInput))) != nil){
				if (substr(cduInput,2,size(cduInput)) >= 100){
					if (substr(cduInput,2,size(cduInput)) <= 412){
						setprop("/instrumentation/fmc/VNAV/cruise/altitude-FL",cduInput);
						setprop("/instrumentation/fmc/VNAV/cruise/altitude-ft",FL2feet(cduInput));
						cduInput = "";
					}else{
						cduInput = "INVALID ENTRY";
						msg = 1;
					}
				}else{
					cduInput = "INVALID ENTRY";
					msg = 1;
				}
			}
		} else {
			cduInput = "INVALID ENTRY";
			msg = 1;
		}
	
	} else if (find("FL", cduInput) == -1){
	
		if (num(cduInput) != nil){
			if (cduInput >= 1000){
			
				if (cduInput < 10000){
					setprop("/instrumentation/fmc/VNAV/cruise/altitude-ft",cduInput);
					setprop("/instrumentation/fmc/VNAV/cruise/altitude-FL",feet2FL(cduInput));
					cduInput = "";
				} else if (cduInput >= 10000){
				
					if (cduInput <= 41200){
						setprop("/instrumentation/fmc/VNAV/cruise/altitude-ft",cduInput);
						setprop("/instrumentation/fmc/VNAV/cruise/altitude-FL",feet2FL(cduInput));
						cduInput = "";
					}else if(cduInput >= 10){
						if (cduInput <= 412){
							setprop("/instrumentation/fmc/VNAV/cruise/altitude-FL","FL"~cduInput);
							setprop("/instrumentation/fmc/VNAV/cruise/altitude-ft",int(cduInput~"00"));
							cduInput = "";
						}else{
							cduInput = "INVALID ENTRY";

						}
					}else{
							cduInput = "INVALID ENTRY";
						}
					}
				
				}else{
						cduInput = "INVALID ENTRY";
						}
			
			}else{ 
				#else for "num(cduInput) != nil"
				cduInput = "INVALID ENTRY";
			}
		}else{
			#else for "find("FL", cduInput) == -1"
			cduInput = "INVALID ENTRY";
			}
			 
		return cduInput;
}

var findPosWithGate = func(gateName,airport){
	#Done by Sidi Liang ---0762
	#gateName\airport are string
	#Currently only supports airports downloaded by Terrasync or custom scenery added by launcher or commandlines.
	#Supports the airports which parking in groundnet was formatted as "name" or "name"+"number".
	#Behaviour: Write the coordinate to the property tree if the gate was found in scenery that was supported(see above), and the gate number will be displayed in the CDU.  
	#			Return 404 if groundnet file or requested gate weren't found.
	var firstLetter = utf8.chstr(airport[0]);
	var secLetter = utf8.chstr(airport[1]);
	var thirdLetter = utf8.chstr(airport[2]);

	var groundNetData = io.read_airport_properties(airport, "groundnet"); 
	var parkingListData = nil;
	var groundNetDataGot = 0;
	var gateGot = 0;
	if(groundNetData == nil){

		if(getprop("sim/fg-scenery")!=nil){
			var getGroundNetDataAttempt = call(func io.readxml(getprop("/sim/fg-scenery") ~ '/Airports/'~firstLetter~'/'~secLetter~'/'~thirdLetter~'/'~airport~'.groundnet.xml'), nil, var err = []);
			if (size(err)){
				groundNetData = nil;
			}else{
				groundNetData = io.readxml(getprop("/sim/fg-scenery") ~ '/Airports/'~firstLetter~'/'~secLetter~'/'~thirdLetter~'/'~airport~'.groundnet.xml');
			}
			if(groundNetData != nil){
				parkingListData = groundNetData.getNode("groundnet/parkingList");
				#props.dump(parkingListData); # dump groundNetData
				groundNetDataGot = 1;
			}
		
			if(!groundNetDataGot){
				var i_scenery = 1;
				while(getprop("sim/fg-scenery["~i_scenery~"]") != nil){
					var getGroundNetDataAttempt = call(func io.readxml(getprop("sim/fg-scenery["~i_scenery~"]") ~ '/Airports/'~firstLetter~'/'~secLetter~'/'~thirdLetter~'/'~airport~'.groundnet.xml'), nil, var err = []);
					if (size(err)){
						groundNetData = nil;
					}else{
						groundNetData = io.readxml(getprop("sim/fg-scenery["~i_scenery~"]") ~ '/Airports/'~firstLetter~'/'~secLetter~'/'~thirdLetter~'/'~airport~'.groundnet.xml');
					}
					if(groundNetData != nil){
						groundNetDataGot = 1;
						parkingListData = groundNetData.getNode("groundnet/parkingList");
						#props.dump(parkingListData); # dump groundNetData
						break;
					}
					i_scenery += 1;
				}
			}
	
		}
	}else{
		#props.dump(groundNetData); # dump groundNetData
		parkingListData = groundNetData.getNode("groundnet/parkingList");
		groundNetDataGot = 1;
	}

	if(groundNetDataGot){
		var getGateName = parkingListData.getNode("Parking").getValue("___name");
		if(parkingListData.getNode("Parking").getValue("___number") != nil){
			getGateName = getGateName ~ parkingListData.getNode("Parking").getValue("___number");#Add support to the name+number format type of groundnet file.
		}
		if(getGateName == gateName){
			#print(gateName);
			var lat = parkingListData.getNode("Parking").getValue("___lat");
			var lon = parkingListData.getNode("Parking").getValue("___lon");
			print(lat);
			print(lon);
			gateGot = 1;
		}else{
			var i_Parking = 0;
			while(parkingListData.getNode("Parking["~i_Parking~"]") != nil){
				getGateName = parkingListData.getNode("Parking["~i_Parking~"]").getValue("___name");
				if(parkingListData.getNode("Parking["~i_Parking~"]").getValue("___number") != nil){
					getGateName = getGateName ~ parkingListData.getNode("Parking["~i_Parking~"]").getValue("___number");#Add support to the name+number format type of groundnet file.
				}
				if(getGateName == gateName){
					#print(gateName);
					var lat = parkingListData.getNode("Parking").getValue("___lat");
					var lon = parkingListData.getNode("Parking").getValue("___lon");
					print(lat);
					print(lon);
					var latOutput = "";
					var lonOutput = "";
					var latOutput1 = "";#擦写板格式
					var lonOutput1 = "";
					var nOrS = utf8.chstr(lat[0]);
					var eOrW = utf8.chstr(lon[0]);
					var latpointer = 0;
					var lonpointer = 0;
					latOutput = latOutput ~ nOrS;
					lonOutput = lonOutput ~ eOrW;
					latOutput1 = latOutput1 ~ nOrS;
					lonOutput1 = lonOutput1 ~ eOrW;
					if(utf8.chstr(lat[3]) == " "){
						latOutput = latOutput~utf8.chstr(lat[1])~utf8.chstr(lat[2])~"*";
						latOutput1 = latOutput1~utf8.chstr(lat[1])~utf8.chstr(lat[2]);
						latpointer = 4;
					}else{
						latOutput = latOutput~"0"~utf8.chstr(lat[1])~"*";
						latOutput1 = latOutput1~"0"~utf8.chstr(lat[1]);
						latpointer = 3;
					}
					if(utf8.chstr(lon[2]) == " "){
						lonOutput = lonOutput~"0"~utf8.chstr(lon[1])~"*";
						lonOutput1 = lonOutput1~"0"~utf8.chstr(lon[1]);
						lonpointer = 3;
					}else if(utf8.chstr(lon[3]) == " "){
						lonOutput = lonOutput~utf8.chstr(lon[1])~utf8.chstr(lon[2])~"*";
						lonOutput1 = lonOutput1~utf8.chstr(lon[1])~utf8.chstr(lon[2]);
						lonpointer = 4;
					}else{
						lonOutput = lonOutput~utf8.chstr(lon[1])~utf8.chstr(lon[2])~utf8.chstr(lon[3])~"*";
						lonOutput1 = lonOutput1~utf8.chstr(lon[1])~utf8.chstr(lon[2])~utf8.chstr(lon[3]);
						lonpointer = 5;
					}
					
					if(utf8.chstr(lat[latpointer+1]) == "."){
						latOutput = latOutput ~ "0"~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]);
						latOutput1 = latOutput1 ~ "0"~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]);
					}else if(utf8.chstr(lat[latpointer+2]) == "."){
						latOutput = latOutput ~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]) ~ utf8.chstr(lat[latpointer+3]);
						latOutput1 = latOutput1 ~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]) ~ utf8.chstr(lat[latpointer+3]);
					}else if(utf8.chstr(lat[latpointer+3]) == "."){
						latOutput = latOutput ~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]) ~ utf8.chstr(lat[latpointer+3]) ~ utf8.chstr(lat[latpointer+4]);
						latOutput1 = latOutput1 ~ utf8.chstr(lat[latpointer]) ~ utf8.chstr(lat[latpointer+1]) ~ utf8.chstr(lat[latpointer+2]) ~ utf8.chstr(lat[latpointer+3]) ~ utf8.chstr(lat[latpointer+4]);
					}
					
					if(utf8.chstr(lon[lonpointer+1]) == "."){
						lonOutput = lonOutput ~ "0"~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]);
						lonOutput1 = lonOutput1 ~ "0"~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]);
					}else if(utf8.chstr(lon[lonpointer+2]) == "."){
						lonOutput = lonOutput ~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]) ~ utf8.chstr(lon[lonpointer+3]);
						lonOutput1 = lonOutput1 ~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]) ~ utf8.chstr(lon[lonpointer+3]);
					}else if(utf8.chstr(lat[lonpointer+3]) == "."){
						lonOutput = lonOutput ~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]) ~ utf8.chstr(lon[lonpointer+3]) ~ utf8.chstr(lon[lonpointer+4]);
						lonOutput1 = lonOutput1 ~ utf8.chstr(lon[lonpointer]) ~ utf8.chstr(lon[lonpointer+1]) ~ utf8.chstr(lon[lonpointer+2]) ~ utf8.chstr(lon[lonpointer+3]) ~ utf8.chstr(lon[lonpointer+4]);
					}
					setprop("instrumentation/fmc/gate-pos-lat-str",latOutput);
					setprop("instrumentation/fmc/gate-pos-lon-str",lonOutput);
					setprop("instrumentation/fmc/gate-pos-lat-noformat",latOutput1);
					setprop("instrumentation/fmc/gate-pos-lon-noformat",lonOutput1);
		
		
					gateGot = 1;
					break;
				}
				i_Parking += 1;
			}
		}
		if(!gateGot){
			return 404;#Gate Not Found
		}
	}else{
		return 404;#Groundnet Data Not Found
	}
}


