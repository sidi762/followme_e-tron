#Custom plate selection system by Sidi Liang for follow me EV
#Contact: sidi.liang@gmail.com
#
#Instructions: This code scans the Models/plate/texture folder
#whenever the vehicle config dialog (config-dialog.xml) is opened.
#To add an plate, just place the new plate texture file (must be .png
#format) to that folder and it will show up in the dialog.

var path = props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Models/plate/texture';
var scan = func(){
    var data = [];
    var files = directory(path);
    if (size(files)) {
        foreach (var file; files) {
            if (substr(file, -4) != ".png")
                continue;
            var n = io.read_properties(path ~ file);
            append(data, [substr(file, 0, size(file) - 4), path ~ file]);
        }
        #me.data = sort(me.data, func(a, b) num(a[1]) == nil or num(b[1]) == nil
        #        ? cmp(a[1], b[1]) : a[1] - b[1]);
    }
    return data;
}
var updateList = func(){
    var allPlates = scan();
    var data = props.globals.getNode("/sim/gui/dialogs/vehicle_config/dialog/group[3]/combo/", 1);
    data.removeChildren("value");
    data.getChild("value", 0, 1).setValue("NONE");
    forindex(var i; allPlates){
        data.getChild("value", i+1, 1).setValue(allPlates[i][0]);
    }
}
var Plate = {
    new: func() {
        return { parents:[Plate]};
    },
    plateNameNode: props.getNode("systems/plate/name", 1),
    plateFileNode: props.getNode("systems/plate/file", 1),
    multiplayerNameNode: props.getNode("sim/multiplay/generic/string[4]", 1),
    multiplayerFileNode: props.getNode("sim/multiplay/generic/string[5]", 1),
    name: "",
    file: "",
    changePlate: func(name){
        #NONE for uninstalling the plate
        me.name = name;
        me.file = name~".png";
        me.update();
    },
    update: func(){
        me.plateNameNode.setValue(me.name);
        me.plateFileNode.setValue(me.file);
    },
};