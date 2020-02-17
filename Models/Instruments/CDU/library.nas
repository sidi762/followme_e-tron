####################################
#   _____ ____ ____  ____   ____   # 
#  |  ___/ ___|  _ \|  _ \ / ___|  #
#  | |_ | |  _| |_) | |_) | |      #
#  |  _|| |_| |  __/|  _ <| |___   #
#  |_|   \____|_|   |_| \_\\____|  #
#							       #
####################################


var decimal2percentage = func(decimal){
	var TMP = decimal * 100;
	var tmp = " "~TMP;#convert to string
	var percentage = substr(tmp,0,4)~"%";
	return percentage;
}

var feet2FL = func(feet){
	var tmp = "";
	var FL = "";
	var offset = 0;
	tmp = "FL"~feet;
		if (feet < 10000){offset = 4}
		else{offset = 5}
		FL = left(tmp,offset);
	return FL;
}
var FL2feet = func(FL){
	var tmp = "";
	var feet = 0;
	var offset = 0;
	if (size(FL) == 4){tmp = 2}
	else{offset = 3}
	tmp = right(FL,offset);
	feet = int(tmp~"00");
	return feet;
}

var lbs2tons = func(lbs){
	var tons = lbs * 0.0005;
	return tons;
}
var lbs2kg = func(lbs){
	var tons = lbs * 0.0005;
	var kg = tons * 1000;
	return kg;
}

var inputPosLatConversion = func(inputedPos){
	var isNorth = 1;
	
	if(find("N", inputedPos) != -1){
		isNorth = 1;
	}else{
		isNorth = 0;
	}
	
	var outputLat = string.trim(string.trim(string.trim(string.trim(inputedPos, 1, string.isdigit), 1, string.ispunct), 1, string.isdigit), 1, string.isalpha);
	var outputLatMin = string.trim(right(outputLat, 4));
	var outputLatMinInDeg = outputLatMin/60;
	var outputLatDeg = (substr(outputLat, 1, size(outputLat) - 5)) + outputLatMinInDeg;
	if(isNorth != 1){
		outputLatDeg = outputLatDeg * -1;
	}
	#print(outputLat);
	#print(outputLatDeg);
	return(outputLatDeg);
}
var inputPosLonConversion = func(inputedPos){
	var isEast = 1;
	
	if(find("E", inputedPos) != -1){
		isEast = 1;
	}else{
		isEast = 0;
	}
	
	var outputLon = string.trim(string.trim(string.trim(string.trim(inputedPos, -1, string.isalpha), -1, string.isdigit), -1, string.ispunct), -1, string.isdigit);
	var outputLonMin = string.trim(right(outputLon, 4));
	var outputLonMinInDeg = outputLonMin/60;
	var outputLonDeg = (substr(outputLon, 1, size(outputLon) - 5)) + outputLonMinInDeg;
	if(isEast != 1){
		outputLonDeg = outputLonDeg * -1;
	}
	#print(outputLon);
	#print(outputLonDeg);
	return(outputLonDeg);
}

var LatDMMunsignal = func(LatDeg){
	var latdegree_INIT = int(LatDeg);
	var latminint_INIT = int((LatDeg - latdegree_INIT) * 60);
	var latmindouble_INIT = int((((LatDeg - latdegree_INIT) * 60) - latminint_INIT) * 10);
	if(latminint_INIT < 10){
		var outlatminint_INIT = "0"~abs(latminint_INIT);
	}else{
		var outlatminint_INIT = abs(latminint_INIT);
	}
	var latmin_INIT = outlatminint_INIT~"."~abs(latmindouble_INIT);
	var isNS_INIT = "N";
	if(LatDeg > 0){
			isNS_INIT = "N";
	}else{
			isNS_INIT = "S";
	}
	if(latdegree_INIT < 10){
		var outlatdegree_INIT = "0"~abs(latdegree_INIT);
	}else{
		var outlatdegree_INIT = abs(latdegree_INIT);
	}
		var latresults_INIT = isNS_INIT~outlatdegree_INIT~""~latmin_INIT;
		return latresults_INIT;
}
var LonDmmUnsignal = func(LonDeg){
	var londegree_INIT = int(LonDeg);
	var lonminint_INIT = int((LonDeg - londegree_INIT) * 60);
	var lonmindouble_INIT = int((((LonDeg - londegree_INIT) * 60) - lonminint_INIT) * 10);
	if(lonminint_INIT < 10){
		var outlonminint_INIT = "0"~abs(lonminint_INIT);
	}else{
		var outlonminint_INIT = abs(lonminint_INIT);
	}
	var lonmin_INIT = outlonminint_INIT~"."~abs(lonmindouble_INIT);
	var isEW_INIT = "E";
	if(LonDeg > 0){
		isEW_INIT = "E";
	}else{
		isEW_INIT = "W";
	}
	if(londegree_INIT < 10){
		var outlondegree_INIT = "0"~abs(londegree_INIT);
	}else{
		var outlondegree_INIT = abs(londegree_INIT);
	}
	var lonresults_INIT = isEW_INIT~outlondegree_INIT~lonmin_INIT;
	return lonresults_INIT;
}

var latdeg2latDMM = func(inLatDeg){
		var latdegree_INIT = int(inLatDeg);
		var latminint_INIT = int((inLatDeg - latdegree_INIT) * 60);
		var latmindouble_INIT = int((((inLatDeg - latdegree_INIT) * 60) - latminint_INIT) * 10);
		if(abs(latminint_INIT) < 10){
			var outlatminint_INIT = "0"~abs(latminint_INIT);
		}else{
			var outlatminint_INIT = abs(latminint_INIT);
		}
		var latmin_INIT = outlatminint_INIT~"."~abs(latmindouble_INIT);
		var isNS_INIT = "N";
		if(inLatDeg	> 0){
				isNS_INIT = "N";
		}else{
				isNS_INIT = "S";
		}
		if(abs(latdegree_INIT) < 10){
			var outlatdegree_INIT = "0"~abs(latdegree_INIT);
		}else{
			var outlatdegree_INIT = abs(latdegree_INIT);
		}
		var latresults_INIT = isNS_INIT~outlatdegree_INIT~"*"~latmin_INIT;
		return latresults_INIT;
}
var londeg2lonDMM = func(inLonDeg){
		var londegree_INIT = int(inLonDeg);
		var lonminint_INIT = int((inLonDeg - londegree_INIT) * 60);
		var lonmindouble_INIT = int((((inLonDeg - londegree_INIT) * 60) - lonminint_INIT) * 10);
		if(abs(lonminint_INIT) < 10){
			var outlonminint_INIT = "0"~abs(lonminint_INIT);
		}else{
			var outlonminint_INIT = abs(lonminint_INIT);
		}
		var lonmin_INIT = outlonminint_INIT~"."~abs(lonmindouble_INIT);
		var isEW_INIT = "E";
		if(inLonDeg > 0){
			isEW_INIT = "E";
		}else{
			isEW_INIT = "W";
		}
		if(abs(londegree_INIT) < 10){
			var outlondegree_INIT = "0"~abs(londegree_INIT);
		}else{
			var outlondegree_INIT = abs(londegree_INIT);
		}
		var lonresults_INIT = isEW_INIT~outlondegree_INIT~"*"~lonmin_INIT;
		return lonresults_INIT;
}	
	
	