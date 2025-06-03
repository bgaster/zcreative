const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui/gui.zig");
const Point = gui.geometry.Point;
const Rect = gui.geometry.Rect;

pub const CanvasWidget = @This();

widget: gui.Widget,
allocator: Allocator,
labels: ArrayList(*gui.Obj),
dragging: bool,
select: Rect(f32),

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    _ = &vg;
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .labels = ArrayList(*gui.Obj).init(allocator),
        .dragging = false,
        .select = Rect(f32).make(0,0,0,0),
    };

    self.widget.drawFn = draw;
    self.widget.onResizeFn = onResize;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.onMouseMoveFn = onMouseMove;

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

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const self: *Self = @fieldParentPtr("widget", widget);

    // handle drawing all our children widgets
    widget.drawChildren(vg);

    if (self.dragging) {
        const r = self.select;
        const x, const w = if (r.w < 0) .{ r.x, @abs(r.w) } else .{ r.x - r.w, r.w };
        const y, const h = if (r.h < 0) .{ r.y, @abs(r.h) } else .{ r.y - r.h, r.h };
        vg.beginPath();
        vg.rect(x,y,w,h);
        vg.strokeColor(nvg.rgbf(0, 0, 1));
        vg.stroke();
    }
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
    if (mouse_event.button == gui.MouseButton.left) {
        if (mouse_event.click_count == 1) {
            self.dragging = true;
            self.select = Rect(f32).make(mouse_event.x, mouse_event.y, 0, 0);
        }
        else if (mouse_event.click_count == 2) {
            self.dragging = false;
            self.select = Rect(f32).make(0, 0, 0, 0);
            const label = try gui.Obj.init(self.allocator, Rect(f32).make(mouse_event.x, mouse_event.y, 37, 20), "+ 10"); 
            try self.labels.append(label);
            try self.widget.addChild(&self.labels.items[self.labels.items.len-1].widget);
        }
    }
    else {
    }
}

fn onMouseDown(widget: *gui.Widget, mouse_event: *gui.MouseEvent) void {
    onMouseDownErr(widget, mouse_event) catch {
    };
}

fn onMouseMove(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    _ = &mouse_event;
    if (self.dragging) {
        self.select = Rect(f32).make(
            self.select.x, self.select.y, 
            self.select.x - mouse_event.x,  self.select.y - mouse_event.y);
        // std.debug.print("{d:.1}, {d:.1}, {d:.1}, {d:.1}\n", .{self.select.x, self.select.y, self.select.w, self.select.h});
    }
}

fn onMouseUp(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    if (mouse_event.button == gui.MouseButton.left and self.dragging) {
        self.dragging = false;
        self.select = Rect(f32).make(0,0,0,0);
    }
}
