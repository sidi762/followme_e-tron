#Parking radar by Sidi Liang
var Radar = {
    #//Class for any Parking Radar (currently only support terrain detection)
    #//height: height of installation above ground;installCoord: coord of installation; maxRange: max radar range
    #//For this vehicle: height 0.3m; installCoord:3.8m; maxRange:6m; maxWidth:2m
    #//To start scanning: myRadar.init();
    #//To Stop: myRadar.stop();
    new: func(height, installCoord, maxRange, maxWidth) {
        return { parents:[Radar, followme.Appliance.new()], height: height, installCoord:installCoord, maxRange:maxRange, maxWidth:maxWidth};
    },
    height: 0.3, #METERS
    installCoord:3.8, #METERS
    maxRange:6, #METERS
    maxWidth:2, #METERS
    radarTimer: nil,

    vehiclePosition: nil,
    coord: nil,
    vehicleHeading: nil,

    backLonRange: nil,
    backLatRange: nil,
    widthLonRange:nil,
    widthLatRange:nil,

    warningTimer: nil,
    #warningFlag: 0,
    warningInterval: 2,
    warningSound: "parking_radar.wav",
    lastDis: 0,

    init: func(){
        me.getCoord();
        me.backLatRange = me.calculateLatChange(me.maxRange);
        me.backLonRange = me.calculateLonChange(me.maxRange, me.coord);
        me.widthLatRange = me.calculateLatChange(me.maxWidth);
        me.widthLonRange = me.calculateLonChange(me.maxWidth, me.coord);
        if(me.radarTimer == nil) me.radarTimer = maketimer(0.2, func me.update());
        if(me.warningTimer == nil) me.warningTimer = maketimer(me.warningInterval, func me.warn());
        me.radarTimer.start();
        print("Parking radar initialized!");
        playAudio("parking_radar_init.wav");
    },
    stop: func(){
        print("Parking radar stopped!");
        me.warningTimer.stop();
        me.radarTimer.stop();
    },
    toggle: func(){
        if(me.radarTimer == nil or me.radarTimer.isRunning == 0){
            me.init();
        }else{
            me.stop();
        }
    },

    getCoord: func(){
        me.vehicleHeading = props.getNode("/orientation/heading-deg",1).getValue();
        me.vehiclePosition = geo.aircraft_position();
        me.coord = geo.Coord.new(me.vehiclePosition);
        me.coord.apply_course_distance(me.vehicleHeading, -me.installCoord);
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
        myElev = me.getElevByCoord(me.coord);
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
        if(meters <= 0.5){
            me.warningInterval = 0.2;
            me.warningSound = "parking_radar_long.wav";
            return;
        }else{
            me.warningSound = "parking_radar.wav";
        }
        if(!me.warningTimer.isRunning) me.warningTimer.start();
        meters = sprintf("%.2f", meters);
        if(meters != me.lastDis) me.warningInterval = (meters)/me.maxRange;
        print("Caution! something behind at approximatly "~meters~" meters");
        me.lastDis = meters;
    },
    sample: func(stepLat, stepLon, searchLat, searchLon){ # returns an elevtion
        var latChange  = math.sin(math.pi * me.vehicleHeading/180);
        var lonChange  = -math.cos(math.pi * me.vehicleHeading/180);
        var coord = geo.Coord.new();
        coord.set_latlon(me.position_change(searchLat,stepLat*latChange), me.position_change(searchLon,stepLon*lonChange));
        return coord;
    },
    update: func(){
        me.getCoord();
        var searchDis = 0.01;#Meters
        var searchStep = 0.1;#Meters
        while(searchDis <= me.maxRange){
            var searchCoord = geo.Coord.new();
            searchCoord.set_latlon(me.coord.lat(), me.coord.lon());
            searchCoord.apply_course_distance(me.vehicleHeading, 0-searchDis);
            for(var i = 0; i > (0 - me.widthLatRange/2); i -= 0.000001){
                var percentage = (0-i)/(me.widthLatRange/2); #use approximate value to reduce cost
                var stepLon = 0 - me.widthLonRange * percentage;
                var targetCoord = me.sample(i, stepLon, searchCoord.lat(), searchCoord.lon());
                targetElev = me.getElevByCoord(targetCoord);
                if(me.judgeElev(targetElev)){
                    var meters = me.coord.distance_to(targetCoord);
                    me.warnControl(meters);
                    #var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", targetCoord);
                    return;
                }
            }
            for(var i = 0; i < me.widthLatRange/2; i += 0.000001){
                var percentage = i/(me.widthLatRange/2); #use approximate value to reduce cost
                var stepLon = me.widthLonRange * percentage;
                var targetCoord = me.sample(i, stepLon, searchCoord.lat(), searchCoord.lon());
                targetElev = me.getElevByCoord(targetCoord);
                if(me.judgeElev(targetElev)){
                    var meters = me.coord.distance_to(targetCoord);
                    me.warnControl(meters);
                    #var model = geo.put_model(getprop("sim/aircraft-dir")~"/Nasal/waypoint.ac", targetCoord);
                    return;
                }
            }
            searchStep += 0.1;
            searchDis += searchStep;
        }
        print("All clear");
        me.warnControl(10000);
    },
};

var parkingRadar = Radar.new(0.3, 3.8, 6, 2);
