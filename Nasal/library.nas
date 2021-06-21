#//Follow Me Library by Sidi Liang
#//Contact: sidi.liang@gmail.com

io.include("texture-selector.nas");

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
