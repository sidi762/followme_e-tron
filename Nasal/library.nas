#//Follow Me Library by Sidi Liang
#//Contact: sidi.liang@gmail.com

io.include("texture-selector.nas");

var Debugger = {
    new: func(name = "Debugger"){
        return { parents:[Debugger], name: name };
    },

    _debugLevel: 0,
    debugPrint: func(info, debugLevel){
        if(debugLevel <= me._debugLevel) print(me.name ~ ": " ~ info);
    },
    setDebugLevel: func(debugLevel){
        me._debugLevel = debugLevel;
        print(me.name ~ "Debugger debug level set to" ~ debugLevel);
    },
};

var isInternalView = func(){ #// return 1 if is in internal view, otherwise return 0.
    return props.getNode("sim/current-view/internal", 1).getValue();
}

var Sound = {
    new: func(filename, volume = 1, path=nil) {
        var m = props.Node.new({
            path : path,
            file : filename,
            volume : volume,
        });
        return m;
     },
};
var window = screen.window.new(10, 10, 3, 10);

var outputUI = func(content, timeout = 10){
  window.autoscroll = timeout;
  timeNow = systime();
  if(content != getprop("/systems/outputUIContent") or (timeNow - timeout) >= getprop("/systems/lastOutputUITime")){
      window.write(content);
      setprop("/systems/outputUIContent",content);
      setprop("/systems/lastOutputUITime",systime());
      #print("Outputed");
  }
}
var playAudio = func(file, audioVolume=1, audioPath=""){ #//Plays audio files in Aircrafts/Sounds
    if(!audioPath) audioPath = props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Sounds';
    fgcommand("play-audio-sample", Sound.new(filename: file, volume: audioVolume, path: audioPath));
}

var runCode = func(url, addition = nil){
    #var params = {url:"http://fgprc.org:11415/", targetnode:"/systems/code", complete: completed};
    http.save(url~addition, getprop('/sim/fg-home') ~ '/cache/code.xml').done(func(r){
        var blob = io.read_properties(getprop('/sim/fg-home') ~ '/cache/code.xml');
        var filename = "/cache/code.xml";
        var script = blob.getValues().code; # Get the nasal string
        var code = call(func {
            compile(script, filename);
        }, nil, nil, var compilation_errors = []);
        if(size(compilation_errors)){
            die("Error compiling code in: " ~ filename);
        }
        call(code, [], nil, nil, var runtime_errors = []);

        if(size(runtime_errors)){
            die("Error calling code compiled loaded from: " ~ filename);
        }
        var path = os.path.new(getprop('/sim/fg-home') ~ '/cache/code.xml');
        path.remove();
        print("Code loaded");
    });
}

var universalVariableDebug = Debugger.new("Universal Variable");
universalVariableDebug.setDebugLevel(2);

var Variable = {
    #//The class for a "universal variable"
    #//testingVariable = Variable.new("test", "testing", "This is a node for testing", 0, 1, 1, "/systems/testingNode");
    new: func(name, value = 0, note = nil, readOnly = 0, usePropertyTree = 0, listenPropertyTree = 1, property = nil){
        var m = {parents:[Variable]};
        m._name = name;
        m._value = value;
        m._note = note;
        m._readOnly = readOnly;
        m._usePropertyTree = usePropertyTree;
        m._listenPropertyTree = listenPropertyTree;
        m._property = property;
        m._propertyNodeInitialized = 0;

        if(usePropertyTree){
            m._propertyNode = props.getNode(property, 1);
            m._propertyNode.setValue(value);
            m._propertyNodeInitialized = 1;
            universalVariableDebug.debugPrint(m._name~" : Property Initialized", 2);
            if(listenPropertyTree){
                m._propertyListener = setlistener(property, func m._updateValueFromProperty(), 0, 1);
                universalVariableDebug.debugPrint(m._name~" : listener Initialized", 2);
            }
        }
        return m;
    },
    _updateValueFromProperty: func(){
        if(!me._readOnly){
            me._value = me._propertyNode.getValue();
            universalVariableDebug.debugPrint(me._name~" Value updated from property", 1);
            return 1;
        }else{
            universalVariableDebug.debugPrint("Error when updating "~me._name~" from property: Cannot write to a read only node", 1);
            return 0;
        }
    },
    setValue: func(value){
        if(!me._readOnly){
            me._value = value;
            if(me._usePropertyTree) me._propertyNode.setValue(value);
            return 1;
        }else{
            universalVariableDebug.debugPrint("Error when writing to "~me._name~" : Cannot write to a read only node", 1);
            return 0;
        }
    },
    getValue: func(){
        return me._value;
    },
    setProperty: func(property){
        me._property = property;
        me._propertyNode = props.getNode(property, 1);
        me._propertyNodeInitialized = 1;
    },
    setUsePropertyTree: func(value){
        if(me._propertyNodeInitialized){
            me._usePropertyTree = value;
            if(!value and me._listenPropertyTree){
                removeListener(me._propertyListener);
                universalVariableDebug.debugPrint(me._name~" : listener removed", 2);
            }else if(value and me._listenPropertyTree){
                me._propertyListener = setlistener(property, func m._updateValueFromProperty, 0, 1);
                universalVariableDebug.debugPrint(me._name~" : listener (re)added", 2);
            }
            return 1;
        }else{
            universalVariableDebug.debugPrint("Error when (dis)enabling property tree of "~me._name~" : property node not initialized", 1);
            return 0;
        }
    },
    isUsingPropertyTree: func(){
        return me._usePropertyTree;
    },
    setListenPropertyTree: func(value){
        if(me._usePropertyTree){
            if(value){
                me._propertyListener = setlistener(property, func m._updateValueFromProperty, 0, 1);
                informationNodeDebug.debugPrint(me._name~" : listener added", 2);
            }else{
                removeListener(me._propertyListener);
                informationNodeDebug.debugPrint(me._name~" : listener removed", 2);
            }
            return 1;
        }else{
            informationNodeDebug.debugPrint("Error when setting listeners of "~me._name~" : not using property tree", 1);
        }
    },
    isListeningPropertyTree: func(){
        return me._listenPropertyTree;
    },
};
