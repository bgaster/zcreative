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
objs: ArrayList(*gui.Obj),
dragging: bool,
select: Rect(f32),

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32), vg: nvg) !*Self {
    _ = &vg;
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .objs = ArrayList(*gui.Obj).init(allocator),
        .dragging = false,
        .select = Rect(f32).make(0,0,0,0),
    };

    self.widget.drawFn = draw;
    self.widget.onResizeFn = onResize;
    self.widget.onKeyDownFn = onKeyDown;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onMouseUpFn = onMouseUp;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.setSelectFn = setSelect;

    return self;
}

pub fn deinit(self: *Self, vg: nvg) void {
    _ = &vg;
    self.widget.deinit();
    for (self.objs.items) |item| {
        item.deinit();
    }
    self.objs.deinit();
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
        // const r = self.select;
        // const x, const w = if (r.w < 0) .{ r.x, @abs(r.w) } else .{ r.x - r.w, r.w };
        // const y, const h = if (r.h < 0) .{ r.y, @abs(r.h) } else .{ r.y - r.h, r.h };
        const r = resolve(self.select);
        vg.beginPath();
        vg.rect(r.x,r.y,r.w,r.h);
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

    // clear any selected objs
    setSelect(widget, false);

    // double click on panel to add object...
    if (mouse_event.button == gui.MouseButton.left) {
        if (mouse_event.click_count == 1) {
            self.dragging = true;
            self.select = Rect(f32).make(mouse_event.x, mouse_event.y, 0, 0);
        }
        else if (mouse_event.click_count == 2) {
            self.dragging = false;
            self.select = Rect(f32).make(0, 0, 0, 0);
            const obj = try gui.Obj.init(self.allocator, Rect(f32).make(mouse_event.x, mouse_event.y, 37, 20), "+ 10"); 
            try self.objs.append(obj);
            try self.widget.addChild(&self.objs.items[self.objs.items.len-1].widget);
        }
    }
}

fn setSelect(widget: *gui.Widget, s: bool) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    for (self.objs.items) |obj| {
        obj.widget.setSelected(s);
    }
}

fn onMouseDown(widget: *gui.Widget, mouse_event: *gui.MouseEvent) void {
    onMouseDownErr(widget, mouse_event) catch {
    };
}

fn onMouseMove(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    if (self.dragging) {
        self.select = Rect(f32).make(
            self.select.x, self.select.y, 
            self.select.x - mouse_event.x,  self.select.y - mouse_event.y);
        
        for (self.objs.items) |obj| {
            const r1 = obj.widget.getWindowRelativeRect();
            const r2 = resolve(self.select);
            const ir = r2.intersection(r1);
            obj.widget.setSelected(ir.w >= 0 and ir.h >= 0);
        }
    }
}

fn onMouseUp(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    if (mouse_event.button == gui.MouseButton.left and self.dragging) {
        self.dragging = false;
        self.select = Rect(f32).make(0,0,0,0);
    }
}

fn resolve(r: Rect(f32)) Rect(f32) {
    const x, const w = if (r.w < 0) .{ r.x, @abs(r.w) } else .{ r.x - r.w, r.w };
    const y, const h = if (r.h < 0) .{ r.y, @abs(r.h) } else .{ r.y - r.h, r.h };
    return Rect(f32).make(x,y,w,h);
}
