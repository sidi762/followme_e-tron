####    Sidi Liang    ####

io.include("../library.nas");

io.include("messages.nas");
var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/FollowmeEV/";
var liverySelector = TextureSelector.new(name: "Livery-Selector", path: liveryPath, fileType: ".xml",
    textureProp: "texture-fuse", enableMultiplayer: 1, defaultValue: "Yellow(Default)",
    dialogTitle: "Select Livery", compactDialog: 1);
