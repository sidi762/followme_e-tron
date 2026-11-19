#//Followme EV electrical system by Sidi Liang
#//Contact: sidi.liang@gmail.com

io.include("lib_elec.nas");

var cSource = VoltageSource.new(0.0136, 405, kWh2kWs(90), "Battery");#//Battery for engine, 90kWh, 405V
var circuit_1 = Circuit.new(cSource);#//Engine circuit

var cSource_small = VoltageSource.new(0.0136, 12, kWh2kWs(0.72), "12V Battery");#//Battery for other systems, 60Ah, 12V
var circuit_low = Circuit.new(cSource_small);#//Low voltage circuit

io.include("power-supply.nas");

var energyKWh = vInfo.electrical.getNode("battery-kWh", 1);
cSource.onEnergyChanged = func {
    energyKWh.setDoubleValue(me.getRemainingInkWh());
    vInfo.electrical.batteryRemainingPercent.setValue(me.getRemainingPercentage());
    vInfo.electrical.batteryRemainingPercentFloat.setDoubleValue(me.getRemainingPercentageFloat());
};
cSource.onEnergyChanged();

# The scheduler may deliver fewer than ten callbacks per simulated second.
# Rebase on pause/resume: an FDM-only freeze can leave the clock running.
var lastElectricalTime = nil;
var electricalFrozen = getprop("/sim/freeze/master");
var updateElectrical = func {
    var now = getprop("/fdm/jsbsim/simulation/sim-time-sec");
    var dt = 0;
    if (!electricalFrozen and now != nil and lastElectricalTime != nil) dt = math.max(0, now - lastElectricalTime);
    lastElectricalTime = now;
    advancePowerSupply(dt);
    if (vInfo.electrical.isRecharging.getValue()) updateCharging(dt);
};

setlistener("/sim/freeze/master", func(n) {
    updateElectrical();
    electricalFrozen = n.getBoolValue();
});

setlistener("/services/service-truck/connect", func(n) {
    var connected = n.getBoolValue();
    if (connected and powerState != "off") {
        n.setBoolValue(0);
        return;
    }
    if (connected == supplyCableConnected) return;
    updateElectrical();
    supplyCableConnected = connected;
    if (!connected and vInfo.electrical.isRecharging.getValue()) chargeBatteryStop();
    advancePowerSupply(0);
});
setlistener("/services/service-truck/enable", func(n) {
    if (!n.getBoolValue()) setprop("/services/service-truck/connect", 0);
});

var electricTimer1 = maketimer(circuit_1.updateInterval, updateElectrical);
electricTimer1.simulatedTime = 1;
setlistener("/sim/signals/fdm-initialized", func(n) {
    electricTimer1.stop();
    lastElectricalTime = nil;
    if (n.getBoolValue()) {
        updateElectrical();
        electricTimer1.start();
    }
}, 1);
