#//Followme EV electrical system by Sidi Liang
#//Contact: sidi.liang@gmail.com

#//Notes: switch should be changed to a (very very) large resistant

io.include("lib_elec.nas");

var cSource = VoltageSource.new(0.0136, 405, kWh2kWs(90), "Battery");#//Battery for engine, 90kWh, 405V
var circuit_1 = Circuit.new(cSource);#//Engine circuit

var cSource_small = VoltageSource.new(0.0136, 12, kWh2kWs(0.72), "12V Battery");#//Battery for other systems, 60Ah, 12V
var circuit_low = Circuit.new(cSource_small);#//Low voltage circuit
# cSource_small.resetRemainingToZero();
#circuit_1.addNewSeriesWithUnitToParallel(cSource_small);


#circuit_1.addUnitToSeries(0, Cable.new(10, 0.008));
#circuit_1.addUnitToSeries(0, Switch.new(0));
#circuit_1.addParallel(Switch.new(1));



var electricTimer1 = maketimer(circuit_1.updateInterval, func circuit_1.update());
electricTimer1.simulatedTime = 1;

var L = setlistener("/sim/signals/fdm-initialized", func{
    electricTimer1.start();
});
