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
#//      var plateSelector = TextureSelector.new(name: "Plate-Selector", path: path, fileType: ".png", enableNone: 1, customDialog: 1);
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
#// dialogTitle: Optional human-readable title for a dedicated selector window.
#// outputNameProp: Destination for the selected name. Defaults to textureNameProp.
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

io.include("../gui/dialogs/base/window.nas");

var TextureSelector = {
    new: func(name, path, fileType = nil, enableNone = 0, customDialog = 0, customDialogBase = "",
            customDialogPosition = "", texturePropertyBase = "sim/model/livery/", textureProp = "livery", textureNameProp = "name",
            textureDataNode = nil, enableMultiplayer = 0, multiplayerProperty = "/sim/multiplay/generic/string[19]",
            texturePrePath = "", defaultValue = "", canvasItemsPropPath = nil, dialogTitle = nil, outputNameProp = nil,
            compactDialog = 0) {

        if(right(path, 1) != "/"){
            path = path ~ "/";
            print("Texture selector: ‘/’ added in the end of the path");
        }

        var m = {parents:[TextureSelector]};

        if(textureDataNode == nil) textureDataNode = props.getNode("/TextureSelector/liveries/", 1);

        m.name = name;
        m.path = path;
        m.fileType = fileType;
        m.enableNone = enableNone;
        m.texturePropertyBase = texturePropertyBase;
        m.textureProp = textureProp;
        m.texturePrePath = texturePrePath;
        m.textureNameProp = textureNameProp;
        m.outputNameProp = outputNameProp or textureNameProp;
        m.textureDataNode = textureDataNode;
        m.defaultValue = defaultValue;
        m.enableMultiplayer = enableMultiplayer;
        m.multiplayerProperty = multiplayerProperty;
        if (canvasItemsPropPath == nil) {
            m._canvasItemsPropPath = "/TextureSelector/liveries/" ~ m.name ~ "/items";
        } else {
            m._canvasItemsPropPath = canvasItemsPropPath;
        }
        m.dialog = nil; # Will hold TextureSelectorDialog instance if customDialog is 0

        if (customDialog == 0) {
            # Create Canvas-based dialog instance
            m.dialog = TextureSelectorDialog.new(m, dialogTitle or m.name, compactDialog);
        }

        m.updateList();

        if(defaultValue){
            m.applyTexture(defaultValue, 1); # Apply default, suppress print for initial setup
        }

        if(enableMultiplayer) {
            var sourceNode = props.getNode(m.texturePropertyBase, 1).getNode(m.textureProp, 1);
            var mpNode = props.getNode(multiplayerProperty, 1);
            if (sourceNode != nil and mpNode != nil) {
                mpNode.alias(sourceNode);
            } else {
                print("TextureSelector: Warning - Could not set up multiplayer alias for " ~ m.name);
            }
        }
        return m;
    },
    # Return the names and disk paths of the textures in this directory.
    scan: func(path=nil, fileType=nil) {
        path = path or me.path;
        fileType = fileType or me.fileType;
        var items = [];
        if (!fileType) return items;
        if (right(path, 1) != "/") path ~= "/";
        foreach (var file; directory(path) or []) {
            if (right(file, size(fileType)) == fileType)
                append(items, [left(file, size(file) - size(fileType)), path ~ file]);
        }
        return items;
    },

    # Read every definition into a fresh tree so an incomplete file cannot inherit
    # the preceding livery's name or texture. Keep the published definition cache.
    scanXML: func(path=nil) {
        var files = me.scan(path, ".xml");
        files = sort(files, func(a,b) cmp(a[1], b[1]));
        me.textureDataNode.removeChildren(me.textureProp);
        me._definitions = {};
        var items = [];
        foreach (var file; files) {
            var doc = io.read_properties(file[1], nil, 1);
            if (doc == nil) continue;
            var entry = doc.getNode(me.texturePropertyBase);
            if (entry == nil) continue;
            var name = entry.getValue(me.textureNameProp);
            var texture = entry.getValue(me.textureProp);
            if (name == nil or name == "" or texture == nil or texture == "" or contains(me._definitions, name)) continue;
            var cached = me.textureDataNode.getChild(me.textureProp, size(items), 1);
            props.copy(doc, cached);
            me._definitions[name] = cached.getNode(me.texturePropertyBase);
            append(items, [name, texture]);
        }
        return items;
    },

    # Rebuild only this selector's rows, including removals since the previous open.
    updateList: func {
        var xml = me.fileType == ".xml";
        var found = xml ? me.scanXML() : me.scan();
        found = sort(found, func(a,b) cmp(string.lc(a[0]), string.lc(b[0])));
        me.items = [];
        me._textures = {};
        var listNode = props.getNode(me._canvasItemsPropPath, 1);
        listNode.removeChildren("value");
        if (me.enableNone) {
            me._textures["NONE"] = "";
            append(me.items, "NONE");
        }
        foreach (var item; found) {
            if (contains(me._textures, item[0])) continue;
            me._textures[item[0]] = xml ? item[1] : me.texturePrePath ~ item[0] ~ me.fileType;
            append(me.items, item[0]);
        }
        forindex (var i; me.items) listNode.getChild("value", i, 1).setValue(me.items[i]);
        me.current = me.selectedName();
    },

    # Resolve the active row from the texture actually used by the vehicle.
    selectedName: func {
        var texture = props.getNode(me.texturePropertyBase, 1).getValue(me.textureProp);
        foreach (var name; me.items) {
            if (me._textures[name] == texture) return name;
        }
        return nil;
    },

    applyTexture: func(name, isDefaultSetup=0) {
        if (name == nil or !contains(me._textures, name)) return 0;
        var target = props.getNode(me.texturePropertyBase, 1);
        if (me.fileType == ".xml" and contains(me._definitions, name)) {
            me.setTextureByNameXML(name, isDefaultSetup);
        } else {
            target.getNode(me.textureProp, 1).setValue(me._textures[name]);
            target.getNode(me.outputNameProp, 1).setValue(name);
        }
        me.current = name;
        return 1;
    },

    # Preserve auxiliary XML fields, while storing the LED sign's name separately
    # from the body livery name even when both definitions call their field "name".
    setTextureByNameXML: func(name, isDefaultSetup=0) {
        if (!contains(me._definitions, name)) return 0;
        var target = props.getNode(me.texturePropertyBase, 1);
        foreach (var field; me._definitions[name].getChildren()) {
            var key = field.getName();
            if (key == me.textureNameProp) key = me.outputNameProp;
            props.copy(field, target.getChild(key, field.getIndex(), 1));
        }
        me.current = name;
        return 1;
    },
};

var TextureSelectorDialog = {
    new: func(selector, title, compact=0) {
        return {parents: [TextureSelectorDialog], _parentSelector: selector,
            _title: title, _window: nil, _rowHeight: 28, _listener: nil,
            _preferredWidth: compact ? 264 : 340, _preferredRows: compact ? 8 : 13};
    },

    # Only the list scrolls. Use the actual Canvas desktop size, which can be
    # smaller than the old 400px window even on a high-DPI screen.
    open: func {
        if (me._window != nil) {
            me._window.raise();
            return;
        }
        var selector = me._parentSelector;
        selector.updateList();
        var dw = getprop("/sim/gui/canvas/size[0]");
        var dh = getprop("/sim/gui/canvas/size[1]");
        var footerHeight = 44;
        var listH = math.max(1, size(selector.items)) * me._rowHeight;
        var w = math.min(me._preferredWidth, dw - 16);
        var available = dh - 64 - footerHeight;
        # Open on whole rows so revealing the last selection leaves a clean top edge.
        var visibleRows = math.clamp(int(available / me._rowHeight), 1, me._preferredRows);
        var h = footerHeight + math.max(1, math.min(listH, visibleRows * me._rowHeight, available));
        me._rows = [];
        me._cursor = -1;
        me._keyboard = 0;
        var dialog = me;
        me._window = canvas.Window.new([w, h], "dialog", selector.name ~ "-TextureDialog");
        me._window.setTitle(me._title);
        me._window.onClose = func dialog.close();
        me._canvas = me._window.createCanvas();
        me._canvas.set("background", "#ffffff").setBool("mipmapping", 1);
        styleVehicleWindow(me._window);
        var root = me._canvas.createGroup("texture-selector");
        var host = root.createChild("group");
        me._scrollArea = canvas.gui.widgets.ScrollArea.new(host);
        me._scrollArea.setColorBackground([1, 1, 1]);
        me._scrollArea._view.vert.set("stroke", "#a6a6ad");
        me._listGroup = me._scrollArea.getContent();
        var extent = me._listGroup.createChild("path").set("fill", "#ffffff");
        forindex (var i; selector.items) me._addRow(i, selector.items[i]);
        if (!size(selector.items)) me._text(me._listGroup, 16, 14, "No entries found", 15);

        var footer = root.createChild("group");
        var separator = footer.createChild("path").set("fill", "#e8e8ec");
        me._currentLabel = me._text(footer, 16, 22, "", 13).set("fill", "#494950");
        var close = footer.createChild("group", "close-button");
        var bg = close.createChild("path").rect(0, 0, 68, 28, {"border-radius": 5}).set("fill", "#ffffff");
        me._text(close, 34, 14, "Close", 14, "center-center").set("fill", "#005bc4");
        close.addEventListener("mouseenter", func bg.set("fill", "#eef3f8"));
        close.addEventListener("mouseleave", func bg.set("fill", "#ffffff"));
        close.addEventListener("mousedown", func bg.set("fill", "#e0e9f2"));
        close.addEventListener("mouseup", func bg.set("fill", "#eef3f8"));
        close.addEventListener("click", func dialog.close());

        me._window.onResize = func {
            var (width, height) = dialog._window.getSize();
            dialog._listHeight = math.max(1, height - footerHeight);
            dialog._canvas.setInt("view[0]", width).setInt("view[1]", height)
                .setInt("size[0]", 2 * width).setInt("size[1]", 2 * height);
            # ScrollArea measures its children as soon as setSize is called.
            extent.reset().rect(0, 0, width, listH).update();
            foreach (var row; dialog._rows)
                row.bg.reset().rect(0.5, 0.5, width - 1, dialog._rowHeight - 1);
            dialog._scrollArea.setSize(width, dialog._listHeight);
            footer.setTranslation(0, dialog._listHeight);
            separator.reset().rect(0, 0, width, 1);
            dialog._currentLabel.setClipByBoundingBox([0, 0, math.max(0, width - 84), footerHeight]);
            close.setTranslation(width - 76, 8);
        };
        me._window.onResize();
        me._disconnectWheel = bindVehicleScroll(me._window, host, me._scrollArea, me._rowHeight);
        me._canvas.addEventListener("keydown", func(e) dialog._key(e));
        root.setFocus();

        me._listener = setlistener(props.getNode(selector.texturePropertyBase, 1).getNode(selector.textureProp, 1),
            func dialog._syncSelection(), 1, 0);
        me._cursor = math.max(0, me._selectedIndex);
        me._revealCursor();
        # Install the placement now so a close/reopen in this frame can remove it.
        me._canvas.update();
    },

    _text: func(parent, x, y, value, px, align="left-center") {
        return parent.createChild("text").setText(value).setAlignment(align)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf").set("character-size", px)
            .set("font-resolution", px * 2).set("fill", "#1d1d1f").setTranslation(x, y);
    },

    # Hit areas fill the row. A single click applies the item and keeps the menu open.
    _addRow: func(i, name) {
        var dialog = me;
        var g = me._listGroup.createChild("group", "row-" ~ i).setTranslation(0, i * me._rowHeight);
        var bg = g.createChild("path", "background").set("fill", "#ffffff");
        var label = me._text(g, 16, 14, name, 15);
        var row = {group: g, name: name, bg: bg, label: label, hover: 0};
        append(me._rows, row);
        g.addEventListener("mouseenter", func { row.hover=1; dialog._paint(i); });
        g.addEventListener("mouseleave", func { row.hover=0; dialog._paint(i); });
        g.addEventListener("click", func {
            dialog._keyboard=0;
            dialog._cursor=i;
            dialog._parentSelector.applyTexture(name);
            dialog._syncSelection();
        });
    },

    _paint: func(i) {
        var row = me._rows[i];
        var selected = i == me._selectedIndex;
        row.bg.set("fill", selected ? "#d4e5fa" : (row.hover ? "#f2f3f5" : "#ffffff"))
            .set("stroke", me._keyboard and i == me._cursor ? "#007aff" : "none");
        row.label.set("fill", selected ? "#193b62" : "#1d1d1f");
    },

    _syncSelection: func {
        var active = me._parentSelector.selectedName();
        me._selectedIndex = -1;
        forindex (var i; me._rows) {
            if (me._rows[i].name == active) me._selectedIndex = i;
        }
        forindex (var i; me._rows) me._paint(i);
        me._currentLabel.setText(active == nil ? "No selection" : "Current: " ~ active);
    },

    _revealCursor: func {
        var y = me._cursor * me._rowHeight;
        var top = me._scrollArea._content_pos[1];
        if (y < top) me._scrollArea.scrollTo(0, y);
        elsif (y + me._rowHeight > top + me._listHeight)
            me._scrollArea.scrollTo(0, y + me._rowHeight - me._listHeight);
    },

    _key: func(e) {
        if (e.key == "Escape" or e.key == "Esc") {
            e.stopPropagation();
            me.close();
            return;
        }
        var last = size(me._rows) - 1;
        if (last < 0) return;
        var old = me._cursor;
        var page = math.max(1, int(me._listHeight / me._rowHeight));
        if (e.key == "Down") me._cursor += 1;
        elsif (e.key == "Up") me._cursor -= 1;
        elsif (e.key == "PageDown" or e.key == "Page_Down") me._cursor += page;
        elsif (e.key == "PageUp" or e.key == "Page_Up") me._cursor -= page;
        elsif (e.key == "Home") me._cursor = 0;
        elsif (e.key == "End") me._cursor = last;
        elsif (e.key == "Enter" or e.key == " ") me._parentSelector.applyTexture(me._rows[old].name);
        else return;
        e.stopPropagation();
        me._keyboard = 1;
        me._cursor = math.clamp(me._cursor, 0, last);
        me._paint(old);
        me._paint(me._cursor);
        me._revealCursor();
    },

    close: func {
        if (me._window == nil) return;
        if (me._listener != nil) removelistener(me._listener);
        me._disconnectWheel();
        me._disconnectWheel = nil;
        me._listener = nil;
        me._window.del();
        me._window = me._canvas = me._scrollArea = me._listGroup = me._currentLabel = nil;
        me._rows = [];
    }
};
