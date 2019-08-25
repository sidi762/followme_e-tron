
var kWh2kWs = func(kWh){
    return kWh * 3600;
}
var kWs2kWh = func(kWs){
    return kWs / 3600;
}

var Series = {
    #//Class for any series connection
    new: func() {
        return { parents:[Series] };
    },
    units: [],
    addUnit: func(unit){
        append(me.units, unit);
    },
    
    
    totalResistance: func(){
        var total = 0;
        foreach(elem; me.units){
            total += elem.resistance;
        }
        return total;
    },
    
    totalActivePower: func(){
        var total = 0;
        foreach(elem; me.units){
            total += elem.activePower;
        }
        return total;
    },
    
    totalPower: func(){
        var total = 0;
        foreach(elem; me.units){
            total += elem.power();
        }
        return total;
    },
    
    
    voltage: 0, #//Volt
    current: func(){
        var a = me.totalResistance();
        var b = me.voltage;
        var c = math.sqrt(me.voltage * me.voltage - 4 * me.totalResistance() * me.totalActivePower());
        var d = b + c;
        return d / (2 * a); #//Ampere
    },
    
    
    calculateSeriesVoltage: func(){
        var tR = me.totalResistance();
        foreach(elem; me.units){
            elem.voltage = (elem.resistance/tR) * me.voltage;
        }
    },
    
    calculateSeriesCurrent: func(){
        foreach(elem; me.units){
            elem.current = me.current();
        }
    },
};

var Circuit = {
    #//Class for any circuit
    #//Currently must be initalized with a source
    #//Currently only support one current source in a circuit
    new: func(cSource) {
        var new_circuit = { parents:[Circuit] };
        var new_series = new_circuit.newSeriesWithUnits(cSource);
        new_circuit.addParallel(new_series);
        return new_circuit;
    },
    
    
    parallelConnection: [],
    
    newSeriesWithUnits: func(addedUnits...){
        var newSeries = Series.new();
        foreach(elem; addedUnits){
            newSeries.addUnit(elem);
        }
        return newSeries;
    },
    
    
    addUnitToSeries: func(seriesNum, unit){
        me.parallelConnection[seriesNum].addUnit(unit);
    },
    
    addParallel: func(units){
      append(me.parallelConnection, units);  
    },
    
    
    current: 0, #//Ampere
    voltage: func(){
        return me.parallelConnection[0].units[0].electromotiveForce;
    }, #//Volt
    
    calculateParallelVoltage: func(){
        foreach(elem; me.parallelConnection){
            elem.voltage = me.voltage();
        }
    }, #//Volt
    
    calculateSeriesVoltage: func(){
        foreach(elem; me.parallelConnection){
            elem.calculateSeriesVoltage();
        }
    }, #//Volt
    
    calculateTotalParalleCurrent: func(){
        var total = 0;
        foreach(elem; me.parallelConnection){
            total += elem.current();
        }
        me.current = total;
        return total;
    }, #//Ampere
    
    calculateTotalPower: func(){
      var total = 0;
      foreach(elem; me.parallelConnection){
          total += elem.totalPower();
      }  
      return total;
    },
    
    updateInterval: 0.1, #//Seconds between each update
    
    debugMode: 0,
    
    loopCount: 0,
    
    update: func(){
        if(me.debugMode) print("Loop Count: "~me.loopCount);
        
        me.calculateParallelVoltage();
        if(me.debugMode) print("Parallel Voltage Calculated");
        
        me.calculateSeriesVoltage();
        if(me.debugMode) print("Series Voltage Calculated");
        
        foreach(elem; me.parallelConnection){
            elem.calculateSeriesCurrent();
        }
        if(me.debugMode) print("Series Current Calculated");
        
        me.calculateTotalParalleCurrent();
        if(me.debugMode) print("Parallel Current Calculated");
        
        me.parallelConnection[0].units[0].remaining -= me.calculateTotalPower() * me.updateInterval; #
        if(me.debugMode) print("Power Calculated");
        
        print("current: "~me.current);
        print("voltage: "~me.voltage());
        
        me.loopCount += 1;
    },
    
    
};

var Appliance = {
    #//Class for any electrical appliance
    new: func() { 
        return { parents:[Appliance] }; 
    },
    
    ratedPower: 0, #//rate power , Watt, 0 if isResistor
    
    
    resistance: 0, #//electric resistance, Ωμέγα
    resistivity: 0,#//Ω·m
    voltage: 0, #//electric voltage, Volt
    current: 0, #//electric current, Ampere
    activePower: 0, #//Output Power
    heatingPower: func(){
        return me.current * me.current * me.resistance;
    },#//heating Power
    power: func(){
      return me.activePower + me.heatingPower();  
    },
    
    
    isResistor: 0,
    
    applianceName: "Appliance",
    applianceDescription: "This is a electric appliance",
    
    setName: func(text){
        me.applianceName = text;
    },
    setDescription: func(text){
        me.applianceDescription = text;
    },
    setResistance: func(r){
        me.resistance = r;
    },
};

var CurrentSource = {
    #//Class for any current source
    #//eR: Internal resistance of the source, eF: Electromotive force of the source, eC: Electrical capacity of the source, name: Name of the source.
    new: func(eR, eF, eC, name = "CurrentSource") {
        var newCS = { parents:[CurrentSource, Appliance.new()], resistance: eR, electromotiveForce:eF, electricalCapacity:eC, applianceName: name };
        newCS.resetRemainingToFull();
        return newCS;
    },

    electromotiveForce: 0, #//Volt
    electricalCapacity: 0, #//kWs
    remaining: 0, #//kWs
    
    resetRemainingToFull: func(){
        me.remaining = me.electricalCapacity;
    },
    getRemainingPercentage: func(){
        return sprintf("%.0f", me.remaining/2880)~"%";
    },
    
};

var Cable = {
    #//Class for any copper electrical cable
    new: func(l = 0, s = 0.008) { 
        var newCable = { parents:[Cable, Appliance.new()], resistivity: 1.75 * 0.00000001, length: l, crossSection: s};
        print("Created Cable with resistance of " ~ newCable.setResistance());
        return newCable; 
    },
    length: 0,#//Meter
    crossSection: 0,#//Meter^2
    setResistance: func(){
        me.resistance = (me.resistivity * me.length) / me.crossSection;
        return me.resistance;
    }
};

var cSource = CurrentSource.new(0.0136, 760, kWh2kWs(80), "Battery");
var circuit_1 = Circuit.new(cSource);
circuit_1.addUnitToSeries(0, Cable.new(100, 0.008));





var electricTimer1 = maketimer(1, func circuit_1.update());

var L = setlistener("/sim/signals/fdm-initialized", func{
    electricTimer1.start();
});












var electric_init = func(){  #Initialize
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-kWh",80);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-kWs",288000);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-U-V",760);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",0);
    props.getNode("/systems/electrical/e-tron/battery-remaining-percent", 1).setValue("0%");
    print("Electrical system initiallized!");
}

var electric_update = func(){
    
    var currentBattery_kWs = props.getNode("/systems/electrical/e-tron/battery-kWs",1);
    var currentBattery_kWh = props.getNode("/systems/electrical/e-tron/battery-kWh",1);
    var currentBattery_percent = props.getNode("/systems/electrical/e-tron/battery-remaining-percent", 1);
    
    if(currentBattery_kWs.getValue() >= 0.1){
        
        
        if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-fwd-eng") == 1){
            props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",747);
            props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V",380);
        }else if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-fwd-eng") == 0){
            props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",0);
             props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V",0);
        }
    
        if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-bwd-eng") == 1){
            props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V",380);
            props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",747);
        }else if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-bwd-eng") == 0){
            props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",0);
            props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V",0);
        }
        
        
    }else{
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V",0);
    }
    
    
    
   
    #battery consume
    
    var currentFwdEngConsume = props.getNode("/systems/electrical/e-tron/fwd-eng-U-V",1).getValue() * props.getNode("/systems/electrical/e-tron/fwd-eng-I-A",1).getValue() * 0.001;
    var currentBwdEngConsume = props.getNode("/systems/electrical/e-tron/bwd-eng-U-V",1).getValue() * props.getNode("/systems/electrical/e-tron/bwd-eng-I-A",1).getValue() * 0.001;
    var currentTotalConsume = currentFwdEngConsume+currentBwdEngConsume;
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-kWs", currentBattery_kWs.getValue() - currentTotalConsume);
    
    currentBattery_kWh.setValue(currentBattery_kWs.getValue()/3600);
    currentBattery_percent.setValue(sprintf("%.0f", currentBattery_kWs.getValue()/2880)~"%");
}

var electricTimer = maketimer(1, electric_update);

var startElectricalSystemUpdate = func(){
    electricTimer.start();
    print("Electrical system update started!");
}
var stopElectricalSystemUpdate = func(){
    electricTimer.stop();
    print("Electrical system update stopped!");
}

var resetElectricalSystemUpdate = func(){
    electricTimer.stop();
    electric_init();
    electricTimer.start();
    print("Electrical system update reseted!");
}

var L = setlistener("/sim/signals/fdm-initialized", func{
    electric_init();
    electricTimer.start();
    removelistener(L);
});