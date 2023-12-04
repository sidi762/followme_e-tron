#// Sidi Liang, 2020
#// Contact: sidi.liang@gmail.com

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

#// Texture Selector for Followme EV
#// Quick start:
#// Aircraft liveries with dedicated selection dialog: (The same behavior
#// as the FG default livery selector, and applies to any texture defined in PropertyList XML):
#//      var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/FollowmeEV/";
#//      var liverySelector = TextureSelector.new(name: "Livery-Selector", path: liveryPath, fileType: ".xml", textureProp: "texture-fuse", enableMultiplayer: 1, defaultValue: "Yellow(Default)");
#//      Dialog:YourNameSpace.liverySelector.dialog.open()
#// Pure texture, dedicated dialog with MP：
#//      var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/Limo/";
#//      var liverySelector = TextureSelector.new(name: "Livery-Selector-Limo", path: liveryPath, fileType: ".png", enableMultiplayer: 1, texturePrePath: "Liveries/Limo/", defaultValue: "limo-fgprc");
#//      Dialog:Same as above
#// Pure texture, custom dialog(without multiplayer):
#//      var path = props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Models/plate/texture';
#//      var plateSelector = TextureSelector.new("Plate-Selector", path, ".png", 1, 1, "sim/gui/dialogs/vehicle_config/dialog", "group[4]/combo/");
#//
#// Documentation:
#//
#// Class: TextureSelector
#// Constructor: new()
#// Creates a new Texture Selector instance.
#//      new(name, path[, fileType[, enableNone[, customDialog[, customDialogBase[, customDialogPosition[, texturePropertyBase[, textureProp[, textureNameProp[, textureDataNode[, enableMultiplayer[, multiplayerProperty[, texturePrePath[, defaultValue]]]]]]]]]]]]);
#// name: The name of the Texture Selector (must be identical)
#// path: The path which contains texture files
#// fileType: The type of file to scan, eg. ".png" for png files and ".xml" for xml files. Defaults to nil.
#// enableNone: Set to 1 to enable the item "NONE" in the selection dialog. Defaults to 0.
#// customDialog: Set to 1 to disable the dedicated built in dialog so that you can make the TextureSelector to use your custom dialog. Defaults to 0.
#// customDialogBase: The property base for the custom dialog(see the plate selection of the followmeEV for example). Defaults to "".
#// customDialogPosition: The element which serves to select the texture in the custom dialog. eg. "group[4]/combo/". Defaults to "".
#// texturePropertyBase: The texture property base in the texture xml files. Only used if fileType is set to ".xml". This is added to support most livery files in FG. Defaults to "sim/model/livery/".
#// textureProp: The texture property in the texture xml files. Only used if fileType is set to ".xml". This is added to support most livery files in FG. Defaults to "livery".
#// textureNameProp: The texture name property in the texture xml files. Only used if fileType is set to ".xml". This is added to support most livery files in FG. Defaults to "name".
#// textureDataNode: The node in the property tree where texture data is stored (for .xml files). Defaults to "/TextureSelector/liveries/".
#// enableMultiplayer: Set to 1 to enable multiplayer synchronization for the selected texture. Defaults to 0.
#// multiplayerProperty: The multiplayer property. Only be used if enableMultiplayer is set to 1. Default to be /sim/multiplay/generic/string[19] (The last string property in the MP Protocol).
#// texturePrePath: The prefix path for texture files. Must end with '/'. Defaults to "".
#// defaultValue: The default texture value to set. Defaults to "".
#//
#// Returns the TextureSelector instance.
#//
#// Example usage:
#// var liveryPath = props.getNode("sim/aircraft-dir").getValue() ~ "/Models/Liveries/FollowmeEV/";
#// var liverySelector = TextureSelector.new(name: "Livery-Selector", path: liveryPath, fileType: ".xml", textureProp: "texture-fuse", enableMultiplayer: 1, defaultValue: "Yellow(Default)");
#// Dialog: YourNameSpace.liverySelector.dialog.open()

#// Notes on Multiplayer: This texture selector implements the MP in a different
#// way than the current default behavior used by FG aircrafts, which does
#// polling on a livery property. Instead, a generic MP property is used to
#// transmit the livery (or other textures) information. I'm personally not sure
#// about the impact on performacne by doing this, but this will at least improve
#// the user experience as any changes on the livery (or other textures) will be
#// reflected over MP at real time. This is a big part of the reason I wrote
#// this system instead of using the existing one.

var TextureSelector = {
    new: func(name, path, fileType = nil, enableNone = 0, customDialog = 0, customDialogBase = "",
            customDialogPosition = "", texturePropertyBase = "sim/model/livery/", textureProp = "livery", textureNameProp = "name",
            textureDataNode = nil, enableMultiplayer = 0, multiplayerProperty = "/sim/multiplay/generic/string[19]",
            texturePrePath = "", defaultValue = ""){

        #//Add the slash and the end of the path if it's not there already
        if(right(path, 1) != "/"){
            path = path ~ "/";
            print("Texture selector: ‘/’ added in the end of the path");
        }

        var m = {parents:[TextureSelector]};
        if(customDialog == 1){
            m.dialogNode = props.getNode(customDialogBase, 1);
        }else{
            m.dialogBaseNode = props.getNode("/sim/gui/dialogs/TextureSelector", 1).getNode(name, 1).getNode("dialog", 1);
            m.dialog = TextureSelectorDialog.new(dialogBase : m.dialogBaseNode, defaultV: defaultValue, name: name);
            m.dialogLis = setlistener(m.dialogBaseNode.getNode("opened", 1), func m.dialogTriggered());
        }
        if(textureDataNode == nil) textureDataNode = props.getNode("/TextureSelector/liveries/", 1);

        m.name = name;
        m.path = path;
        m.fileType = fileType;
        m.enableNone = enableNone;
        m.customDialog = customDialog;
        m.dialogCustom = customDialogPosition;
        m.texturePropertyBase = texturePropertyBase;
        m.textureProp = textureProp;
        m.texturePrePath = texturePrePath;#//Tmp Node: must end with /
        m.textureNameProp = textureNameProp;
        m.textureDataNode = textureDataNode;
        m.defaultValue = defaultValue;
        m.enableMultiplayer = enableMultiplayer;
        m.multiplayerProperty = multiplayerProperty;
        m.updateList();
        if(defaultValue and m.fileType == ".xml"){
            m.setTextureByNameXML(defaultValue);
            print("Texture selector: Default value is " ~ defaultValue);
        }else if(defaultValue){
            props.getNode(m.texturePropertyBase, 1).getNode(m.textureProp, 1).setValue(m.texturePrePath ~ defaultValue ~ m.fileType);
        }
        if(enableMultiplayer) props.getNode(multiplayerProperty, 1).alias(props.getNode(m.texturePropertyBase, 1).getNode(m.textureProp, 1));
        return m;
    },
    path: "", #//path containing texture file
    fileType: "",
    enableNone: 0,
    customDialog: 0,
    dialogCustom:"list/",
    texturePropertyBase: "sim/model/livery/",
    textureProp:"livery",
    textureNameProp:"name",
    defaultValue:"",
    dialogNode:nil,
    dialog:nil,
    current:nil,
    textureDataNode:props.getNode("/TextureSelector/liveries/", 1),
    enableMultiplayer: 0, #//The property will be transmitted via MP if enabled.
    multiplayerProperty: "/sim/multiplay/generic/string[19]", #// The multiplayer property. Only be used if enableMultiplayer is set to 1. Default to be /sim/multiplay/generic/string[19](The last string property in the MP Protocol)
    scan: func(path = nil, fileType = nil){
        if(path == nil and me.path) path = me.path;
        else return 1;
        if(fileType == nil and me.fileType) fileType = me.fileType;
        else return 1;
        var data = [];
        var files = directory(path);
        if (size(files)) {
            foreach (var file; files) {
                if (substr(file, 0 - size(fileType)) != fileType)
                    continue;
                append(data, [substr(file, 0, size(file) - size(fileType)), path ~ file]);
            }
            #me.data = sort(me.data, func(a, b) num(a[1]) == nil or num(b[1]) == nil
            #        ? cmp(a[1], b[1]) : a[1] - b[1]);
        }
        return data;
    },
    scanXML: func(path = nil){
        if(path == nil and me.path) path = me.path;
        else return 1;
        var fileType = ".xml";
        var names = [];
        var files = directory(path);
        if (size(files)) {
            var i = 0;
            foreach (var file; files) {
                if (substr(file, 0 - size(fileType)) != fileType)
                    continue;
                var node = me.textureDataNode.getChild(me.textureProp, i, 1); #//Temporary solution, to be improved
                n = io.read_properties(me.path ~ file, node);
                if(n == nil) continue;
                var data = [];
                append(data, n.getNode(me.texturePropertyBase ~ me.textureNameProp).getValue());
                append(names, data);
                i+=1;
            }
        }
        return names;
    },
    updateList: func(){
        var allItems = nil;
        if(me.fileType != ".xml") allItems = me.scan();
        else allItems = me.scanXML();
        var data = nil;
        if(me.customDialog) data = me.dialogNode.getNode(me.dialogCustom, 1); #//Pass the custom dialog if used
        else data = me.dialog.list;
        data.removeChildren("value");
        if(me.enableNone){
            data.getChild("value", 0, 1).setValue("NONE");
            forindex(var i; allItems){
                data.getChild("value", i+1, 1).setValue(allItems[i][0]);
            }
        }else{
            forindex(var i; allItems){
                data.getChild("value", i, 1).setValue(allItems[i][0]);
            }
        }
    },
    dialogTriggered: func(){
        if(me.dialogBaseNode.getNode("opened", 1).getValue() == 1){
            #//print("Dialog opened");
            me.updateList();
            me.resultLis = setlistener(me.dialog.result, func(){
               var selected = me.dialog.result.getValue();
               if(selected != "none"){
                   me.current = selected;
                   if(me.fileType == ".xml") me.setTextureByNameXML(selected);
                   else props.getNode(me.texturePropertyBase, 1).getNode(me.textureProp, 1).setValue(me.texturePrePath ~ me.current ~ me.fileType);
               }else{
                   #fileNode.setValue(nameNode.getValue());
               }
            });
        }else{
            removelistener(me.resultLis);
        }
    },
    setTextureByNameXML: func(name){
        allTextures = me.textureDataNode.getChildren(me.textureProp);
        foreach(var texture; allTextures){
            var tmp = texture.getNode(me.texturePropertyBase);
            if(tmp.getNode(me.textureNameProp).getValue() == name){
                props.copy(tmp, props.getNode(me.texturePropertyBase));
                print("Texture " ~ tmp.getNode(me.textureProp).getValue() ~ " Set");
                #if(me.enableMultiplayer){
                #    props.getNode(me.multiplayerProperty, 1).setValue(texture.getNode(me.texturePropertyBase).getNode(me.textureProp).getValue());
                #}
                break;
            }
        }
    },
};

#// Class: TextureSelectorDialog
#// Constructor: new()
#// Creates a new Texture Selector Dialog instance.
#// Note that this is already handled by TextureSelector internally and there
#// is no need to create it yourself.
#// dialogBase: The base node for the custom dialog.
#// dialogFile: The path to the XML file that defines the dialog layout. Defaults to "Aircraft/followme_e-tron/gui/dialogs/livery-select.xml".
#// defaultV: The default value for the texture selection. Defaults to an empty string.
#// name: The name of the dialog. Defaults to "Texture selection".
#// Returns the TextureSelectorDialog instance.
#// Example usage:
#// var customDialog = TextureSelectorDialog.new(dialogBase, "path/to/custom_dialog.xml", "defaultTextureName", "Custom Dialog Title");

var TextureSelectorDialog = {
    new: func(dialogBase, dialogFile = "Aircraft/followme_e-tron/gui/dialogs/livery-select.xml", defaultV = "", name = "Texture selection"){
        var m = gui.Dialog.new(dialogBase, dialogFile, name);
        m.parents = [TextureSelectorDialog, gui.Dialog];
        m.dialogNode = dialogBase;
        m.dialogFile = dialogFile;
        m.title = name;
        m.list = m.dialogNode.getNode("list", 1);
        m.result = props.getNode(m.list.getPath() ~ "/result", 1);
        m.defaultValue = defaultV;
        m.nasal = m.dialogNode.getNode("nasal", 1);
        m.openScript = m.nasal.getNode("open", 1);
        m.closeScript = m.nasal.getNode("close", 1);
        m.openScript.setValue('print("' ~ m.title ~ ' dialog opened");
        props.getNode(cmdarg().getPath()).getNode("opened"), 1).setValue(1);');
        m.closeScript.setValue('props.getNode(cmdarg().getPath()).getNode("opened", 1).setValue(0);');
        m.reload();
        #Reload when the GUI is reloaded
        m.reload_listener = setlistener("/sim/signals/reinit-gui", func(n) m.reload());

        return m;
    },
    reload: func(){
        me.list.getNode("property").setValue(me.result.getPath());
        me.result.setValue(me.result.getValue() or me.defaultValue);
        me.openScript.setValue('print("' ~ me.title ~ ' dialog opened");
        props.getNode(cmdarg().getPath()~"/opened", 1).setValue(1);');
        me.closeScript.setValue('followme.playAudio("repair.wav");
        props.getNode(cmdarg().getPath()).getNode("opened", 1).setValue(0);');
        me.dialogNode.getNode("group/text/label").setValue(me.title);
        me.dialogNode.getNode("group/button/binding/script").setValue('gui.Dialog.instance["' ~ me.dialogNode.getNode("name").getValue() ~ '"].close()');
    }
};
