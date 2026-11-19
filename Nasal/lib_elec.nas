#//Followme EV electrical system by Sidi Liang
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

#//Notes: switch should be changed to a (very very) large resistant


io.include("library.nas");

var electricalDebug = Debugger.new("Electrical");
electricalDebug.setDebugLevel(0);

var kWh2kWs = func(kWh){
    return kWh * 3600;
}
var kWs2kWh = func(kWs){
    return kWs / 3600;
}

var Series = {
    #//Class for any series connection
    new: func() {
        return { parents:[Series], units: [] };
    },
    addUnit: func(unit){
        append(me.units, unit);
    },
    isSwitch: func(){
        return 0;
    },

    voltage: 0,
    current: 0,

    # Solve U*I = P + R*I^2. The traction inverter draws the current
    # needed for its shaft power. Contactor and cable losses are in series.
    solve: func() {
        var resistance = 0;
        var demandW = 0;
        var powerLoad = nil;
        var open = size(me.units) == 1 and me.units[0].isVoltageSource();
        foreach (var unit; me.units) {
            if (unit.isSwitch() and !unit.isConnected()) open = 1;
            if (unit.isPowerLoad) powerLoad = unit;
            resistance += unit.resistance;
            demandW += unit.loadPowerW();
        }

        var u = me.voltage;
        var i = 0;
        if (!open and u > 0) {
            if (powerLoad != nil or demandW > 0) {
                # The low-current root, in a form stable also at zero load.
                var discriminant = u*u - 4*resistance*demandW;
                i = discriminant >= 0 ? 2*demandW / (u + math.sqrt(discriminant))
                                      : u / (2*resistance);
            } elsif (resistance > 0) {
                i = u / resistance;
            }
        }
        me.current = i;
        foreach (var unit; me.units) {
            unit.current = i;
            unit.voltage = i * unit.resistance;
            if (unit.isVoltageSource()) unit.voltage = u - i * unit.resistance;
            elsif (unit == powerLoad and !open) unit.voltage = u - i * (resistance - unit.resistance);
        }
    },

};

var Circuit = {
    #//Class for any circuit
    #//Currently must be initalized with a source
    #//Currently only support one voltage source in a circuit
    new: func(vSource) {
        var new_circuit = { parents:[Circuit], source: vSource, parallelConnection: [] };
        new_circuit.addNewSeriesWithUnitToParallel(vSource);
        return new_circuit;
    },


    newSeriesWithUnits: func(addedUnits...){
        var newSeries = Series.new();
        foreach(var elem; addedUnits){
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

    addNewSeriesWithUnitToParallel: func(units){
        var new_series = me.newSeriesWithUnits(units);
        me.addParallel(new_series);
    },


    current: 0,
    voltage: func() {
        return math.max(0, me.source.electromotiveForce - me.current * me.source.resistance);
    },

    calculateTotalPower: func() {
        return me.source.electromotiveForce * me.current;
    },

    updateInterval: 0.1,
    update: func(dt = 0) {
        me.current = 0;
        foreach (var branch; me.parallelConnection) {
            branch.voltage = me.source.electromotiveForce;
            branch.solve();
            me.current += branch.current;
        }
        if (dt > 0) me.source.voltageSourceUpdate(me.calculateTotalPower(), dt);
    },

};

var Appliance = {
    #//Class for any electrical appliance
    new: func() {
        return { parents:[Appliance] };
    },

    isVoltageSource: func(){
        return 0;
    },

    isPowerLoad: 0,
    ratedPower: 0, #//rate power , Watt, 0 if isResistor

    isSwitch: func(){
        return 0;
    },

    resistance: 0, #//electric resistance, Ωμέγα
    resistivity: 0,#//Ω·m
    voltage: 0, #//electric voltage, Volt
    current: 0, #//electric current, Ampere
    activePower: 0, #//Output Power, Watt
    activePower_kW: 0, #//Output Power, kWatt, independence of activePower
    loadPowerW: func() { return me.activePower + 1000 * me.activePower_kW; },
    heatingPower: func(){
        return me.current * me.current * me.resistance;
    },#//heating Power
    power: func(){
        electricalDebug.debugPrint("Applicance " ~ me.applianceName ~" power: " ~ (me.activePower + me.activePower_kW*1000 + me.heatingPower()), 4);
        return me.activePower + me.activePower_kW*1000 + me.heatingPower();
    },
    counterElectromotiveForce: func(){
        return (me.activePower + me.activePower_kW*1000)/me.current; #//Counter Electromotive Force calculated by output power divided by current
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

var VoltageSource = {
    #//Class for any voltage source
    #//eR: Internal resistance of the source, eF: Electromotive force of the source, eC: Electrical capacity of the source, name: Name of the source.
    new: func(eR, eF, eC, name = "VoltageSource") {
        var newVS = { parents:[VoltageSource, Appliance.new()], resistance: eR, ratedElectromotiveForce:eF, electromotiveForce:eF, electricalCapacity:eC, applianceName: name };
        newVS.resetRemainingToFull();
        return newVS;
    },

    isVoltageSource: func(){
        return 1;
    },

    direction: 1, #//1 means it is connected in the current direction, -1 means the opposite
    ratedElectromotiveForce: 0, #//Volt
    electromotiveForce: 0, #//Volt
    electricalCapacity: 0, #//kWs
    remaining: 0, #//kWs


    voltageSourceUpdate: func(powerW, dt) {
        if (powerW > 0 and dt > 0) me.addToBattery(-powerW * dt / 1000);
    },

    # Source energy is stored in kW s. All writers pass through this boundary.
    setRemainingKWs: func(energy) {
        me.remaining = math.clamp(energy, 0, me.electricalCapacity);
        me.electromotiveForce = me.remaining > 0 ? me.ratedElectromotiveForce : 0;
        if (me.onEnergyChanged != nil) me.onEnergyChanged();
    },
    onEnergyChanged: nil,
    setRemainingKWh: func(kWh) { me.setRemainingKWs(kWh2kWs(kWh)); },
    setRemainingFraction: func(fraction) { me.setRemainingKWs(fraction * me.electricalCapacity); },
    resetRemainingToFull: func() { me.setRemainingFraction(1); },
    resetRemainingToZero: func() { me.setRemainingFraction(0); },
    getRemainingPercentage: func() {
        return sprintf("%.0f%%", me.getRemainingPercentageFloat());
    },
    getRemainingPercentageFloat: func() {
        return 100 * me.remaining / me.electricalCapacity;
    },
    getRemainingInkWh: func() { return kWs2kWh(me.remaining); },
    addToBattery: func(deltaKWs) { me.setRemainingKWs(me.remaining + deltaKWs); },

};

var Switch = {
    #//Class for any switches
    #//Type 0 for appliance switch. type 1 for series switch
    #//switchToggle: Return 1 if connected, return 0 if disconnected
    new: func(type, name = "Switch") {
        var newCS = { parents:[Switch, Appliance.new()], applianceName: name, type: type, isResistor: 1,};
        return newCS;
    },
    isSwitch: func(){
        return 1;
    },
    resistance: 3000000000000, #//3000000000000 when disconnected and 0 when connected
    switchState: 1, #//0 for disconnect, 1 for connect

    isConnected: func(){
        if(me.switchState){
            return 1;
        }else if(!me.switchState){
            return 0;
        }
    },

    switchConnect: func(){
        me.switchState = 1;
        me.resistance = 0;
        return 1;
    },
    switchDisconnect: func(){
        me.switchState = 0;
        me.resistance = 3000000000000;
        return 0;
    },
    switchToggle: func(){
        if(me.isConnected()){
            return me.switchDisconnect();
        }else if(!me.isConnected()){
            return me.switchConnect();
        }
    },
};

var Cable = {
    #//Class for any copper electrical cable
    new: func(l = 0, s = 0.008) {
        var newCable = { parents:[Cable, Appliance.new()], applianceName: "Cable", resistivity: 1.75 * 0.00000001, length: l, crossSection: s};
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
