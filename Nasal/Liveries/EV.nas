####    Sidi Liang    ####

io.include("../library.nas");

var displayPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Messages/";
var displaySelector = TextureSelector.new(name: "Message-Selector", path: displayPath, fileType: ".xml", textureProp: "texture", enableMultiplayer: 1, multiplayerProperty:"/sim/multiplay/generic/string[18]", defaultValue: "Blanco");
var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/FollowmeEV/";
var liverySelector = TextureSelector.new(name: "Livery-Selector", path: liveryPath, fileType: ".xml", textureProp: "texture-fuse", enableMultiplayer: 1, defaultValue: "Yellow(Default)");
