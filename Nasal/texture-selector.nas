#//Sidi Liang, 2020
#//Docs WIP
#//Texture Selector for Followme EV
#//Quick start:
#//Aircraft liveries with dedicated selection dialog: (The same applies to any texture defined in PropertyList XML):
#//     var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/";
#//     var liverySelector = TextureSelector.new(path: liveryPath, fileType: ".xml", textureProp: "texture-fuse", enableMultiplayer: 1, defaultValue: "Yellow(Default)");
#//Pure texture, custom dialog(without multiplayer):
#//     var path = props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Models/plate/texture';
#//     var plateSelector = TextureSelector.new(path, ".png", 1, 1, "sim/gui/dialogs/vehicle_config/dialog", "group[4]/combo/");


var TextureSelector = { #//Tmp Note: path MUST end with "/"
    new: func(name, path, fileType = nil, enableNone = 0, customDialog = 0, customDialogBase = "",
            customDialogPosition = "", texturePropertyBase = "sim/model/livery/", textureProp = "livery", textureNameProp = "name",
            textureDataNode = nil, enableMultiplayer = 0, multiplayerProperty = "/sim/multiplay/generic/string[19]", defaultValue = ""){

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
        m.textureNameProp = textureNameProp;
        m.textureDataNode = textureDataNode;
        m.defaultValue = defaultValue;
        m.enableMultiplayer = enableMultiplayer;
        m.multiplayerProperty = multiplayerProperty;
        if(defaultValue) m.setTextureByNameXML(defaultValue);
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
            print("Dialog opened");
            me.updateList();
            me.resultLis = setlistener(me.dialog.result, func(){
               var selected = me.dialog.result.getValue();
               if(selected != "none"){
                   me.setTextureByNameXML(selected);
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
                print(tmp.getNode(me.textureProp).getValue());
                props.copy(tmp, props.getNode(me.texturePropertyBase));
                if(me.enableMultiplayer){
                    props.getNode(me.multiplayerProperty, 1).setValue(texture.getNode(me.texturePropertyBase).getNode(me.textureProp).getValue());
                }
                break;
            }
        }
    },
};

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
        m.closeScript.setValue('followme.playAudio("repair.wav");
        props.getNode(cmdarg().getPath()).getNode("opened", 1).setValue(0);');
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
