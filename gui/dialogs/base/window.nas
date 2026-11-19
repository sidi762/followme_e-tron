# FlightGear allocates the decoration in logical pixels when sizing a dialog.
# Configure it after the window's final size is known so both layers are sharp.
var styleVehicleWindow = func(win) {
	var titleHeight = 32;
	var centerY = titleHeight / 2;
	win._title_bar_height = titleHeight;
	win.setInt("shadow-radius", 0).setInt("shadow-inset", 0);
	win.set("decoration-border", "32 1 1").setBool("update", 1);
	# Filtered decoration texels already contain RGB multiplied by their coverage.
	win.set("blend-source-rgb", "one").set("blend-destination-rgb", "one-minus-src-alpha");
	var deco = win.getCanvasDecoration();
	deco.setBool("mipmapping", 1);
	win._frame.hide();
	win._top_line.hide();
	var decoration = deco.getGroup("decoration");
	var bar = decoration.getElementById("title_bar");
	var images = getprop("/sim/aircraft-dir") ~ "/gui/images/";
	# One image draws the header, its divider and the four edges. Skip the center:
	# FlightGear places the content canvas inside the frame, above the decoration.
	var surface = decoration.createChild("image", "vehicle-frame")
		.setFile(images ~ "window-frame.png").set("z-index", -1)
		.set("slice", "64 16 6").set("slice-width", "32 8 3")
		.set("fill", "#f5f5f7");
	var dragArea = win._title_bar_bg.set("fill-opacity", 0).set("z-index", 1);
	win._resizeDecoration = func {
		var (w, h) = win.getSize();
		w += 2;
		h += titleHeight + 1;
		deco.setInt("view[0]", w).setInt("view[1]", h)
			.setInt("size[0]", 2*w).setInt("size[1]", 2*h);
		surface.setSize(w, h);
		dragArea.reset().rect(0, 0, w, titleHeight);
	};
	win._resizeDecoration();
	# The capitals are about 10.5 px tall at 15 px. A fixed baseline keeps
	# their center aligned with the close icon even in titles containing g or y.
	win._title.setAlignment("left-baseline").setTranslation(40, centerY + 5.25)
		.set("character-size", 15).set("font-resolution", 30);
	bar.getElementById("WindowButton-close").hide();
	var close = bar.createChild("group", "options-close").setTranslation(5, centerY - 13).set("z-index", 2);
	var hit = close.createChild("path").rect(0, 0, 28, 26, {"border-radius": 6}).set("fill", "#f5f5f7");
	var glyph = close.createChild("image").setFile(images ~ "close-mask.png")
		.setSize(16, 16).setTranslation(6, 5).setBool("capture-events", 0);
	close.addEventListener("mouseenter", func hit.set("fill", "#e4e5e8"));
	close.addEventListener("mouseleave", func hit.set("fill", "#f5f5f7"));
	close.addEventListener("mousedown", func hit.set("fill", "#d6d7db"));
	close.addEventListener("drag", func(e) e.stopPropagation());
	close.addEventListener("click", func win.onClose());

	# Anchor to the press point on the Canvas desktop so dropped or coalesced
	# motion events cannot accumulate a window offset.
	var anchor = nil;
	dragArea.addEventListener("mousedown", func(e) {
		if (e.button != 0) return;
		var (x, y) = win.getPosition();
		anchor = [e.screenX - x, e.screenY - y];
		win.raise();
		e.stopPropagation();
	});
	dragArea.addEventListener("drag", func(e) {
		if (anchor != nil)
			win.setPosition(e.screenX - anchor[0], e.screenY - anchor[1]);
		e.stopPropagation();
	});
	var release = func { anchor = nil; };
	dragArea.addEventListener("dragend", release);
	dragArea.addEventListener("mouseup", release);
	var tint = func(active) {
		win._title.set("fill", active ? "#1d1d1f" : "#65656b");
		glyph.set("fill", active ? "#575960" : "#77777d");
	};
	tint(win._focused);
	deco.addEventListener("wm.focus-in", func tint(1));
	deco.addEventListener("wm.focus-out", func { release(); tint(0); });
};

# Cocoa SCROLL_2D falls through Canvas and reaches FGMouseInput as buttons 3/4.
# Return the disconnect function so the owner can release both listeners on close.
var bindVehicleScroll = func(win, host, scroll, step, enabled=func 1) {
	var overList = nil;
	host.addEventListener("mouseenter", func { overList = 1; });
	host.addEventListener("mouseleave", func { overList = 0; });
	win.getCanvas().addEventListener("wm.focus-out", func { overList = 0; });
	win.getCanvas().addEventListener("wm.focus-in", func { overList = nil; });
	var mouse = props.getNode("/devices/status/mice/mouse[0]", 1);
	var modes = props.getNode("/input/mice/mouse[0]", 1);
	var pulse = func(n) {
		if (!n.getBoolValue() or !scroll._max_scroll[1] or !enabled()) return;
		var mode = modes.getChild("mode", mouse.getValue("mode"));
		if (mode == nil or !mode.getValue("pass-through") or mouse.getValue("button[2]")) return;
		if (overList == nil) {
			# Opening the window under a stationary pointer produces no enter event.
			if (canvas.gui.focused_window != win) return;
			var origin = win.toScreenPosition(host.localToCanvas([0, 0]));
			var x = mouse.getValue("x");
			var y = mouse.getValue("y");
			if (x == nil or y == nil or x < origin[0] or x >= origin[0] + scroll._size[0]
				or y < origin[1] or y >= origin[1] + scroll._size[1]) return;
		} elsif (!overList) return;
		var distance = n.getIndex() == 3 ? -step : step;
		scroll.scrollBy(0, distance);
	};
	var listeners = [];
	foreach (var button; [3, 4])
		append(listeners, setlistener(mouse.getChild("button", button, 1), pulse, 0, 0));
	return func { foreach (var id; listeners) removelistener(id); };
};
