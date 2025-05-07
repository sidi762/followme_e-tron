###############################################################################
# Window Class
# Extends canvas.Window with custom styling and behavior
###############################################################################
var Window = {
    new: func(size, type = nil, id = nil) {
        var m = canvas.Window.new(size, type, id);
        m.parents = [Window] ~ m.parents;
        
        # Set initial position 
        m.setPosition(100, 100);
        
        # # Set up decorations
        # m._updateDecoration();
        
        # Track open state
        m._isOpen = 1;
        
        return m;
    },
    
    # Destructor
    del: func() {
        if (me["_title"] != nil) me._title.del();
        me.clearFocus();

        if(me["_canvas"] != nil) {
            var placements = me._canvas._node.getChildren("placement");
            # Do not remove canvas if other placements exist
            if(size(placements) > 1) {
                foreach(var p; placements){
                    if(p.getValue("type") == "window" and 
                    p.getValue("id") == me.get("id"))
                        p.remove();
                }
            } else {
                me._canvas.del();
            }
            me._canvas = nil;
        }
        if (me._node != nil) {
            me._node.remove();
            me._node = nil;
        }
        me._isOpen = 0;
    },

    # _updateDecoration: func() {
    #     var border_radius = 9;
    #     me.set("decoration-border", "25 1 1");
    #     me.set("shadow-inset", int((1 - math.cos(45 * D2R)) * border_radius + 0.5));
    #     me.set("shadow-radius", 5);
    #     me.setBool("update", 1);

    #     var canvas_deco = me.getCanvasDecoration();
    #     canvas_deco.addEventListener("mousedown", func me.raise());
    #     canvas_deco.set("blend-source-rgb", "src-alpha");
    #     canvas_deco.set("blend-destination-rgb", "one-minus-src-alpha");
    #     canvas_deco.set("blend-source-alpha", "one");
    #     canvas_deco.set("blend-destination-alpha", "one");

    #     var group_deco = canvas_deco.getGroup("decoration");
    #     group_deco.removeAllChildren();

    #     var title_bar = group_deco.createChild("group", "title_bar");
    #     me._title_bar_bg = title_bar.createChild("path", "background");
    #     me._title_bar_bg
    #         .rect(0, 0,
    #              me.get("size[0]"), 25,
    #              {"border-top-radius": border_radius})
    #         .setColorFill(0.25, 0.24, 0.22)
    #         .setStrokeLineWidth(0);
            
    #     # Add border frame
    #     me._frame = title_bar.createChild("path", "frame");
    #     me._frame
    #         .rect(0, 0,
    #             me.get("size[0]"), me.get("size[1]"),
    #             {"border-top-radius": border_radius})
    #         .setColor(0.25, 0.24, 0.22)
    #         .setStrokeLineWidth(1)
    #         .setColorFill("none");
            
    #     # Add highlight top line
    #     me._top_line = title_bar.createChild("path", "top-line");
    #     me._top_line
    #         .moveTo(border_radius - 2, 2)
    #         .lineTo(me.get("size[0]") - border_radius + 2, 2)
    #         .setColor(0.5, 0.5, 0.5)
    #         .setStrokeLineWidth(1);

    #     # Close button - use direct path drawing for reliability
    #     var x = 10;
    #     var y = 3;
    #     var w = 20;
    #     var h = 20;
        
    #     # Button background
    #     var close_button = title_bar.createChild("group", "close_button")
    #         .setTranslation(x, y);
            
    #     var bg = close_button.createChild("path", "bg")
    #         .rect(0, 0, w, h, {"border-radius": 2})
    #         .setColorFill(1, 0.3, 0.1, 0.8)
    #         .setStrokeLineWidth(0);
            
    #     # X mark
    #     var x_mark = close_button.createChild("path", "x_mark")
    #         .setColor(1, 1, 1)
    #         .setStrokeLineWidth(2);
            
    #     x_mark.moveTo(5, 5).lineTo(w-5, h-5);
    #     x_mark.moveTo(5, h-5).lineTo(w-5, 5);
                
    #     # Custom close button handling to fix reusability issue
    #     close_button.addEventListener("click", func {
    #         if (me._isOpen)
    #             me.del();
    #     });
        
    #     close_button.addEventListener("mouseover", func {
    #         bg.setColorFill(1, 0, 0, 1);
    #     });
        
    #     close_button.addEventListener("mouseout", func {
    #         bg.setColorFill(1, 0.3, 0.1, 0.8);
    #     });

    #     # Title text
    #     me._title = title_bar.createChild("text", "title")
    #         .set("alignment", "left-center")
    #         .set("character-size", 14)
    #         .set("font", "LiberationFonts/LiberationSans-Bold.ttf")
    #         .setColor(1, 1, 1) # Brighter white text for better contrast
    #         .setTranslation(x + w + 10, y + h/2);

    #     var title = me.get("title", "Canvas Window");
    #     me._title.setText(title);
    #     me._node.getNode("title", 1).alias(me._title._node.getPath() ~ "/text");

    #     # Window drag behavior - simplify further to avoid 'local' property
    #     title_bar.addEventListener("drag", func(e) {
    #         # Store the window reference for the event handler
    #         var window = me;
            
    #         # Move the window based on the delta
    #         window.move(e.deltaX, e.deltaY);
    #     });
        
    #     # Handle window resize
    #     me.onResize = func {
    #         if (me._title_bar_bg != nil) {
    #             me._title_bar_bg.reset().rect(0, 0, me.get("size[0]"), 25, {"border-top-radius": border_radius})
    #                 .setColorFill(0.25, 0.24, 0.22).setStrokeLineWidth(0);
                    
    #             me._frame.reset().rect(0, 0, me.get("size[0]"), me.get("size[1]"), 
    #                 {"border-top-radius": border_radius})
    #                 .setColor(0.25, 0.24, 0.22).setStrokeLineWidth(1).setColorFill("none");
                    
    #             me._top_line.reset().moveTo(border_radius - 2, 2)
    #                 .lineTo(me.get("size[0]") - border_radius + 2, 2)
    #                 .setColor(0.5, 0.5, 0.5).setStrokeLineWidth(1);
    #         }
            
    #         if (me['_canvas'] != nil) {
    #             for(var i = 0; i < 2; i += 1) {
    #                 var size = me.get("content-size[" ~ i ~ "]");
    #                 me._canvas.set("size[" ~ i ~ "]", size);
    #                 me._canvas.set("view[" ~ i ~ "]", size);
    #             }
    #         }
    #     };
    # }
};
