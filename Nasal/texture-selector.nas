#//Sidi Liang, 2020
#//Docs to be done

var TextureSelector = { #//Tmp Note: path MUST end with "/"
    new: func(path, fileType = nil, enableNone = 0, customDialog = 0, customDialogBase = "",
            customDialogPosition = "", texturePropertyBase = "sim/model/livery/", textureProp = "livery", textureNameProp = "name",
            textureDataNode = nil, defaultValue = ""){

        var m = {parents:[TextureSelector]};
        if(customDialog == 1){
            m.dialogNode = props.getNode(customDialogBase, 1);
        }else{
            m.dialog = TextureSelectorDialog.new(defaultV: defaultValue);
        }
        if(textureDataNode == nil) textureDataNode = props.getNode("/TextureSelector/liveries/", 1);

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
    setTextureByNameXML: func(name){
        allTextures = me.textureDataNode.getChildren(me.textureProp);
        foreach(var texture; allTextures){
            var tmp = texture.getNode(me.texturePropertyBase);
            if(tmp.getNode(me.textureNameProp).getValue() == name){
                print(tmp.getNode(me.textureProp).getValue());
                props.copy(tmp, props.getNode(me.texturePropertyBase));
                props.getNode("/sim/multiplay/generic/string[19]", 1).setValue(texture.getNode(me.texturePropertyBase).getNode(me.textureProp).getValue());
                break;
            }
        }
    },
};

var TextureSelectorDialog = {
    new: func(dialogBase = "/sim/gui/dialogs/TextureSelector/dialog", dialogFile = "Aircraft/followme_e-tron/gui/dialogs/livery-select.xml", defaultV = ""){
        var m = gui.Dialog.new(dialogBase, dialogFile);
        m.parents = [TextureSelectorDialog, gui.Dialog];
        var dNode = props.getNode(dialogBase, 1);
        m.dialogNode = dNode;
        m.dialogFile = dialogFile;
        m.title = "Livery Selection";
        m.list = m.dialogNode.getNode("list", 1);
        m.result = props.getNode(m.list.getPath() ~ "/result", 1);
        m.defaultValue = defaultV;
        m.nasal = m.dialogNode.getNode("nasal", 1);
        m.openScript = m.nasal.getNode("open", 1);
        m.closeScript = m.nasal.getNode("close", 1);
        m.openScript.setValue('print("livery-select dialog opened");
        followme.liverySelector.updateList();
        #print(cmdarg().getPath());
        var lis = setlistener(followme.liverySelector.dialog.result, func(){
           var selected = followme.liverySelector.dialog.result.getValue();
           if(selected != "none"){
               followme.liverySelector.setTextureByNameXML(selected);
           }else{
               #fileNode.setValue(nameNode.getValue());
           }
        });');
        m.closeScript.setValue('\n followme.playAudio("repair.wav");');
        m.reload();
        #Reload when the GUI is reloaded
        m.reload_listener = setlistener("/sim/signals/reinit-gui", func(n) m.reload());

        return m;
    },
    reload: func(){
        me.list.getNode("property").setValue(me.result.getPath());
        me.result.setValue(me.result.getValue() or me.defaultValue);
        me.openScript.setValue('print("livery-select dialog opened");
        followme.liverySelector.updateList();
        #print(cmdarg().getPath());
        var lis = setlistener(followme.liverySelector.dialog.result, func(){
           var selected = followme.liverySelector.dialog.result.getValue();
           if(selected != "none"){
               followme.liverySelector.setTextureByNameXML(selected);
           }else{
               #fileNode.setValue(nameNode.getValue());
           }
        });');
        me.closeScript.setValue('followme.playAudio("repair.wav");');
        me.dialogNode.getNode("group/text/label").setValue(me.title);
        me.dialogNode.getNode("group/button/binding/script").setValue('gui.Dialog.instance["' ~ me.dialogNode.getNode("name").getValue() ~ '"].close()');
    }
};
