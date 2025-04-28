###############################################################################
# UIWidget Base Class
# Provides common UI creation methods and event handling
###############################################################################

var UIWidget = {
    new: func(dialog, group, name) {
        var m = { 
            parents: [UIWidget],
            _class: "UIWidget",
            _dialog: dialog,
            _listeners: [],
            _name: name,
            _group: group,
            _style: canvas.DefaultStyle.new("AmbianceClassic", "Humanity")
        };
        return m;
    },

    removeListeners: func() {
        foreach(var l; me._listeners) {
            removelistener(l);
        }
        me._listeners = [];
    },

    setListeners: func(instance) {},

    init: func(instance=me) {},

    deinit: func() {
        me.removeListeners();
    },

    createButton: func(x, y, width, height, text, callback) {
        # Create a custom button instead of using the DefaultStyle widget
        var group = me._group.createChild("group")
            .setTranslation(x, y);
        
        # Button background
        var bg = group.createChild("path")
            .rect(0, 0, width, height, {"border-radius": 5})
            .setColor(0.4, 0.4, 0.6)
            .setStrokeLineWidth(1)
            .setColorFill(0.3, 0.3, 0.5);
        
        # Button text
        var label = group.createChild("text")
            .setText(text)
            .setAlignment("center-center")
            .setTranslation(width/2, height/2)
            .setFont("LiberationFonts/LiberationSans-Bold.ttf")
            .set("character-size", 14)
            .setColor(1, 1, 1);
        
        # Click handlers
        if (callback != nil) {
            group.addEventListener("click", callback);
        }
        
        # Hover effects
        group.addEventListener("mouseover", func {
            bg.setColorFill(0.4, 0.4, 0.7);
        });
        
        group.addEventListener("mouseout", func {
            bg.setColorFill(0.3, 0.3, 0.5);
        });
        
        group.addEventListener("mousedown", func {
            bg.setColorFill(0.2, 0.2, 0.4);
        });
        
        group.addEventListener("mouseup", func {
            bg.setColorFill(0.4, 0.4, 0.7);
        });
        
        return group;
    },

    createLabel: func(x, y, text, size=14, alignment="left-center") {
        # Create a direct text element instead of using label widget
        var text_element = me._group.createChild("text")
            .setText(text)
            .setAlignment(alignment)
            .setTranslation(x, y)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", size)
            .setColor(0.9, 0.9, 0.9); # Lighter text color for better contrast
        
        return text_element;
    },

    createCenteredLabel: func(x, y, text, size=14) {
        return me.createLabel(x, y, text, size, "center-center");
    },

    createCheckbox: func(x, y, text, property, callback=nil) {
        # Create a group for the checkbox components
        var group = me._group.createChild("group")
            .setTranslation(x, y);
        
        # Box for the checkbox
        var box = group.createChild("path")
            .rect(0, 0, 16, 16, {"border-radius": 2})
            .setStrokeLineWidth(1)
            .setColor(0.3, 0.3, 0.3)
            .setColorFill(1, 1, 1);
        
        # Check mark (hidden by default)
        var check = group.createChild("path")
            .moveTo(3, 8)
            .lineTo(7, 12)
            .lineTo(13, 4)
            .setStrokeLineWidth(2)
            .setColor(0, 0.6, 0)
            .hide();
        
        # Label
        var label = group.createChild("text")
            .setText(text)
            .setTranslation(22, 8)
            .setAlignment("left-center")
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", 14)
            .setColor(0.9, 0.9, 0.9); # Lighter text color for better contrast
        
        var is_checked = getprop(property) or 0;
        
        # Show check mark if initially checked
        if (is_checked) {
            check.show();
        }
        
        # Toggle function
        var toggle = func {
            is_checked = !is_checked;
            setprop(property, is_checked);
            if (is_checked) {
                check.show();
            } else {
                check.hide();
            }
            if (callback != nil) {
                callback(is_checked);
            }
        };
        
        # Add click handlers
        box.addEventListener("click", toggle);
        label.addEventListener("click", toggle);
        
        # Add property listener
        append(me._listeners, 
            setlistener(property, func(n) {
                is_checked = n.getValue() or 0;
                if (is_checked) {
                    check.show();
                } else {
                    check.hide();
                }
            }, 1, 0)
        );
        
        return group;
    },

    createSlider: func(x, y, width, property, min, max, default_value=nil) {
        var group = me._group.createChild("group")
            .setTranslation(x, y);
        
        # Track background
        var track = group.createChild("path")
            .rect(0, 8, width, 4, {"border-radius": 2})
            .setColor(0.5, 0.5, 0.5)
            .setStrokeLineWidth(1)
            .setColorFill(0.8, 0.8, 0.8);
            
        # Handle
        var handle = group.createChild("path");
        var handle_width = 16;
        var handle_height = 20;
            
        handle.rect(-handle_width/2, 0, handle_width, handle_height, {"border-radius": 4})
            .setColor(0.4, 0.4, 0.4)
            .setStrokeLineWidth(1)
            .setColorFill(0.9, 0.9, 0.9);
            
        # Value display
        var value_text = group.createChild("text")
            .setAlignment("left-center")
            .setTranslation(width + 15, 10)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", 14)
            .setColor(0.9, 0.9, 0.9); # Lighter text color for better contrast
            
        var update_handle = func {
            var value = getprop(property);
            var pos = (value - min) / (max - min) * width;
            handle.setTranslation(pos, 0);
            value_text.setText(sprintf("%.2f", value));
        };
        
        if (default_value != nil) {
            var reset = group.createChild("text")
                .setText("Default")
                .setAlignment("left-center")
                .setTranslation(width + 70, 10)
                .setFont("LiberationFonts/LiberationSans-Regular.ttf")
                .set("character-size", 14)
                .setColor(0.4, 0.7, 1.0); # Brighter blue for better contrast
                
            reset.addEventListener("click", func {
                setprop(property, default_value);
            });
        }
        
        append(me._listeners, setlistener(property, update_handle, 0, 0));
        
        var handleSliderClick = func(val) {
            var new_value = min + (val / width) * (max - min);
            new_value = math.max(min, math.min(new_value, max));
            setprop(property, new_value);
        };
        
        # Allow clicking directly on the track to set value
        # Use the drag event to capture the handle's position instead of click
        var drag_obj = {
            started: 0,
            start_x: 0,
            start_value: 0
        };
        
        track.addEventListener("mousedown", func(e) {
            # Set drag_obj to track the drag
            drag_obj.started = 1;
            
            # Start a dragging operation
            var pos = handle.getTranslation()[0];
            drag_obj.start_x = pos;
            drag_obj.start_value = getprop(property);
            
            # Set the handle directly to where the user clicked
            # Just move directly to the desired position based on track width percentage
            var pos_factor = e.clientX / width;
            if (pos_factor < 0) pos_factor = 0;
            if (pos_factor > 1) pos_factor = 1;
            
            var new_value = min + pos_factor * (max - min);
            setprop(property, new_value);
        });
        
        handle.addEventListener("drag", func(e) {
            var newpos = handle.getTranslation()[0] + e.deltaX;
            newpos = math.max(0, math.min(newpos, width));
            var value = min + (newpos / width) * (max - min);
            setprop(property, value);
        });
        
        handle.addEventListener("mouseover", func {
            handle.setColorFill(1, 1, 1);
        });
        
        handle.addEventListener("mouseout", func {
            handle.setColorFill(0.9, 0.9, 0.9);
        });
        
        # Initialize the slider position
        update_handle();
        return group;
    },

    createLineEdit: func(x, y, width, height, text="", property=nil) {
        var config = {
            position: [x, y],
            size: [width, height],
            text: text
        };

        var line_edit = me._style.createWidget(me._group, "line-edit", config);
        
        if (property != nil) {
            # Set initial value if property exists
            if (getprop(property) != nil) {
                line_edit._model.setText(getprop(property));
            }
            
            # Add property listener
            append(me._listeners, 
                setlistener(property, func(n) {
                    line_edit._model.setText(n.getValue());
                })
            );
            
            # Add text change listener
            line_edit._root.addEventListener("keyup", func {
                setprop(property, line_edit._model.text());
            });
        }
        
        return line_edit;
    },

    createScrollArea: func(x, y, width, height) {
        var config = {
            position: [x, y],
            size: [width, height]
        };
        
        var scroll = me._style.createWidget(me._group, "scroll-area", config);
        return scroll;
    },

    createSeparator: func(x, y, width) {
        # Create a simple line as separator since DefaultStyle doesn't have a separator widget
        var line = me._group.createChild("path")
            .setTranslation(x, y)
            .moveTo(0, 0)
            .lineTo(width, 0)
            .setColor(0.4, 0.4, 0.4)
            .setStrokeLineWidth(1);
            
        return line;
    }
};
