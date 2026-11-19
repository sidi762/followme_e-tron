var displayPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Messages/";
var displaySelector = TextureSelector.new(name: "Message-Selector", path: displayPath, fileType: ".xml", textureProp: "texture", enableMultiplayer: 1, multiplayerProperty:"/sim/multiplay/generic/string[18]", defaultValue: "Blanco", dialogTitle: "Select Message", outputNameProp: "message-name");
