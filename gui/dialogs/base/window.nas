# FlightGear allocates the decoration in logical pixels when sizing a dialog.
# Configure it after the window's final size is known so both layers are sharp.
var styleVehicleWindow = func(win) {
	var titleHeight = 32;
	win._title_bar_height = titleHeight;
	win.setInt("shadow-radius", 0).setInt("shadow-inset", 0);
	win.set("decoration-border", "32 0 0").setBool("update", 1);
	var deco = win.getCanvasDecoration();
	var (width, bodyHeight) = win.getSize();
	var height = bodyHeight + titleHeight;
	deco.setInt("view[0]", width).setInt("view[1]", height)
		.setInt("size[0]", width * 2).setInt("size[1]", height * 2).setBool("mipmapping", 1);
	win._frame.hide();
	win._top_line.hide();
	win._title_bar_bg.reset().rect(0, 0, width, titleHeight, {"border-top-radius": 8});
	win._title.setTranslation(40, 16).set("character-size", 15).set("font-resolution", 30);
	var tintTitle = func {
		win._title_bar_bg.set("fill", "#f5f5f7");
		win._title.set("fill", "#1d1d1f");
	};
	tintTitle();
	deco.addEventListener("wm.focus-in", tintTitle);
	deco.addEventListener("wm.focus-out", tintTitle);

	var bar = deco.getGroup("decoration").getElementById("title_bar");
	bar.getElementById("WindowButton-close").hide();
	var close = bar.createChild("group", "options-close").setTranslation(5, 3);
	var hit = close.createChild("path").rect(0, 0, 28, 26, {"border-radius": 6}).set("fill", "#f5f5f7");
	close.createChild("path").moveTo(9, 8).lineTo(19, 18).moveTo(19, 8).lineTo(9, 18)
		.set("fill", "none").set("stroke", "#575960").set("stroke-width", 1.6).setStrokeLineCap("round");
	close.addEventListener("mouseenter", func hit.set("fill", "#e4e5e8"));
	close.addEventListener("mouseleave", func hit.set("fill", "#f5f5f7"));
	close.addEventListener("mousedown", func hit.set("fill", "#d6d7db"));
	close.addEventListener("click", func win.onClose());
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
