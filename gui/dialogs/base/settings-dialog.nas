io.include("window.nas");

# Shared Canvas window lifecycle, settings controls and keyboard focus.
var SettingsDialog = {
	_window: nil,
	_bg: "#f5f5f7",
	_ink: "#1d1d1f",
	_secondary: "#515158",
	_blue: "#005bc4",
	_font: "LiberationFonts/LiberationSans-Regular.ttf",
	_bold: "LiberationFonts/LiberationSans-Bold.ttf",

	# FlightGear owns the named dialog lifecycle. Its XML open/close hooks
	# call the two Canvas methods below, including during a GUI reset.
	open: func {
		if (me._window != nil) {
			me._window.raise();
			return;
		}
		fgcommand("dialog-show", props.Node.new({"dialog-name": me._dialogName}));
	},

	close: func {
		if (me.is_open()) fgcommand("dialog-close", props.Node.new({"dialog-name": me._dialogName}));
	},

	_openCanvas: func {
		var desktopW = getprop("/sim/gui/canvas/size[0]");
		var desktopH = getprop("/sim/gui/canvas/size[1]");
		var w = math.min(380, desktopW - 16);
		me._width = w - 32;
		me._items = [];
		me._listeners = [];
		me._focusIndex = -1;
		me._pickers = {};
		var dialog = me;
		var win = canvas.Window.new([w, 300], "dialog", me._id);
		me._window = win;
		win.setTitle(me._title);
		win.onClose = func dialog.close();
		me._canvas = win.createCanvas();
		me._canvas.set("background", me._bg);
		var host = me._canvas.createGroup();
		me._scroll = canvas.gui.widgets.ScrollArea.new(host);
		me._scroll.setColorBackground([245/255, 245/255, 247/255]);
		me._scroll._view.vert.set("stroke", "#92939b");
		me._scroll._view.horiz.hide();
		var content = me._scroll.getContent();
		var extent = content.createChild("path").set("fill", "none");
		me._body = content.createChild("group", "options").setTranslation(16, 10);
		var fullH = me._build() + 18;
		# Include the margins in the scrollable extent, even before fonts are laid out.
		extent.rect(0, 0, w - 1, fullH).update();
		var h = math.min(fullH, math.max(80, desktopH - 68));
		win.setSize(w, h);
		win.setPosition(math.clamp(100, 4, desktopW - w - 4),
			math.clamp(100, 30, desktopH - h - 36));
		me._canvas.setInt("size[0]", 2 * w).setInt("size[1]", 2 * h);
		me._canvas.setInt("view[0]", w).setInt("view[1]", h);
		me._canvas.setBool("mipmapping", 1);
		styleVehicleWindow(win);
		me._scroll.setSize(w, h);
		me._scroll._view.vert.setVisible(fullH > h);
		me._scroll.update();
		me._canvas.addEventListener("keydown", func(e) dialog._key(e));

		me._disconnectWheel = bindVehicleScroll(win, host, me._scroll, 28, func dialog._picker == nil);
		me._canvas.addEventListener("wm.focus-out", func dialog._dismissPicker(0));
		me._body.setFocus();
		me._canvas.update();
	},

	is_open: func me._window != nil,
	toggle: func { if (me.is_open()) me.close(); else me.open(); },
	_picker: nil,
	_onClose: func {},

	_closeCanvas: func {
		if (me._window == nil) return;
		me._dismissPicker(0);
		foreach (var picker; values(me._pickers)) picker.disconnect();
		me._pickers = nil;
		me._disconnectWheel();
		me._disconnectWheel = nil;
		me._onClose();
		foreach (var id; me._listeners) removelistener(id);
		me._window.del();
		me._window = me._canvas = me._scroll = me._body = nil;
		me._items = me._listeners = nil;
	},

	_text: func(parent, x, y, value, size, color, bold=0, align="left-center") {
		return parent.createChild("text").setText(value).setAlignment(align)
			.setFont(bold ? me._bold : me._font).set("character-size", size)
			.set("font-resolution", size * 2).set("fill", color)
			.setTranslation(x, y);
	},

	# Focus follows the displayed row order and scrolls off-screen controls into view.
	_register: func(group, y, activate, focusStyle, keyboardAdjust=nil) {
		var index = size(me._items);
		append(me._items, {group: group, y: y + 10, activate: activate,
			paintFocus: focusStyle, adjust: keyboardAdjust});
		var dialog = me;
		group.addEventListener("mousedown", func(e) dialog._focus(index, 0));
	},

	_focus: func(index, keyboard) {
		if (me._focusIndex >= 0) me._items[me._focusIndex].paintFocus(0);
		me._focusIndex = index;
		var item = me._items[index];
		item.group.setFocus();
		item.paintFocus(keyboard);
		if (keyboard) {
			var top = me._scroll._content_pos[1];
			var height = me._window.getSize()[1];
			if (item.y < top) me._scroll.scrollTo(0, item.y - 6);
			elsif (item.y + 26 > top + height) me._scroll.scrollTo(0, item.y + 32 - height);
		}
	},

	_key: func(e) {
		if (me._picker != nil) { me._pickerKey(e); return; }
		if (e.key == "Escape" or e.key == "Esc") me.close();
		elsif (e.key == "Tab") {
			var count = size(me._items);
			var i = me._focusIndex;
			me._focus(math.mod(i < 0 ? (e.shiftKey ? count - 1 : 0) :
				i + (e.shiftKey ? count - 1 : 1), count), 1);
		} elsif (me._focusIndex >= 0) {
			var item = me._items[me._focusIndex];
			if ((e.key == "Enter" or e.key == " " or e.key == "Space") and item.activate != nil) item.activate();
			elsif (item.adjust != nil and (e.key == "Left" or e.key == "Right"))
				item.adjust(e.key == "Right" ? 1 : -1);
			else return;
		} else return;
		e.stopPropagation();
	},

	_watch: func(path, callback, initial=1) {
		append(me._listeners, setlistener(path, func(n) callback(n.getValue()), initial, 0));
	},

	_heading: func(y, title) {
		me._text(me._body, 0, y + 7, title, 13, me._secondary);
		return y + 19;
	},

	# Exclusive choices use a tint. Only independent settings draw a checkbox.
	_button: func(x, y, w, title, action, checkbox=0) {
		var g = me._body.createChild("group", title).setTranslation(x, y);
		var bg = g.createChild("path", "surface").rect(0.5, 0.5, w - 1, 24, {"border-radius": 6})
			.set("stroke-width", 1);
		var box = nil;
		var check = nil;
		if (checkbox) {
			box = g.createChild("path", "box").rect(6.5, 4.5, 16, 16, {"border-radius": 3})
				.set("stroke-width", 1);
			check = g.createChild("path", "check").moveTo(10, 12.5).lineTo(13, 15.5).lineTo(19, 9.5)
				.set("fill", "none").set("stroke", "#ffffff").set("stroke-width", 1.75)
				.set("stroke-linecap", "round").set("stroke-linejoin", "round");
		}
		var label = me._text(g, checkbox ? 30 : int(w / 2), 12, title, 14, me._ink,
			0, checkbox ? "left-center" : "center-center");
		var state = {selected: 0, hover: 0, down: 0, focus: 0};
		var paint = func {
			var selected = state.selected and !checkbox;
			bg.set("fill", selected ? (state.down ? "#c9dffc" : (state.hover ? "#d5e7fc" : "#e1edfc")) :
				(state.down ? "#dce5f0" : (state.hover ? "#eaf1fa" : (checkbox ? "#f5f5f7" : "#ffffff"))));
			bg.set("stroke", state.focus ? "#007aff" : (selected ? "#a1c5ed" :
				(checkbox ? "#f5f5f7" : "#c9cbd1")));
			bg.set("stroke-width", state.focus ? 2 : 1);
			label.set("fill", selected ? "#004caa" : "#1d1d1f");
			if (checkbox) {
				box.set("fill", state.selected ? "#005bc4" : "#ffffff")
					.set("stroke", state.selected ? "#005bc4" : "#888b92");
				check.setVisible(state.selected);
			}
		};
		g.addEventListener("mouseenter", func { state.hover = 1; paint(); });
		g.addEventListener("mouseleave", func { state.hover = state.down = 0; paint(); });
		g.addEventListener("mousedown", func { state.down = 1; paint(); });
		g.addEventListener("mouseup", func { state.down = 0; paint(); });
		g.addEventListener("click", func action());
		me._register(g, y, action, func(show) { state.focus = show; paint(); });
		paint();
		return func(selected) { state.selected = selected; paint(); };
	},

	_choice: func(x, y, w, title, path, value) {
		var select = me._button(x, y, w, title, func setprop(path, value));
		me._watch(path, func(v) select(v != nil and math.abs(v - value) < 0.001));
	},

	_checkbox: func(y, text, path) {
		var select = me._button(0, y, me._width, text, func setprop(path, !getprop(path)), 1);
		me._watch(path, func(value) select(value == 1));
	},

	_dropdown: func(y, w, path, values) {
		var dialog = me;
		if (getprop(path) == nil and size(values)) setprop(path, values[0]);
		var g = me._body.createChild("group", path).setTranslation(0, y);
		var bg = g.createChild("path").rect(0.5, 0.5, w - 1, 25, {"border-radius": 6})
			.set("fill", "#ffffff").set("stroke", "#c9cbd1").set("stroke-width", 1);
		var label = me._text(g, 10, 13, "", 14, me._ink);
		g.createChild("path").moveTo(w - 19, 11).lineTo(w - 15, 15).lineTo(w - 11, 11)
			.set("fill", "none").set("stroke", me._secondary).set("stroke-width", 1.5);
		var openList = func dialog._openPicker(g, w, path, values);
		me._register(g, y, openList, func(focus) bg.set("stroke", focus ? "#007aff" : "#c9cbd1"));
		g.addEventListener("click", openList);
		me._watch(path, func(value) {
			label.setText(value == nil ? "" : value);
			if (dialog._picker != nil and dialog._picker.path == path)
				forindex (var i; values) if (values[i] == value) dialog._highlightPicker(i);
		});
	},

	# Place the list in window coordinates so it remains accessible when the form is scrolled.
	_openPicker: func(anchor, width, path, values) {
		me._dismissPicker(0);
		if (!size(values)) return;
		var (x, y) = anchor.localToCanvas([0, 0]);
		var h = me._window.getSize()[1];
		var below = math.max(0, h - y - 30);
		var above = math.max(0, y - 4);
		var listH = math.min(24 * size(values), 216, math.max(below, above));
		var picker = me._pickers[path];
		if (picker == nil) {
			picker = me._makePicker(anchor, width, path, values);
			me._pickers[path] = picker;
		}
		me._picker = picker;
		picker.height = listH;
		picker.host.setTranslation(x, below >= listH ? y + 28 : y - listH - 2);
		picker.overlay.show();
		picker.frame.reset().rect(-1, -1, width + 2, listH + 2, {"border-radius": 3});
		picker.scroll.setSize(width, listH);
		picker.scroll._view.vert.setVisible(listH < size(values) * 24);
		var value = getprop(path);
		var active = 0;
		forindex (var i; values) if (values[i] == value) active = i;
		me._highlightPicker(active);
		picker.host.setFocus();
	},

	# Keep the popup graph for the lifetime of the form. Removing the event target
	# during a Canvas click can invalidate the renderer's active dispatch path.
	_makePicker: func(anchor, width, path, items) {
		var dialog = me;
		var (w, h) = me._window.getSize();
		var overlay = me._canvas.createGroup("settings-picker-" ~ path).set("z-index", 20);
		var backdrop = overlay.createChild("path").rect(0, 0, w, h).setColorFill(0, 0, 0, 0);
		backdrop.addEventListener("click", func dialog._dismissPicker(1));
		var host = overlay.createChild("group");
		var frame = host.createChild("path").set("fill", "#c9cbd1");
		var scroll = canvas.gui.widgets.ScrollArea.new(host);
		scroll.setColorBackground([1, 1, 1]);
		scroll._view.horiz.hide();
		scroll._view.vert.set("stroke", "#92939b");
		var content = scroll.getContent();
		content.createChild("path").rect(0, 0, width, size(items) * 24).set("fill", "#ffffff").update();
		var picker = {overlay: overlay, anchor: anchor, host: host, frame: frame, scroll: scroll, rows: [],
			values: items, path: path, index: 0, height: 0};
		var choose = func(value) func { setprop(path, value); dialog._dismissPicker(1); };
		var hover = func(index) func {
			if (dialog._picker == picker) dialog._highlightPicker(index, 0);
		};
		forindex (var i; items) {
			var row = content.createChild("group", "choice-" ~ i).setTranslation(0, i * 24);
			var bg = row.createChild("path").rect(0, 0, width - 5, 24).set("fill", "#ffffff");
			me._text(row, 10, 12, items[i], 14, me._ink);
			append(picker.rows, bg);
			row.addEventListener("click", choose(items[i]));
			row.addEventListener("mouseenter", hover(i));
		}
		picker.disconnect = bindVehicleScroll(me._window, host, scroll, 24, func dialog._picker == picker);
		return picker;
	},

	_highlightPicker: func(i, reveal=1) {
		var p = me._picker;
		p.rows[p.index].set("fill", "#ffffff");
		p.index = math.clamp(i, 0, size(p.values) - 1);
		p.rows[p.index].set("fill", "#e1edfc");
		if (!reveal) return;
		var y = p.index * 24;
		if (y < p.scroll._content_pos[1]) p.scroll.scrollTo(0, y);
		elsif (y + 24 > p.scroll._content_pos[1] + p.height) p.scroll.scrollTo(0, y + 24 - p.height);
	},

	_pickerKey: func(e) {
		var p = me._picker;
		if (e.key == "Escape" or e.key == "Esc") me._dismissPicker(1);
		elsif (e.key == "Enter" or e.key == " ") {
			setprop(p.path, p.values[p.index]);
			me._dismissPicker(1);
		} elsif (e.key == "Up") me._highlightPicker(p.index - 1);
		elsif (e.key == "Down") me._highlightPicker(p.index + 1);
		elsif (e.key == "Home") me._highlightPicker(0);
		elsif (e.key == "End") me._highlightPicker(size(p.values) - 1);
		elsif (e.key == "Tab") { me._dismissPicker(1); me._key(e); return; }
		else return;
		e.stopPropagation();
	},

	_dismissPicker: func(restoreFocus) {
		var p = me._picker;
		if (p == nil) return;
		me._picker = nil;
		p.overlay.hide();
		if (restoreFocus) p.anchor.setFocus();
	},
};
