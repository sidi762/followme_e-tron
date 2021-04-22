#//Parking radar by Sidi Liang
#//Contact: sidi.liang@gmail.com

var MultiplayerCoordManager = {
    new: func() {
        var m = {
            parents: [MultiplayerCoordManager],
            items: {},
            updateKeys: [],
            addListener: nil,
            delListener: nil,
        };
        return m;
    },
    start: func() {
        me.stop();
        var self = me;
        me.addListener = setlistener('/ai/models/model-added', func(changed, listen, mode, is_child) {
            var path = changed.getValue();
            if (path == nil) return;
            #printf("ADD: %s", path);
            if (me.items[path] == nil) {
                me.items[path] = {
                    prop: props.globals.getNode(path),
                    data: {},
                };
            }
            else {
                me.items[path].prop = prop;
            }
        }, 1, 1);
        me.delListener = setlistener('/ai/models/model-removed', func(changed, listen, mode, is_child) {
            var path = changed.getValue();
            if (path == nil) return;
            #printf("DEL: %s", path);
            if (me.items[path] == nil) return;
            if (me.items[path] != nil) {
                me.items[path].prop = nil;
                me.items[path].data = {};
            }
        }, 1, 1);
    },

    stop: func() {
        if (me.addListener != nil) {
            removelistener(me.addListener);
            me.addListener = nil;
        }
        if (me.delListener != nil) {
            removelistener(me.delListener);
            me.delListener = nil;
        }
        me.items = {};
    },

    nxtupdatetime: 0,

    update: func() {
        var _tm = systime();
        if (me.nxtupdatetime != 0) {
            if (_tm<me.nxtupdatetime) return;
        }
        me.nxtupdatetime = _tm + 0.1; # refresh rate at 100ms

        if (size(me.updateKeys) == 0) {
            me.updateKeys = keys(me.items);
        }
        var path = pop(me.updateKeys);
        foreach (var path; keys(me.items)) {
            me.updateItem(path);
        }
    },

    proplist: ['lat', 'lon', 'alt'],

    updateItem: func(path) {

        var item = me.items[path];
        if (item == nil or item.prop == nil) return;

        if (item.prop['lat'] == nil) {
            item.prop['lat'] = item.prop.getNode('position/latitude-deg');
            item.prop['lon'] = item.prop.getNode('position/longitude-deg');
            item.prop['alt'] = item.prop.getNode('position/altitude-ft');
        }

        foreach (var k; me.proplist) {
            if (item.prop[k] != nil) {
                item.data[k] = item.prop[k].getValue();
            }
        }
        #//print("MultiplayerCoordManager: Working!");

    },


};


var Radar = {
    #//Class for any Parking Radar (currently supports terrain detection and multiplayer(and ai) model detection) which scans in a sector
    #//height: height of installation above ground;installCoordX: X coord of installation; installCoordY: Y coord of installation; maxRange: max radar range; maxWidth: width of the sector
    #//orientationMode 0:towards back, 180:towards front, 90: towards left, 270:towards right, custom values are accepted(in degrees)
    #//updateInterval: update interval of the radar timer, defaults to 0.25
    #//Note that 0 degrees is the backward(180 degrees heading of the vehicle), which is a little weird because I forgot about it when designing the system
    #//and the support of other install orientations are added afterwards
    #//For a typical parking radar, set orientationMode=0(or leave it as default)
    #//warnEnabled: set it to 1 (or leave it as default) enables the internal warning system(typecally used for a parking radar)
    #//Notice: when warnEnabled set to 1, nothing will be outputed to radarOutput!
    #//For follow me EV: height 0.3m; installCoordX:0m; installCoordY:3.8m; maxRange:3m;maxWidth:3m
    #//To start scanning: myRadar.init();
    #//To Stop: myRadar.stop();

    #//Todo: Add the tilt angle into consideratoin

    new: func(height, installCoordX, installCoordY, maxRange, maxWidth, orientationMode=0, warnEnabled=1,
        updateInterval=0.25, debug=0) {
        return { parents:[Radar, Appliance.new()], height: height, installCoordX:installCoordX, installCoordY:installCoordY, maxRange:maxRange, maxWidth:maxWidth, orientationMode:orientationMode, warnEnabled:warnEnabled, debug:debug, radarOutput:10000};
    },

    initialized: 0,
    isRunning: 0,

    debug: 0,#if debug = 1, shows marker and prints info
    warnEnabled: 1,#1 enables the internal warning system(typecally used for a parking radar) as 0 disables it

    height: 0.3, #METERS
    installCoordX: 0, #METERS
    installCoordY: 3.8, #METERS
    maxRange: 3, #METERS
    maxWidth: 3, #METERS
    radarTimer: nil,
    updateInterval:0.25,#SEC
    searchAngle: 0, #RAD, half of the search angle
    tanSearchAngle: 0,
    orientationMode:0, #Deg

    vehiclePosition: nil,
    coord: nil,
    vehicleHeadingProp: props.getNode("/orientation/heading-deg",1),
    vehicleHeading: nil,
    vehicleElevProp: props.getNode("/position/altitude-ft",1),

    backLonRange: nil,
    backLatRange: nil,
    widthLonRange:nil,
    widthLatRange:nil,

    warningTimer: nil,
    #warningFlag: 0,
    warningInterval: 2,
    warningSound: "parking_radar.wav",
    lastDis: 0,

    radarOutput: 10000,#The value which radar returns in meters

    multiplayerManager: MultiplayerCoordManager.new(), #//Experimental new multiplayer coordinate manager

    calculateVehicleElevation: func(){
        #//Return the elevation in METERS
        var elev_ft = me.vehicleElevProp.getValue();
        return elev_ft * FT2M;
    },

    init: func(){
        me.searchAngle = math.acos(me.maxRange / math.sqrt((2/me.maxWidth)*(2/me.maxWidth) + me.maxRange*me.maxRange));
        me.tanSearchAngle = math.tan(me.searchAngle);
        me.getCoord();
        me.backLatRange = me.calculateLatChange(me.maxRange);
        me.backLonRange = me.calculateLonChange(me.maxRange, me.coord);
        me.widthLatRange = me.calculateLatChange(me.maxWidth);
        me.widthLonRange = me.calculateLonChange(me.maxWidth, me.coord);
        if(me.radarTimer == nil) me.radarTimer = maketimer(me.updateInterval, func me.update());
        if(me.warnEnabled and me.warningTimer == nil) me.warningTimer = maketimer(me.warningInterval, func me.warn());
        me.radarTimer.start();
        me.multiplayerManager.start();
        me.initialized = 1;
        if(me.warnEnabled){
            print("Parking radar initialized and started!");
            playAudio("parking_radar_init.wav");
        }else{
            #print("Radar initialized!");
        }
    },
    initWithoutStarting: func(){ #//Added due to compability
        if(me.radarTimer == nil) me.radarTimer = maketimer(me.updateInterval, func me.update());
        if(me.warnEnabled and me.warningTimer == nil) me.warningTimer = maketimer(me.warningInterval, func me.warn());
        me.searchAngle = math.acos(me.maxRange / math.sqrt((2/me.maxWidth)*(2/me.maxWidth) + me.maxRange*me.maxRange));
        me.tanSearchAngle = math.tan(me.searchAngle);
        me.getCoord();
        me.backLatRange = me.calculateLatChange(me.maxRange);
        me.backLonRange = me.calculateLonChange(me.maxRange, me.coord);
        me.widthLatRange = me.calculateLatChange(me.maxWidth);
        me.widthLonRange = me.calculateLonChange(me.maxWidth, me.coord);
        me.initialized = 1;
    },
    start: func(){
        me.radarTimer.start();
        me.multiplayerManager.start();
        me.isRunning = 1;
        if(me.warnEnabled){
            print("Parking radar started!");
            playAudio("parking_radar_init.wav");
        }else{
            #print("Radar initialized!");
        }
    },
    stop: func(){
        me.isRunning = 0;
        if(me.warnEnabled){
            print("Parking radar stopped!");
            #playAudio("parking_radar_init.wav");
        }else{
            #print("Radar Stopped!");
        }
        me.radarOutput = 10000;
        if(me.warnEnabled) me.warningTimer.stop();
        me.radarTimer.stop();
        me.multiplayerManager.stop();
    },
    toggle: func(){
        if(me.radarTimer == nil or me.radarTimer.isRunning == 0){
            me.init();
        }else{
            me.stop();
        }
    },

    getCoord: func(){
        me.vehicleHeading = geo.normdeg(me.vehicleHeadingProp.getValue() + me.orientationMode);
        me.vehiclePosition = geo.aircraft_position();
        me.coord = geo.Coord.new(me.vehiclePosition);
        me.coord.apply_course_distance(geo.normdeg(me.vehicleHeading-90), me.installCoordX);
        me.coord.apply_course_distance(me.vehicleHeading, -me.installCoordY);
        #var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", me.coord);
    },
    calculateLonChange: func(meters, coord){
        var earthLength = 2 * 6378137 * math.pi; #equator
        var lat2EarthLength = earthLength * math.cos(math.abs(coord.lat()));
        var lonChange = meters * (360/lat2EarthLength);
        return math.abs(lonChange);
    },
    calculateLatChange: func(meters){
        return meters * 0.000008983152841195214;
    },
    calculateMeterChangebyLat: func(lat){
        return lat / 0.000008983152841195214;
    },
    getElevByCoord: func(coord){
        return geo.elevation(coord.lat(), coord.lon());
    },
    position_change: func(position_val,value){
        if(position_val+value>180)
            position_val += value-360;
        else if(position_val+value<-180)
            position_val += value+360;
        else
            position_val += value;
        return position_val;
    },
    judgeElev: func(targetElev){
        #//myElev = me.getElevByCoord(me.coord);
        myElev = me.calculateVehicleElevation();
        #print("elevgeo: "~me.getElevByCoord(me.coord));
        #print("elevprop: "~me.calculateVehicleElevation());
        if((myElev + me.height) < targetElev){
            return 1;
        }else{
            return 0;
        }
    },
    warn: func(){
        me.warningTimer.restart(me.warningInterval);
        playAudio(me.warningSound);
    },
    warnControl: func(meters){
        if(meters == 10000){
            me.warningTimer.stop();
            return;
        }
        if(!me.warningTimer.isRunning) me.warningTimer.start();
        if(meters <= 0.5){
            me.warningInterval = 0.2;
            me.warningSound = "parking_radar_long.wav";
            if(me.debug) print("Caution! Something detected at less than 0.5 meters!");
            return;
        }else{
            me.warningSound = "parking_radar.wav";
        }
        meters = sprintf("%.3f", meters);
        if(meters != me.lastDis) me.warningInterval = (meters)/me.maxRange;
        if(me.debug) print("Caution! Something detected at approximatly "~meters~" meters");
        me.lastDis = meters;
    },
    sample: func(stepLat, stepLon, searchLat, searchLon){ # returns an elevtion
        var latChange  = math.sin(me.vehicleHeading * D2R);
        var lonChange  = -math.cos(me.vehicleHeading * D2R);
        var sampleCoord = geo.Coord.new();
        sampleCoord.set_latlon(me.position_change(searchLat,stepLat*latChange), me.position_change(searchLon,stepLon*lonChange));
        if(me.debug) var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", sampleCoord.lat(), sampleCoord.lon(), me.coord.alt());
        return sampleCoord;
    },
    multiplayerModelDetection: func(targetCoord){
        foreach(var itemPath; keys(me.multiplayerManager.items)){
            var item = me.multiplayerManager.items[itemPath];
            if(item.data != nil){
                if(math.abs(item.data['alt'] * FT2M - me.height - me.calculateVehicleElevation()) > 1) continue;
                var itemCoord = geo.Coord.new();
                itemCoord.set_latlon(item.data['lat'], item.data['lon']);
                var multiplayerModelDistanceInMeters = itemCoord.distance_to(targetCoord);
                if(multiplayerModelDistanceInMeters <= 0.3){#//Value based on guessing
                    var meters = me.coord.distance_to(targetCoord);
                    if(me.debug) var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", targetCoord.lat(), targetCoord.lon(), me.coord.alt());
                    return meters;
                }
            }
        }
        return nil;
    },
    update: func(){
        me.getCoord();
        me.multiplayerManager.update(); #//Updates the multiplayer coordinates manager at it's own refresh rate
        var searchDis = 0.01;#Meters
        var searchStep = 0;#Meters
        while(searchDis <= me.maxRange){
            var searchWidth = math.abs(searchDis * me.tanSearchAngle);
            var searchWidthLat = me.calculateLatChange(searchWidth);
            var searchWidthLon = me.calculateLonChange(searchWidth, me.coord);
            var searchCoord = geo.Coord.new();
            searchCoord.set_latlon(me.coord.lat(), me.coord.lon());
            searchCoord.apply_course_distance(me.vehicleHeading, 0-searchDis);
            for(var i = 0; i >= (0 - searchWidthLat); i -= searchWidthLat/1.5){
                #print(me.widthLatRange/2);
                var percentage = (0-i)/(searchWidthLat/2); #use approximate value to reduce cost
                var stepLon = 0 - searchWidthLon * percentage;
                var targetCoord = me.sample(i, stepLon, searchCoord.lat(), searchCoord.lon());
                #//Multiplayer model detection
                meters = me.multiplayerModelDetection(targetCoord);
                if(meters != nil){
                    if(me.warnEnabled) me.warnControl(meters);
                    else me.radarOutput = meters;
                    return;
                }

                #//Terrain detection
                var targetElev = me.getElevByCoord(targetCoord);
                if(me.judgeElev(targetElev)){
                    var meters = me.coord.distance_to(targetCoord);
                    if(me.debug) var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", targetCoord.lat(), targetCoord.lon(), me.coord.alt());
                    if(me.warnEnabled) me.warnControl(meters);
                    else me.radarOutput = meters;
                    return;
                }
            }
            for(var i = 0; i <= searchWidthLat; i += searchWidthLat/1.5){
                var percentage = i/(searchWidthLat/2); #use approximate value to reduce cost
                var stepLon = searchWidthLon * percentage;
                var targetCoord = me.sample(i, stepLon, searchCoord.lat(), searchCoord.lon());
                #//Multiplayer model detection
                meters = me.multiplayerModelDetection(targetCoord);
                if(meters != nil){
                    if(me.warnEnabled) me.warnControl(meters);
                    else me.radarOutput = meters;
                    return
                }

                #//Terrain detection
                var targetElev = me.getElevByCoord(targetCoord);
                if(me.judgeElev(targetElev)){
                    var meters = me.coord.distance_to(targetCoord);
                    if(me.debug) var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", targetCoord.lat(), targetCoord.lon(), me.coord.alt());
                    if(me.warnEnabled) me.warnControl(meters);
                    else me.radarOutput = meters;
                    return;
                }
            }
            searchStep += 0.1;
            searchDis += searchStep;
        }
        if(me.debug) print("All clear");
        if(me.warnEnabled) me.warnControl(10000);
        else me.radarOutput = 10000;
    },
};
