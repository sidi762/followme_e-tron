#//Custom plate selection system by Sidi Liang for follow me EV
#//Contact: sidi.liang@gmail.com
#
#Instructions: This code scans the Models/plate/texture folder
#whenever the vehicle config dialog (config-dialog.xml) is opened.
#To add an plate, just place the new plate texture file (must be .png
#format) to that folder and it will show up in the dialog.

var path = props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Models/plate/texture';
var plateSelector = TextureSelector.new(path, ".png", 1, 1, "sim/gui/dialogs/vehicle_config/dialog", "group[4]/combo/"); 

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
