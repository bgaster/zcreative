const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui/gui.zig");
const cvs = @import("CanvasWidget.zig");
const Point = gui.geometry.Point;
const Rect = gui.geometry.Rect;

pub const PanelWidget = @This();

widget: gui.Widget,
allocator: Allocator,
canvas: *cvs.CanvasWidget,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    _ = &vg;
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .canvas = try cvs.init(allocator, rect, vg),
    };

    try self.widget.addChild(&self.canvas.widget);
    self.widget.onResizeFn = onResize;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    _ = &vg;
    self.canvas.deinit(vg);
    self.widget.deinit();
    self.allocator.destroy(self);
}

fn updateLayout(self: *Self) void {
    _ = &self;
}

fn onResize(widget: *gui.Widget, event: *const gui.ResizeEvent) void {
    _ = event;
    const self: *Self = @fieldParentPtr("widget", widget);
    self.updateLayout();
}

fn onKeyDown(widget: *gui.Widget, key_event: *gui.KeyEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    _ = &self;
    const shift_held = key_event.isModifierPressed(.shift);
    _ = &shift_held;
    if (key_event.isModifierPressed(.ctrl)) {
        switch (key_event.key) {
            else => key_event.event.ignore(),
        }
    } else if (key_event.isModifierPressed(.alt)) {
        switch (key_event.key) {
            else => key_event.event.ignore(),
        }
    } else if (key_event.modifiers == 0) {
        switch (key_event.key) {
            else => key_event.event.ignore(),
        }
    } else {
        key_event.event.ignore();
    }
}

//TODO: think about removing these...

fn onMouseDown(widget: *gui.Widget, mouse_event: *gui.MouseEvent) void {
    _ = widget;
    _ = mouse_event;
}

fn onMouseMove(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    _ = widget;
    _ = mouse_event;
}

fn onMouseUp(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    _ = widget;
    _ = mouse_event;
}
