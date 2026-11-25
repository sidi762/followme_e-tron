# The regulated loads share the high-voltage feed with the traction inverter.
# The circuit solves for pack current from their combined input power.
var supplyLoad = Appliance.new();
supplyLoad.isPowerLoad = 1;
circuit_1.addUnitToSeries(0, supplyLoad);
var accessoryLoad = Appliance.new();
accessoryLoad.isPowerLoad = 1;
circuit_low.addUnitToSeries(0, accessoryLoad);

# Reference component: TI TIDA-050063 (2 mF DC link, 4 A active precharge).
# TI TIDA-020031 is a 3.6 kW reference converter. The fixed efficiency,
# 12 V charge limit, bleed time and awake electronics draw are model assumptions.
var linkCapacitanceF = 0.002;
var prechargeCurrentA = 4;
var converterLimitW = 3600;
var converterEfficiency = 0.92;
var auxChargeLimitW = 120;
var auxBusPowered = vInfo.electrical.initNode("aux-bus-powered", 1, "BOOL");
cSource_small.onEnergyChanged = func {
    vInfo.electrical.setValue("aux-battery-kWh", me.getRemainingInkWh());
};
cSource_small.onEnergyChanged();
var supplyCableConnected = getprop("/services/service-truck/connect");
var linkVoltage = 0;
var powerState = "off";
var setPowerState = func(state) {
    powerState = state;
    vInfo.electrical.setValue("power-state", state);
};
setPowerState("off");

var requestDrivePower = func {
    updateElectrical();
    if (supplyCableConnected or cSource.remaining <= 0 or cSource_small.remaining <= 0)
        return 0;
    if (powerState == "off") setPowerState("precharge");
    return 1;
};

var accessoryPowerW = func {
    # Pair of H4 filaments (OSRAM nominal 55/60 W); paired 21 W indicators.
    var watts = powerState != "off" ? 25 : 0;
    if (vInfo.lighting.highBeam.getValue()) watts += 120;
    elsif (vInfo.lighting.headlight.getValue()) watts += 110;
    if (getprop("/controls/lighting/front-fog/powered")) watts += 110;
    if (getprop("/controls/lighting/rear-fog/powered")) watts += 21;
    if (getprop("/sim/model/lights/indicator-left/state")) watts += 42;
    if (getprop("/sim/model/lights/indicator-right/state")) watts += 42;
    if (getprop("/controls/wiper/frontwiper/switch")) watts += 45;
    return watts;
};

var stepPowerSupply = func(dt) {
    var sourceV = cSource.electromotiveForce;
    var precharging = powerState == "precharge";
    var prechargeW = 0;
    var nextV = linkVoltage;
    if (precharging and dt > 0 and sourceV > 0) {
        nextV = math.min(sourceV, linkVoltage + prechargeCurrentA * dt / linkCapacitanceF);
        if (sourceV - nextV < 1e-8) nextV = sourceV;
        prechargeW = 0.5 * linkCapacitanceF * (nextV*nextV - linkVoltage*linkVoltage) / dt;
    }
    var demandW = accessoryPowerW();
    var converterW = 0;
    var converterOn = sourceV > 0 and (powerState == "ready" or supplyCableConnected);
    if (converterOn) {
        var roomJ = 1000 * (cSource_small.electricalCapacity - cSource_small.remaining);
        var topUpW = dt > 0 ? math.min(auxChargeLimitW, roomJ / dt) : 0;
        converterW = math.min(converterLimitW, demandW + topUpW);
    }

    supplyLoad.activePower = prechargeW + converterW / converterEfficiency;
    var availableJ = cSource.remaining * 1000;
    circuit_1.update(dt);
    # At depletion a long frame can deliver only part of the requested energy.
    var usedJ = circuit_1.current * sourceV * dt;
    var supplied = usedJ > 0 ? math.min(1, availableJ / usedJ) : 1;
    converterW *= supplied;
    if (precharging) {
        linkVoltage = math.sqrt(linkVoltage*linkVoltage + supplied *
                                (nextV*nextV - linkVoltage*linkVoltage));
        if (sourceV > 0 and nextV >= sourceV and supplied >= 1) setPowerState("ready");
    } elsif (powerState == "off") {
        linkVoltage *= math.exp(-dt); # one-second off-state discharge time constant
    } else {
        linkVoltage = circuit_1.voltage();
    }

    accessoryLoad.activePower = math.max(0, demandW - converterW);
    circuit_low.update(dt);
    if (converterW > demandW and dt > 0) cSource_small.addToBattery((converterW - demandW) * dt / 1000);
    auxBusPowered.setBoolValue(cSource_small.remaining > 0 or (converterOn and cSource.remaining > 0));
    if (powerState != "off" and (cSource.remaining <= 0 or !auxBusPowered.getBoolValue()))
        setPowerState("off");
    vInfo.electrical.setValue("dc-link-v", linkVoltage);
    vInfo.electrical.setValue("dc-dc-output-w", converterW);
    vInfo.electrical.setValue("accessory-demand-w", demandW);
};

# A slow frame can cross the contactor transition. Apply each supply mode
# only for the part of the interval for which it was active.
var advancePowerSupply = func(dt) {
    if (powerState == "precharge" and cSource.electromotiveForce > 0) {
        var t = math.max(0, cSource.electromotiveForce - linkVoltage) * linkCapacitanceF / prechargeCurrentA;
        if (t > 0 and t < dt) {
            stepPowerSupply(t);
            dt -= t;
        }
    }
    stepPowerSupply(dt);
};

var quickRecharge = func {
    updateElectrical();
    cSource.resetRemainingToFull();
    cSource_small.resetRemainingToFull();
    advancePowerSupply(0);
};
