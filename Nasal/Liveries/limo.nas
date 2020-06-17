####    Sidi Liang    ####

io.include("../library.nas");

var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/Limo/";
var liverySelector = TextureSelector.new(name: "Livery-Selector-Limo", path: liveryPath, fileType: ".png", enableMultiplayer: 1, texturePrePath: "Liveries/Limo/", defaultValue: "limo-fgprc");
