#//Parking radar by Sidi Liang
#//Contact: sidi.liang@gmail.com

#// This program is free software: you can redistribute it and/or modify
#// it under the terms of the GNU General Public License as published by
#// the Free Software Foundation, either version 2 of the License, or
#// (at your option) any later version.

#// This program is distributed in the hope that it will be useful,
#// but WITHOUT ANY WARRANTY; without even the implied warranty of
#// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#// GNU General Public License for more details.

#// You should have received a copy of the GNU General Public License
#// along with this program.  If not, see <https://www.gnu.org/licenses/>.

#// Tracks the positions of the AI and multiplayer models for one radar
var MultiplayerCoordManager = {
    new: func() {
        return {
            parents: [MultiplayerCoordManager],
            items: {},
            addListener: nil,
            delListener: nil,
            nxtupdatetime: 0,
        };
    },

    start: func() {
        me.stop();
        #//model-added only holds the latest model, so pick up the ones already there
        foreach (var model; props.globals.getNode("/ai/models", 1).getChildren()) {
            if (model.getNode("position/latitude-deg") != nil) me.add(model.getPath());
        }
        var self = me;
        me.addListener = setlistener("/ai/models/model-added", func(changed) {
            var path = changed.getValue();
            if (path != nil) self.add(path);
        }, 0, 1);
        me.delListener = setlistener("/ai/models/model-removed", func(changed) {
            var path = changed.getValue();
            if (path != nil) delete(self.items, path);
        }, 0, 1);
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
        me.nxtupdatetime = 0;
    },

    add: func(path) {
        var node = props.globals.getNode(path);
        if (node != nil) me.items[path] = { prop: node, data: nil };
    },

    update: func() {
        var _tm = systime();
        if (_tm < me.nxtupdatetime) return;
        me.nxtupdatetime = _tm + 0.1; # refresh rate at 100ms
        foreach (var path; keys(me.items)) me.updateItem(me.items[path]);
    },

    updateItem: func(item) {
        var node = item.prop;
        var valid = node.getNode("valid");
        var lat = node.getNode("position/latitude-deg");
        var lon = node.getNode("position/longitude-deg");
        if ((valid != nil and !valid.getBoolValue()) or lat == nil or lon == nil) {
            item.data = nil;
            return;
        }
        item.data = {
            lat: lat.getValue(),
            lon: lon.getValue(),
            alt: (node.getValue("position/altitude-ft") or 0) * FT2M,
            heading: node.getValue("orientation/true-heading-deg") or 0,
        };
        if (item.data.lat == nil or item.data.lon == nil) item.data = nil;
    },
};


var Radar = {
    #//Class for any Parking Radar (currently supports terrain detection and multiplayer(and ai) model detection) which scans a sector
    #//height: height of installation above ground; installCoordX: X coord of installation; installCoordY: Y coord of installation (meters behind the front bumper)
    #//maxRange: max radar range; maxWidth: width of the sector at maxRange; baseWidth: width of the sector at the sensor (the bumper width)
    #//orientationMode 0:towards back, 180:towards front, 90: towards left, 270:towards right, custom values are accepted(in degrees)
    #//updateInterval: update interval of the radar timer, defaults to 0.25
    #//lateralSamples: terrain samples on each side of the centre line per distance step
    #//Note that 0 degrees is the backward(180 degrees heading of the vehicle), which is a little weird because I forgot about it when designing the system
    #//and the support of other install orientations are added afterwards
    #//For a typical parking radar, set orientationMode=0(or leave it as default)
    #//warnEnabled: set it to 1 (or leave it as default) enables the internal warning system(typecally used for a parking radar)
    #//beepSound / continuousSound: the warning samples; continuousDistance: below it the tone runs continuously
    #//audioQueue: sound queue, give each radar its own so that front and rear can sound together
    #//radarOutput holds the distance to the nearest obstacle along the scan direction in meters, 10000 when clear
    #//scanCount goes up by one with every scan, so readers can tell a new reading from an old one
    #//To start scanning: myRadar.init();
    #//To Stop: myRadar.stop();

    new: func(height, installCoordX, installCoordY, maxRange, maxWidth, orientationMode=0, warnEnabled=1,
        updateInterval=0.25, debug=0, baseWidth=0, lateralSamples=2,
        beepSound="parking_radar.wav", continuousSound="parking_radar_long.wav", continuousDistance=0.5,
        audioQueue="fx_radar", reportSectors=0) {
        return {
            parents:[Radar, Appliance.new()],
            height: height, installCoordX:installCoordX, installCoordY:installCoordY,
            maxRange:maxRange, maxWidth:maxWidth, baseWidth:baseWidth,
            orientationMode:orientationMode, warnEnabled:warnEnabled,
            updateInterval:updateInterval, lateralSamples:lateralSamples, debug:debug,
            beepSound:beepSound, continuousSound:continuousSound, continuousDistance:continuousDistance,
            audioQueue:audioQueue, warningSound:beepSound,
            radarOutput:10000, scanCount:0,
            # Left, centre and right looking out from the sensor. Nil entries mean no echo.
            sectorRanges: reportSectors ? [nil, nil, nil] : nil,
            #//Each radar keeps its own list, so stopping one radar leaves the others' alone
            multiplayerManager: MultiplayerCoordManager.new(),
        };
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
    baseWidth: 0, #METERS
    lateralSamples: 2,
    radarTimer: nil,
    updateInterval:0.25,#SEC
    orientationMode:0, #Deg

    vehiclePosition: nil,
    coord: nil,
    vehicleHeadingProp: props.getNode("/orientation/heading-deg",1),
    vehicleHeading: nil,
    groundBaseline: 3, #METERS, how far under the vehicle the ground slope is measured
    vehicleElevProp: props.getNode("/position/altitude-ft",1),

    #//AI and multiplayer models are taken as a car-sized box around their position
    targetHalfLength: 2.3, #METERS
    targetHalfWidth: 0.95, #METERS

    warningTimer: nil,
    warningInterval: 2,
    beepSound: "parking_radar.wav",
    continuousSound: "parking_radar_long.wav",
    continuousDistance: 0.5, #METERS
    continuousInterval: 0.2, #SEC
    audioQueue: "fx_radar",
    warningSound: "parking_radar.wav",

    radarOutput: 10000,#The value which radar returns in meters
    scanCount: 0,

    calculateVehicleElevation: func(){
        #//Return the elevation in METERS
        var elev_ft = me.vehicleElevProp.getValue();
        return elev_ft * FT2M;
    },

    createTimers: func(){
        if(me.radarTimer == nil) me.radarTimer = maketimer(me.updateInterval, func me.update());
        if(me.warnEnabled and me.warningTimer == nil) me.warningTimer = maketimer(me.warningInterval, func me.warn());
    },
    init: func(quiet=0){
        me.createTimers();
        me.radarTimer.start();
        me.multiplayerManager.start();
        me.initialized = 1;
        me.isRunning = 1;
        if(me.warnEnabled and !quiet){
            print("Parking radar initialized and started!");
            playAudio("parking_radar_init.wav");
        }
    },
    initWithoutStarting: func(){ #//Added due to compability
        me.createTimers();
        me.initialized = 1;
    },
    start: func(){
        me.radarTimer.start();
        me.multiplayerManager.start();
        me.isRunning = 1;
        if(me.warnEnabled){
            print("Parking radar started!");
            playAudio(file: "parking_radar_init.wav", queue: "fx_radar");
        }
    },
    stop: func(){
        me.isRunning = 0;
        if(me.warnEnabled){
            print("Parking radar stopped!");
        }
        me.radarOutput = 10000;
        if (me.sectorRanges != nil) me.sectorRanges = [nil, nil, nil];
        if(me.warningTimer != nil) me.warningTimer.stop();
        if(me.radarTimer != nil) me.radarTimer.stop();
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
    },
    calculateLonChange: func(meters, coord){
        var earthLength = 2 * 6378137 * math.pi; #equator
        var lat2EarthLength = earthLength * math.cos(coord.lat() * D2R);
        var lonChange = meters * (360/lat2EarthLength);
        return math.abs(lonChange);
    },
    calculateLatChange: func(meters){
        return meters * 0.000008983152841195214;
    },
    #//Half of the sector width at a distance from the sensor
    halfWidthAt: func(distance){
        return (me.baseWidth + (me.maxWidth - me.baseWidth) * distance / me.maxRange) / 2;
    },
    warn: func(){
        me.warningTimer.restart(me.warningInterval);
        playAudio(file: me.warningSound, queue: me.audioQueue);
    },
    warnControl: func(meters){
        if(meters == 10000){
            me.warningTimer.stop();
            return;
        }
        if(meters <= me.continuousDistance){
            me.warningInterval = me.continuousInterval;
            me.warningSound = me.continuousSound;
        }else{
            me.warningInterval = meters / me.maxRange;
            me.warningSound = me.beepSound;
        }
        if(me.debug) print(sprintf("Caution! Something detected at approximatly %.2f meters", meters));
        #//Beep as soon as something shows up; the timer was made with an old interval
        if(!me.warningTimer.isRunning) me.warn();
    },
    #//Ground elevation at a distance along the scan direction from the sensor (negative: under the vehicle)
    groundAt: func(frame, distance){
        return geo.elevation(frame.lat + distance * frame.cosB * frame.latPerM,
            geo.normdeg180(frame.lon + distance * frame.sinB * frame.lonPerM));
    },
    #//Nearest AI or multiplayer model in the sector: its distance along the scan direction, or nil
    nearestModel: func(frame, sectors=nil){
        var nearest = nil;
        var myElev = me.calculateVehicleElevation();
        var reach = me.maxRange + me.targetHalfLength + me.targetHalfWidth + me.halfWidthAt(me.maxRange);
        var corners = [[1, 1], [1, -1], [-1, -1], [-1, 1], [1, 1]];
        foreach (var path; keys(me.multiplayerManager.items)) {
            var data = me.multiplayerManager.items[path].data;
            if (data == nil) continue;
            if (math.abs(data.alt - myElev) > 4) continue; #//On another level, such as a bridge
            #//A model on our own position is our dual-control passenger
            var ownNorth = (data.lat - me.vehiclePosition.lat()) / frame.latPerM;
            var ownEast = geo.normdeg180(data.lon - me.vehiclePosition.lon()) / frame.lonPerM;
            if (ownNorth * ownNorth + ownEast * ownEast < 1) continue;
            #//Its centre in meters along and across the scan direction
            var north = (data.lat - frame.lat) / frame.latPerM;
            var east = geo.normdeg180(data.lon - frame.lon) / frame.lonPerM;
            var along = north * frame.cosB + east * frame.sinB;
            var across = -north * frame.sinB + east * frame.cosB;
            if (along < -reach or along > reach or math.abs(across) > reach) continue;
            #//Walk the outline of its box and keep the nearest point inside the sector
            var angle = data.heading * D2R - frame.bearing;
            var cosA = math.cos(angle);
            var sinA = math.sin(angle);
            for (var c = 0; c < 4; c += 1) {
                var x0 = corners[c][0] * me.targetHalfLength;
                var y0 = corners[c][1] * me.targetHalfWidth;
                var x1 = corners[c + 1][0] * me.targetHalfLength;
                var y1 = corners[c + 1][1] * me.targetHalfWidth;
                var length = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
                var steps = int(length / 0.25) + 1;
                for (var k = 0; k < steps; k += 1) {
                    var x = x0 + (x1 - x0) * k / steps;
                    var y = y0 + (y1 - y0) * k / steps;
                    var f = along + x * cosA - y * sinA;
                    var s = across + x * sinA + y * cosA;
                    if (f < -0.3 or f > me.maxRange) continue;
                    if (f < 0) f = 0; #//Already touching the bumper
                    var halfWidth = me.halfWidthAt(f);
                    if (math.abs(s) > halfWidth) continue;
                    if (nearest == nil or f < nearest) nearest = f;
                    if (sectors != nil) {
                        var sector = me.sectorIndex(s, halfWidth);
                        if (sectors[sector] == nil or f < sectors[sector]) sectors[sector] = f;
                    }
                }
            }
        }
        return nearest;
    },
	# Split each cross-section of the beam into equal thirds. A wide obstacle can
	# cover multiple sectors; a second obstacle may be farther away in a different one.
	sectorIndex: func(offset, halfWidth) {
		if (offset < -halfWidth / 3) return 0;
		if (offset > halfWidth / 3) return 2;
		return 1;
	},
    #//Distance to the nearest obstacle along the scan direction, or nil when clear
    scan: func(){
        var bearing = geo.normdeg(me.vehicleHeading + 180) * D2R;
        var frame = {
            bearing: bearing,
            cosB: math.cos(bearing),
            sinB: math.sin(bearing),
            lat: me.coord.lat(),
            lon: me.coord.lon(),
            latPerM: me.calculateLatChange(1),
            lonPerM: me.calculateLonChange(1, me.coord),
        };
        var sectors = me.sectorRanges == nil ? nil : [nil, nil, nil];
        var nearest = me.nearestModel(frame, sectors);

        #//Terrain is an obstacle once it rises more than the sensor height above the ground the
        #//vehicle stands on, extended along its slope so that ramps don't count. The slope is
        #//measured on the ground, because the body pitch also holds the suspension's squat and dive.
        var ground = me.groundAt(frame, 0);
        var groundBehind = me.groundAt(frame, -me.groundBaseline);
        var slope = (ground == nil or groundBehind == nil) ? 0 : (ground - groundBehind) / me.groundBaseline;
        if (ground == nil) ground = me.calculateVehicleElevation();

        var searchDis = 0.01;#Meters
        var searchStep = 0;#Meters
        while(searchDis <= me.maxRange and (sectors != nil or nearest == nil or searchDis < nearest)){
            var limit = ground + me.height + searchDis * slope;
            var halfWidth = me.halfWidthAt(searchDis);
            for(var j = 0; j <= me.lateralSamples; j += 1){
                var offsets = [0];
                if(j > 0){
                    var side = halfWidth * j / me.lateralSamples;
                    offsets = [-side, side];
                }
                foreach(var offset; offsets){
                    if (sectors != nil) {
                        var sector = me.sectorIndex(offset, halfWidth);
                        if (sectors[sector] != nil and sectors[sector] <= searchDis) continue;
                    }
                    var north = searchDis * frame.cosB - offset * frame.sinB;
                    var east = searchDis * frame.sinB + offset * frame.cosB;
                    var lat = frame.lat + north * frame.latPerM;
                    var lon = geo.normdeg180(frame.lon + east * frame.lonPerM);
                    if(me.debug) geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", lat, lon, me.coord.alt());
                    var targetElev = geo.elevation(lat, lon);
                    if(targetElev != nil and targetElev > limit) {
                        if (sectors == nil) return searchDis;
                        sectors[sector] = searchDis;
                        if (nearest == nil or searchDis < nearest) nearest = searchDis;
                    }
                }
            }
            searchStep += 0.1;
            searchDis += searchStep;
        }
        me.sectorRanges = sectors;
        return nearest;
    },
    update: func(){
        me.getCoord();
        me.multiplayerManager.update(); #//Updates the multiplayer coordinates manager at it's own refresh rate
        var meters = me.scan();
        me.radarOutput = (meters == nil) ? 10000 : meters;
        me.scanCount += 1;
        if(me.debug and meters == nil) print("All clear");
        if(me.warnEnabled) me.warnControl(me.radarOutput);
    },
};


#//The front and rear parking radars as one system behind the parking aid switch.
#//It comes on when reverse is selected with the drive system on, and goes off once the
#//vehicle drives forwards faster than autoOffSpeed or the drive system shuts down.
var ParkingAssist = {
    new: func(rear, front, activeVariable){
        var m = { parents: [ParkingAssist], rear: rear, front: front, activeVariable: activeVariable };
        m.speedTimer = maketimer(0.5, func m.watchSpeed());
        #//Only on changes: power-state and direction are restored and rewritten at times
        setlistener(m.directionNode.getPath(), func(node) m.onDirectionChanged(node.getValue()), 0, 0);
        setlistener(m.powerStateNode.getPath(), func(node) m.onPowerStateChanged(node.getValue()), 0, 0);
        return m;
    },
    isRunning: 0,
    autoOffSpeed: 15, #KM/H
    directionNode: props.getNode("/controls/direction", 1),
    powerStateNode: props.getNode("/systems/electrical/e-tron/power-state", 1),

    start: func(){
        if(me.isRunning) return;
        me.isRunning = 1;
        me.rear.init();
        me.front.init(1); #//One start chime for the system
        me.speedTimer.start();
        me.activeVariable.setValue(1);
    },
    stop: func(){
        if(!me.isRunning) return;
        me.isRunning = 0;
        me.rear.stop();
        me.front.stop();
        me.speedTimer.stop();
        me.activeVariable.setValue(0);
    },
    toggle: func(){
        if(me.isRunning) me.stop();
        else me.start();
    },
    hasObstacle: func(){
        return me.isRunning and (me.rear.radarOutput != 10000 or me.front.radarOutput != 10000);
    },
    onDirectionChanged: func(direction){
        var power = me.powerStateNode.getValue();
        if(direction == -1 and power != nil and power != "off") me.start();
    },
    onPowerStateChanged: func(state){
        if(state == "off") me.stop();
        elsif(state == "ready" and me.directionNode.getValue() == -1) me.start();
    },
    speedKMH: func(){
        return vInfo.getSpeedKMH();
    },
    watchSpeed: func(){
        if(me.directionNode.getValue() == 1 and me.speedKMH() > me.autoOffSpeed) me.stop();
    },
};
