const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui/gui.zig");
const Point = gui.geometry.Point;
const Rect = gui.geometry.Rect;

pub const PanelWidget = @This();

widget: gui.Widget,
allocator: Allocator,
labels: ArrayList(*gui.Label),

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    _ = &vg;
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .labels = ArrayList(*gui.Label).init(allocator),
    };

    self.widget.onResizeFn = onResize;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onMouseDownFn = onMouseDown;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    _ = &vg;
    self.widget.deinit();
    for (self.labels.items) |item| {
        item.deinit();
    }
    self.labels.deinit();
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

fn onMouseDownErr(widget: *gui.Widget, mouse_event: *gui.MouseEvent) !void {
    const self: *Self = @fieldParentPtr("widget", widget);
    // double click on panel to add object...
    if (mouse_event.button == gui.MouseButton.left and mouse_event.click_count == 2) {
        const label = try gui.Label.init(self.allocator, Rect(f32).make(mouse_event.x, mouse_event.y, 37, 20), "Zoom:"); 
        try self.labels.append(label);
        try self.widget.addChild(&self.labels.items[self.labels.items.len-1].widget);
    }
}

fn onMouseDown(widget: *gui.Widget, mouse_event: *gui.MouseEvent) void {
    onMouseDownErr(widget, mouse_event) catch {
    };
}
