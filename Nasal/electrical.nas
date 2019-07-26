var electric_init = func(){  #Initialize
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-kWh",80);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/battery-U-V",760);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V-max",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V-max",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",0);
    print("Electrical system initiallized!");
}

var electric_update = func(){
    if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-fwd-eng") == 1){
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V-max",380);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",747);
    }else{
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-U-V-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/fwd-eng-I-A-max",0);
    }
    
    if(props.getNode("/",1).getValue("/systems/electrical/e-tron/switch/bat-bwd-eng") == 1){
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V-max",380);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",747);
    }else{
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-U-V-max",0);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/bwd-eng-I-A-max",0);
    }
    
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