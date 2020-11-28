var AdditionalModel = {
	new: func(){
		var m = {parents: [AdditionalModel]};
		newCoord = geo.Coord.new();
		newCoord.set_latlon(0, 0, 0);
		m.coord = newCoord;
		m._aircraftPath = getprop("sim/aircraft-dir") ~ "/";
		print("AdditionalModel: Model initialized");
		return m;
	},

	name: "New Model",
	info: "This is a new model for followme EV created by FGPRC",
	getPath: func(){
		return me._aircraftPath ~ me.relativePath;
	},
	relativePath: "",
	hdg: 0,
	coord: nil,
	_aircraftPath: "",
	_tileIndex:0,
	_isPlaced: 0,

	setLonLat: func(lon, lat){
		#//Use this to automatically update tileIndex
		me.coord.set_latlon(lat, lon);
		me._tileIndex = geo.tile_index(lat, lon);
	},
	setElevtionAsAlt: func(){
		var elev = geo.elevation(me.coord.lat(), me.coord.lon());
		me.coord.set_alt(elev);
	},
	setTileIndex: func(index){
		me._tileIndex = index;
	},

	tileIndex: func(){
		return me._tileIndex;
	},
	isPlaced: func(){
		return me._isPlaced;
	},


	node: func(){
		var node = props.Node.new();
		node.getNode("name", 1).setValue(me.name);
		node.getNode("info", 1).setValue(me.info);
		node.getNode("path", 1).setValue(me.relativePath);
		node.getNode("hdg", 1).setValue(me.hdg);
		node.getNode("lat", 1).setDoubleValue(me.coord.lat() or 0);
		node.getNode("lon", 1).setDoubleValue(me.coord.lon() or 0);
		node.getNode("alt", 1).setDoubleValue(me.coord.alt() or 0);
		return node;
	},
	loadFromNode: func(node){
		me.name = node.getNode("name", 1).getValue();
		me.info = node.getNode("info", 1).getValue();
		me.relativePath = node.getNode("path", 1).getValue();
		me.hdg = node.getNode("hdg", 1).getValue();
		me.setLonLat(node.getNode("lon", 1).getValue(), node.getNode("lat", 1).getValue());
		me.coord.set_alt(node.getNode("alt", 1).getValue());
		print("AdditionalModel: Model " ~ me.name ~ " loaded from node!");
	},
	placeModel: func(){
		geo.put_model(me.getPath(), me.coord, me.hdg);
		me._isPlaced = 1;
		print("AdditionalModel: Model " ~ me.name ~ " is placed");
	},
	checkAvilablity: func(){
		#//Depreciated
		avilIndex = geo.tile_index(me.coord.lat(), me.coord.lon());
		var ac_pos = geo.aircraft_position();
		acIndex = geo.tile_index(ac_pos.lat(), ac_pos.lon());
		if(avilIndex == acIndex and !me.isPlaced()){
			print("AdditionalModel: Model " ~ me.name ~ " is now avilable!");
			me.placeModel();
			me.checkTimer.stop();
		}else{
			print("AdditionalModel: Model " ~ me.name ~ " is not avilable!");
		}
	},

};

var ModelManager = {
	new: func(filePath = nil){
		if(!filePath) filePath = getprop("/sim/fg-home") ~ "/Export/followmeEV/ModelManager.xml";
		m = {parents:[ModelManager]};
		m.filePath = filePath;
		m.updateTimer = maketimer(m.updateInterval, func m.update());
		m._allModelsNode = props.Node.new();
		m.addModels(m.readNodeFromFile());
		return m;
	},

	filePath: "",
	allModels: [],
	_allModelsNode: nil,

	addModel: func(model){ #//model: AdditionalModel
		append(me.allModels, model);
		#//Add to nodes
		var tmp = me._allModelsNode.addChild("models");
		props.copy(model.node(), tmp);
		print("ModelManager: Model " ~ model.name ~ " successfully added");
		me.writeNodeToFile();
	},
	addModels: func(models){ #//models: [AdditionalModel]
		foreach(model; models){
			append(me.allModels, model);
			#//Add to nodes
			var tmp = me._allModelsNode.addChild("models");
			props.copy(model.node(), tmp);
			print("ModelManager: Model " ~ model.name ~ " successfully added");
		}
		me.writeNodeToFile();
	},
	removeModel: func(){
		#//WIP
	},

	node: func(){
		return me._allModelsNode;
	},

	writeNodeToFile: func(){
		io.write_properties(me.filePath, me.node());
		print("ModelManager: Node written to " ~ me.filePath);
	},
	readNodeFromFile: func(){ #//Returns a [AdditionalModel] vector
		if(io.read_properties(me.filePath) == nil){
			#//File doesn't exists or invalid, create new empty file
			me.writeNodeToFile();
			print("ModelManager: readNodeFromFile: File doesn't exists or invalid, creating new empty file");
		}
		var modelNodes = io.read_properties(me.filePath).getChildren("models");
		var results = [];
		var count = 0;
		foreach(modelNode; modelNodes){
			var newModel = AdditionalModel.new();
			newModel.loadFromNode(modelNode);
			append(results, newModel);
			count += 1;
		}
		print("ModelManager: readNodeFromFile: " ~ count ~ " models read from file");
		return results;
	},

	updateTimer: nil,
	updateInterval: 10,

	update: func(){
		var ac_pos = geo.aircraft_position();
		acIndex = geo.tile_index(ac_pos.lat(), ac_pos.lon());
		foreach(model; me.allModels){
			var allPlaced = 1; #//1 if every model is placed
			if(model.tileIndex() == acIndex){
				#//Model in the same tile of aircraft
				if(!model.isPlaced()){
					model.setElevtionAsAlt();
					model.placeModel();
					print("ModelManager: Model " ~ model.name ~ " is now avilable and placed");
				}
			}
		}
	},

	start: func(){
		me.updateTimer.start();
	},
	stop:func(){
		me.updateTimer.stop();
	}
};


var path = getprop("/sim/fg-home") ~ '/Export/followmeEV/service.xml';
var modelManager = ModelManager.new(path);

#//var serviceStationModel = AdditionalModel.new();
#//var stationPath = 'Models/Service-Station/Service-Staion.ac';

#//serviceStationModel.name = "service station";
#//serviceStationModel.info = "this is a service station";
#//serviceStationModel.path = stationPath;
#//serviceStationModel.hdg = 0;
#//serviceStationModel.setLonLat(122.671763, 41.513892);

#//modelManager.addModel(serviceStationModel);
modelManager.start();
