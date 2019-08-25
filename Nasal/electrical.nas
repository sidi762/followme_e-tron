
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
        foreach(elem; units){
            total += elem.resistance;
        }
        return total;
    },
    
    totalPower: func(){
        var total = 0;
        foreach(elem; units){
            total += elem.power();
        }
        return total;
    },
    
    voltage: 0, #//Volt
    current: func(){
        return (me.voltage + math.sqrt(me.voltage * me.voltage - 4 * me.totalResistance * me.totalPower)) / 2 * me.totalResistance; #//Ampere
    },
    
    
    calculateSeriesVoltage: func(){
        var tR = me.totalResistance();
        foreach(elem; units){
            elem.voltage = (elem.resistance/tR) * me.voltage;
        }
    },
    
    calculateSeriesCurrent: func(){
        foreach(elem; units){
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
    
    addParallel: func(units){
      append(me.parallelConnection, units);  
    },
    
    current: 0, #//Ampere
    voltage: func(){
        return parallelConnection[0].units[0].electromotiveForce;
    }, #//Volt
    
    calculateParallelVoltage: func(){
        foreach(elem; parallelConnection){
            elem.voltage = me.voltage();
        }
    }, #//Volt
    
    calculateSeriesVoltage: func(){
        foreach(elem; parallelConnection){
            elem.calculateSeriesVoltage();
        }
    }, #//Volt
    
    calculateTotalParalleCurrent: func(){
        var total = 0;
        foreach(elem; parallelConnection){
            total += elem.current();
        }
        me.current = total;
        return total;
    }, #//Ampere
    
    calculateTotalPower: func(){
      var total = 0;
      foreach(elem; parallelConnection){
          total += elem.totalPower();
      }  
    },
    
    updateInterval: 0.1, #//Seconds between each update
    
    update: func(){
        me.calculateParallelVoltage();
        me.calculateSeriesVoltage();
        foreach(elem; parallelConnection){
            elem.calculateSeriesCurrent();
        }
        me.calculateTotalParalleCurrent();
        parallelConnection[0].units[0].remaining -= me.calculateTotalPower() * me.updateInterval; #
    },
    
    
};

var Appliance = {
    #//Class for any electrical appliance
    new: func() { 
        return { parents:[Appliance] }; 
    },
    
    ratedPower: 0, #//rate power , Watt, 0 if isResistor
    
    
    resistance: 0, #//electric resistance, Ωμέγα
    voltage: 0, #//electric voltage, Volt
    current: 0, #//electric current, Ampere
    activePower: 0, #//Output Power
    heatingPower: func(){
        return me.current * me.current * me.resistance;
    },#//heating Power
    power: func(){
      return activePower + heatingPower;  
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
    new: func(eR, eF, eC, name = "CurrentSource") {
        var newCS = { parents:[CurrentSource, Appliance.new()], applianceName: name, resistance: eR, electromotiveForce:eF, electricalCapacity:eC };
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



var cSource = CurrentSource.new((13.6*0.001), 760, kWh2kWs(80), "Battery");
var circuit_1 = Circuit.new(cSource);



















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