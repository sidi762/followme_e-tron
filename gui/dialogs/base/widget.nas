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
        var textElement = me._group.createChild("text")
            .setText(text)
            .setAlignment(alignment)
            .setTranslation(x, y)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", size)
            .setColor(0.9, 0.9, 0.9); # Lighter text color for better contrast
        
        return textElement;
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
            .hide(); # Initially hidden
        
        # Label
        var label = group.createChild("text")
            .setText(text)
            .setTranslation(22, 8)
            .setAlignment("left-center")
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", 14)
            .setColor(0.9, 0.9, 0.9);
        
        # Set initial visual state based on property
        var initialPropVal = getprop(property) or 0;
        if (initialPropVal) { # If true (e.g., 1)
            check.show();
        } else {
            check.hide(); # Ensure it's hidden if false (e.g., 0 or nil)
        }
        
        # Toggle function: reads current prop val, inverts, and sets
        var toggle = func {
            var currentVal = getprop(property) or 0; # Read current value, default to 0 (false) if nil
            var newVal = !currentVal; # Invert (0 becomes 1, 1 becomes 0)
            setprop(property, newVal); # Set the property, this will trigger the listener
            
            if (callback != nil) {
                callback(newVal);
            }
        };
        
        # Add click handlers
        box.addEventListener("click", toggle);
        label.addEventListener("click", toggle);
        check.addEventListener("click", toggle); # Add listener to the checkmark itself
        
        # Add property listener to update visual state
        append(me._listeners, 
            setlistener(property, func(n) {
                var valFromProp = n.getValue() or 0; # Default to 0 (false) if nil
                if (valFromProp) { # If true (e.g., 1)
                    check.show();
                } else {
                    check.hide();
                }
            }, 1, 0) # Execute now to ensure consistency if prop already set
        );
        
        return group;
    },

    createSlider: func(x, y, width, property, min, max, defaultValue=nil) {
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
        var handleWidth = 16;
        var handleHeight = 20;
            
        handle.rect(-handleWidth/2, 0, handleWidth, handleHeight, {"border-radius": 4})
            .setColor(0.4, 0.4, 0.4)
            .setStrokeLineWidth(1)
            .setColorFill(0.9, 0.9, 0.9);
            
        # Value display
        var valueText = group.createChild("text")
            .setAlignment("left-center")
            .setTranslation(width + 15, 10)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", 14)
            .setColor(0.9, 0.9, 0.9); # Lighter text color for better contrast
            
        var _updateHandle = func {
            var value = getprop(property);
            var pos = (value - min) / (max - min) * width;
            handle.setTranslation(pos, 0);
            valueText.setText(sprintf("%.2f", value));
        };
        
        if (defaultValue != nil) {
            var reset = group.createChild("text")
                .setText("Default")
                .setAlignment("left-center")
                .setTranslation(width + 70, 10)
                .setFont("LiberationFonts/LiberationSans-Regular.ttf")
                .set("character-size", 14)
                .setColor(0.4, 0.7, 1.0); # Brighter blue for better contrast
                
            reset.addEventListener("click", func {
                setprop(property, defaultValue);
            });
        }
        
        append(me._listeners, setlistener(property, _updateHandle, 0, 0));
        
        var _handleSliderClick = func(val) {
            var newValue = min + (val / width) * (max - min);
            newValue = math.max(min, math.min(newValue, max));
            setprop(property, newValue);
        };
        
        # Allow clicking directly on the track to set value
        # Use the drag event to capture the handle's position instead of click
        var dragObj = {
            started: 0,
            startX: 0,
            startValue: 0
        };
        
        track.addEventListener("mousedown", func(e) {
            # Set dragObj to track the drag
            dragObj.started = 1;
            
            # Start a dragging operation
            var pos = handle.getTranslation()[0];
            dragObj.startX = pos;
            dragObj.startValue = getprop(property);
            
            # Set the handle directly to where the user clicked
            # Just move directly to the desired position based on track width percentage
            var posFactor = e.clientX / width;
            if (posFactor < 0) posFactor = 0;
            if (posFactor > 1) posFactor = 1;
            
            var newValue = min + posFactor * (max - min);
            setprop(property, newValue);
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
        _updateHandle();
        return group;
    },

    createLineEdit: func(x, y, width, height, text="", property=nil) {
        var config = {
            position: [x, y],
            size: [width, height],
            text: text
        };

        var lineEdit = me._style.createWidget(me._group, "line-edit", config);
        
        if (property != nil) {
            # Set initial value if property exists
            if (getprop(property) != nil) {
                lineEdit._model.setText(getprop(property));
            }
            
            # Add property listener
            append(me._listeners, 
                setlistener(property, func(n) {
                    lineEdit._model.setText(n.getValue());
                })
            );
            
            # Add text change listener
            lineEdit._root.addEventListener("keyup", func {
                setprop(property, lineEdit._model.text());
            });
        }
        
        return lineEdit; 
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
    },
    
    createDropdown: func(x, y, width, items, property, defaultIndex=nil) {
        var widgetGroup = me._group; 
        var dialogCanvas = me._dialog._canvas; 

        # Create overall container for the dropdown header
        var headerContainerGroup = widgetGroup.createChild("group") 
            .setTranslation(x, y);
        
        # Create dropdown header
        var dropdownHeader = headerContainerGroup.createChild("group", "dropdown-header"); 
        
        # Header background
        var headerBg = dropdownHeader.createChild("path") 
            .rect(0, 0, width, 28, {"border-radius": 3})
            .setColor(0.3, 0.3, 0.3)
            .setStrokeLineWidth(1)
            .setColorFill(0.25, 0.25, 0.25);
        
        # Down arrow indicator
        var arrow = dropdownHeader.createChild("path") 
            .moveTo(width - 20, 10)
            .lineTo(width - 10, 10) 
            .lineTo(width - 15, 18)
            .setColor(0.7, 0.7, 0.7)
            .setColorFill(0.7, 0.7, 0.7);
        
        # Selected text display
        var selectedText = dropdownHeader.createChild("text") 
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .set("character-size", 14)
            .setColor(1, 1, 1)
            .setAlignment("left-center")
            .setTranslation(10, 14);
        
        # Initialize selected value
        var currentValue = "";
        if (property != nil) {
            currentValue = getprop(property);
            if (currentValue == nil and defaultIndex != nil and defaultIndex >= 0 and defaultIndex < size(items)) {
                currentValue = items[defaultIndex];
                setprop(property, currentValue);
            } else if (currentValue == nil and size(items) > 0) {
                currentValue = items[0];
                setprop(property, currentValue);
            }
        }
        selectedText.setText(currentValue != nil ? currentValue : ""); 
        
        var popupListGroup = nil; 
        var overlayGroup = nil; 
        var itemBgs = [];
        var itemContainers = [];
        var isSelecting = 0; 

        var _closeDropdown = func {
            if (popupListGroup != nil) { 
                popupListGroup.del(); 
                popupListGroup = nil; 
            }
            if (overlayGroup != nil) { 
                overlayGroup.del(); 
                overlayGroup = nil; 
            }
            itemBgs = [];
            itemContainers = [];
        };
        
        # Function to update all backgrounds based on selection
        var _updateSelection = func(selectionIndex) {
            if (selectionIndex < 0 or selectionIndex >= size(items)) return;
            
            # Update the value
            currentValue = items[selectionIndex];
            selectedText.setText(currentValue); 
            
            # Set property if provided
            if (property != nil) {
                setprop(property, currentValue);
            }
            
            # Update visual highlighting
            for (var j = 0; j < size(itemBgs); j += 1) {
                if (j == selectionIndex) {
                    itemBgs[j].setColorFill(0.4, 0.4, 0.6);
                } else {
                    itemBgs[j].setColorFill(0.25, 0.25, 0.25);
                }
            }
        };
        
        dropdownHeader.addEventListener("click", func(event) {
            if (popupListGroup != nil) { # If already open, close it
                _closeDropdown();
                return;
            }

            # Clear tracking arrays
            itemBgs = [];
            itemContainers = [];
            
            # Create popup components
            overlayGroup = dialogCanvas.createGroup("dropdown-overlay-group-" ~ me._name);
            overlayGroup.set("z-index", 9998);
            
            var actualOverlayPath = overlayGroup.createChild("path")
                .rect(0, 0, dialogCanvas.get("size[0]"), dialogCanvas.get("size[1]"))
                .setColorFill(0, 0, 0, 0); # Transparent
            
            # Put the dropdown list on top of everything
            popupListGroup = dialogCanvas.createGroup("dropdown-popup-" ~ me._name);
            popupListGroup.set("z-index", 9999);
            
            # Position the popup under the header
            var dialogPos = me._dialog._group.getTranslation();
            var popupX = dialogPos[0] + x;
            var popupY = dialogPos[1] + y + 28;
            popupListGroup.setTranslation(popupX, popupY);
            
            # Create the list background
            var itemHeight = 25;
            var maxHeight = 800;
            var listHeight = math.min(size(items) * itemHeight, maxHeight);
            
            var listBg = popupListGroup.createChild("path")
                .rect(-1, -1, width + 2, listHeight + 2, {"border-radius": 3})
                .setColor(0.2, 0.2, 0.2)
                .setStrokeLineWidth(1)
                .setColorFill(0.25, 0.25, 0.25);
            
            # Track current selection based on match with currentValue
            var currentSelection = -1;
            for (var i = 0; i < size(items); i += 1) {
                if (items[i] == currentValue) {
                    currentSelection = i;
                    break;
                }
            }
            
            # Create individual list item containers with explicit index-based handling
            for (var i = 0; i < size(items); i += 1) {
                var itemContainer = popupListGroup.createChild("group");
                itemContainer.setTranslation(0, i * itemHeight);
                append(itemContainers, itemContainer);
                
                # Create item background
                var itemBg = itemContainer.createChild("path")
                    .rect(0, 0, width, itemHeight)
                    .setColor(0.2, 0.2, 0.2)
                    .setStrokeLineWidth(0);
                    
                # Default or selected color
                if (i == currentSelection) {
                    itemBg.setColorFill(0.4, 0.4, 0.6);
                } else {
                    itemBg.setColorFill(0.25, 0.25, 0.25);
                }
                append(itemBgs, itemBg);
                
                # Create item text
                var itemText = itemContainer.createChild("text")
                    .setText(items[i])
                    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
                    .set("character-size", 14)
                    .setColor(1, 1, 1)
                    .setAlignment("left-center")
                    .setTranslation(10, itemHeight / 2);
                
                # Create proper event handlers using closure functions for each item
                # This ensures each handler gets the correct index
                var _makeMouseOverHandler = func(idx) {
                    return func {
                        if (!isSelecting) {
                            itemBgs[idx].setColorFill(0.4, 0.4, 0.6);
                        }
                    };
                };
                
                var _makeMouseOutHandler = func(idx, itemValue) {
                    return func {
                        if (!isSelecting and itemValue != currentValue) {
                            itemBgs[idx].setColorFill(0.25, 0.25, 0.25);
                        }
                    };
                };
                
                var _makeClickHandler = func(idx, itemValue) {
                    return func {
                        isSelecting = 1;
                        
                        # Update the actual value directly
                        currentValue = itemValue;
                        selectedText.setText(currentValue);
                        
                        # Update the property if provided
                        if (property != nil) {
                            setprop(property, currentValue);
                        }
                        
                        # Update highlighting
                        for (var j = 0; j < size(itemBgs); j += 1) {
                            if (j == idx) {
                                itemBgs[j].setColorFill(0.4, 0.4, 0.6);
                            } else {
                                itemBgs[j].setColorFill(0.25, 0.25, 0.25);
                            }
                        }
                        
                        # Close after brief delay to avoid overlap with overlay click
                        settimer(func {
                            _closeDropdown();
                            isSelecting = 0;
                        }, 0.01);
                    };
                };
                
                # Attach event handlers with their own properly captured index and item value
                itemContainer.addEventListener("mouseover", _makeMouseOverHandler(i));
                itemContainer.addEventListener("mouseout", _makeMouseOutHandler(i, items[i]));
                itemContainer.addEventListener("click", _makeClickHandler(i, items[i]));
            }
            
            # Add click handler to overlay but make it check to ensure we're not clicking an item
            overlayGroup.addEventListener("click", func {
                # Don't close if we're in the process of selecting
                if (!isSelecting) {
                    _closeDropdown();
                }
            });
            
            # Force immediate rendering
            popupListGroup.update();
            
            # Prevent event bubbling to the overlay
            event.stopPropagation();
        });
        
        # Property listener for external changes
        if (property != nil) {
            append(me._listeners, 
                setlistener(property, func(n) {
                    var newVal = n.getValue();
                    selectedText.setText(newVal != nil ? newVal : "");
                    currentValue = newVal;
                    
                    # Find the index of the newly selected value
                    var selectedIdx = -1;
                    for (var k = 0; k < size(items); k += 1) {
                        if (items[k] == currentValue) {
                            selectedIdx = k;
                            break;
                        }
                    }
                    currentSelection = selectedIdx; # Update currentSelection
                    
                    # Update highlights if dropdown is visible
                    if (popupListGroup != nil) {
                        for (var j = 0; j < size(itemBgs); j += 1) {
                            if (j == selectedIdx) {
                                itemBgs[j].setColorFill(0.4, 0.4, 0.6);
                            } else {
                                itemBgs[j].setColorFill(0.25, 0.25, 0.25);
                            }
                        }
                    }
                }, 1, 0)
            );
        }
        
        # Clean up references when widget is removed
        var originalDeinit = me.deinit;
        me.deinit = func() {
            _closeDropdown();
            if (originalDeinit != nil) {
                call(originalDeinit, [], me);
            }
        };
        
        return headerContainerGroup;
    }
};
