var Series = {
    #//Class for any series connection
    new: func() {
        return { parents:[Circuit] };
    },
    units: [],
    addUnit: func(unit){
        me.units.append(unit);
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
            total += elem.power;
        }
        return total;
    },
    
    voltage: 0, #//Volt
    current: func(){
        return (me.voltage + math.sqrt(me.voltage * me.voltage - 4 * me.totalResistance * me.totalPower)) / 2 * me.totalResistance; #//Ampere
    },
    
    
    #/*calculateVoltage: func(){
    #    foreach(elem; units){
    #        elem.voltage
    #    }
    #},*/
};

var Circuit = {
    #//Class for any circuit
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
      me.parallelConnection.append(units);  
    },
    
    current: 0, #//Ampere
    voltage: func(){
        return parallelConnection[0].units[0].electromotiveForce;
    }, #//Volt
    
    calculateParallelVoltage: func(){
        foreach(elem; parallelConnection){
            elem.voltage = me.voltage;
        }
    }, #//Volt
    
    totalParalleCurrent: func(){
        var total = 0;
        foreach(elem; parallelConnection){
            total += elem.current;
        }
        return total;
    }, #//Ampere
    
    
};

var Appliance = {
    #//Class for any electrical appliance
    new: func() { 
        return { parents:[Appliance] }; 
    },
    
    resistance: 0, #//electric resistance, Ωμέγα
    voltage: 0, #//electric voltage, Volt
    current: 0, #//electric current, Ampere
    power: 0, #//electric power, Watt
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
    calculatePower: func(){
        me.power = me.voltage * me.current;
        return me.power;
    },
    
};

var CurrentSource = {
    #//Class for any current source
    new: func() {
        return { parents:[Appliance], applianceName: "CurrentSource" };
    },

    electromotiveForce: 0, #//Volt
    
};



var cSource = CurrentSource.new();
cSource.name = "Battery";
cSource.resistance = 13.6 * 0.001;
cSource.electromotiveForce = 760;





















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