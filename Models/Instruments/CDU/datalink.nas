################################
#|  ___/ ___|  _ \|  _ \ / ___|#
#| |_ | |  _| |_) | |_) | |	   #
#|  _|| |_| |  __/|  _ <| |___ #
#|_|   \____|_|   |_| \_\\____|#
################################

var serviceable = 1;

if (serviceable == 1){

	var ground = {
		
		ident : 0,
		
		new: func(id) { return { parents:[ground], ident: id}; },
		data : ["Comm Success"],
		dataName: ["testMessage"],
		errorMessage : "Error",
		
		uplink : func(key,target){
			transmit(key, "uplink",me.ident,target);
		},
		downlinkReceived: func(key,from){
			#print(key);
			
			if(findInArray(me.dataName,allAircrafts[from].dataName[key]) == 404){
				append(me.data, allAircrafts[from].data[key]);
				append(me.dataName, allAircrafts[from].dataName[key]);
			}else{
				me.data[findInArray(me.dataName, allAircrafts[from].dataName[key])] = allAircrafts[from].data[key];
			}
			#print("DownlinkReceived, "~allAircrafts[from].dataName[findInArray(allAircrafts[from].dataName, key)]~" is "~allAircrafts[from].data[findInArray(allAircrafts[from].dataName, key)]);#Bugs in this line, I'm too lazy to fix it --- 0762
		},
		requestReceived : func(key,from){
				allAircrafts[from].requestState = "<REQUEST SENT"; 
				print(allAircrafts[from].requestState);
				me.requestRespond(key,from);
		},
		requestRespond : func(key, to){
			if(key == "ALTNWXR"){
				#while(findInArray(me.dataName,"ALTN")==404){
				#	print("Hold on for a sec... Waiting for ALTN APT to be transmit");
				#	#settimer(break,1);
				#}
				#while(me.data[findInArray(me.dataName,"ALTN")] != allAircrafts[0].data[findInArray(allAircrafts[0].dataName,"ALTN")]){ #Commanded because it might cause FG to freeze - 0762
				#	print("Hold on for a sec... Waiting for new ALTN APT to be transmit");
				#}
				if(findInArray(me.dataName,"ALTN")!=404){
					print("Getting WXR for "~me.data[findInArray(me.dataName,"ALTN")]);
					me.getWXR(me.data[findInArray(me.dataName,"ALTN")],me.ident,to);
				}else{
					print(me.errorMessage ~ "NO ALTN DATA");
				}
			}else if(findInArray(me.dataName,key) != 404){
				me.uplink(findInArray(me.dataName,key),to);
			}else{
				print(me.errorMessage);
			}
		},
		getWXR : func(apt,from,to){	#apt is the ICAO(4 digit)code for the airport
			http.save("https://aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&stationString="~apt~"&hoursBeforeNow=1", getprop('/sim/fg-home') ~ '/Export/METAR.xml')
			    .fail(func print("Download failed!"))
			    .done(func(r) processMETAR(r,from,to));
		}
		#datalink.allAircrafts[0].request("ALTNWXR",groundDefault);
	};
	
	var onBoard = {
		
		ident : 0,
		
		states : "NO COMM",
		
		new: func(id) { 
			return { parents:[onBoard], ident: id}; 
		},
		
		data : ["Comm Success by Aircraft"],
		dataName: ["test",],
		errorMessage : "Error",
		
		dataNum: 1,
		
		downlink : func(key,target){
			return transmit(key, "downlink",me.ident,target.ident);
		},
		uplinkReceived: func(key,from){
			if(findInArray(me.dataName,allGrounds[from].dataName[key]) == 404){
				append(me.data, allGrounds[from].data[key]);
				append(me.dataName, allGrounds[from].dataName[key]);
				me.dataNum+=1;
			}else{
				me.data[findInArray(me.dataName, allGrounds[from].dataName[key])] = allGrounds[from].data[key];
			}
			
			print("UplinkReceived, "~allGrounds[from].dataName[key]~" is "~allGrounds[from].data[key]);
			if(me.data[size(me.data)-1] == "Comm Success"){
				me.states = "READY";
			}
			if(allGrounds[from].dataName[key] == "ALTNWXR"){
				cdu.outputUI(content = "ALTN WXR: "~me.data[size(me.data)-1]);	
			}
		},
		request : func(key,target){
			me.requestState = "REQUESTING";
			print(me.requestState);
			if(key == "ALTNWXR"){
				me.downlink(findInArray(me.dataName, "ALTN"),allGrounds[0]);
			}
			#print("I made it here");
			transmit(key,"request",me.ident,target.ident);
			
			
		},
		
		testConnection: func(){
			
			me.request("testMessage",allGrounds[0]);
			print("DATALINK COMM TEST STARTED");
			me.states = "NO COMM";
			
		},
		
		requestState: "<REQUEST",
		
	};
	
	var transmit = func(key,tag,planeId,groundId){
		var transmitTimer = maketimer(rand()*5, func(){
			if(tag == "uplink"){
				allAircrafts[planeId].uplinkReceived(key,groundId);
			}else if(tag == "downlink"){
				allGrounds[groundId].downlinkReceived(key,planeId);
			}else if(tag == "request"){
				allGrounds[groundId].requestReceived(key,planeId);
			}
		});
		transmitTimer.singleShot = 1;
		transmitTimer.start();
		return transmitTimer;
	}
	
	
	var allAircrafts = [];
	var allGrounds = [];
	var aircraft1 = onBoard.new(0);
	var groundDefault = ground.new(0);
	
	append(allGrounds, groundDefault);
	append(allAircrafts, aircraft1);
	
	#allAircrafts[0].request("testMessage",allGrounds[0]);
	#allAircrafts[0].downlink("test",allGrounds[0]);
	
	var findInArray = func(target, obj){
		for(var i = 0; i < size(target); i+=1){
			if(target[i] == obj){
				return i;
			}
		}
		return 404;
	}

	var processMETAR = func(r,from,to){
		#For datalink wxr request use
		#print("Finished request with status: " ~ r.status ~ " " ~ r.reason);
		var path = getprop("/sim/fg-home") ~ '/Export/METAR.xml';
		var data = io.readfile(path);
		var result = "";
		for(var i = 0; i < utf8.size(data)-2; i = i+1){
			if(utf8.chstr(data[i])~utf8.chstr(data[i+1])~utf8.chstr(data[i+2]) == "raw"){
				var metar_j = i+9;
				while(utf8.chstr(data[metar_j]) != "<"){
					result = result~utf8.chstr(data[metar_j]);
					metar_j += 1;
				}
				break;
			}
		}	
		#print(result);
		if(result != ""){
			append(allGrounds[from].data,result);
			append(allGrounds[from].dataName,"ALTNWXR");
			allGrounds[from].uplink(findInArray(allGrounds[from].data,result),to);
		}else{
			print("nil Error");
			cdu.outputUI(content = "ALTN WXR NOT AVAILABLE");	
		}
	}
}