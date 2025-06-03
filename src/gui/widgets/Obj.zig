const std = @import("std");

const nvg = @import("nanovg");
const gui = @import("../gui.zig");
const Rect = @import("../geometry.zig").Rect;
const Point = @import("../geometry.zig").Point;
const event = @import("../event.zig");

const Obj = @This();

widget: gui.Widget,
allocator: std.mem.Allocator,
text: []const u8,
text_alignment: gui.TextAlignment = .left,
padding: f32 = 0,
draw_border: bool = true,

hovered: bool = false,
focused: bool = false,
pressed: bool = false,
selected: bool = false,

onClickFn: ?*const fn (*Self) void = null,
onEnterFn: ?*const fn (*Self) void = null,
onLeaveFn: ?*const fn (*Self) void = null,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, rect: Rect(f32), text: []const u8) !*Self {
    var self = try allocator.create(Self);
    self.* = Self{
        .widget = gui.Widget.init(allocator, rect),
        .allocator = allocator,
        .text = text,
    };
    self.widget.drawFn = draw;
    self.widget.onMouseMoveFn = onMouseMove;
    self.widget.onMouseDownFn = onMouseDown;
    self.widget.onEnterFn = onEnter;
    self.widget.onLeaveFn = onLeave;
    return self;
}

pub fn deinit(self: *Self) void {
    self.widget.deinit();
    self.allocator.destroy(self);
}

pub fn draw(widget: *gui.Widget, vg: nvg) void {
    const self: *Self = @fieldParentPtr("widget", widget);

    const rect = widget.relative_rect;
    vg.save();
    if (self.draw_border) {
        gui.drawPanel(vg, rect.x, rect.y, rect.w, rect.h, 1, self.hovered, self.pressed, self.selected);
        vg.intersectScissor(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2);
    } else {
        vg.intersectScissor(rect.x, rect.y, rect.w, rect.h);
    }
    defer vg.restore();

    vg.fontFace("guifont");
    vg.fontSize(12);
    var text_align = nvg.TextAlign{ .vertical = .middle };
    var x = rect.x;
    var y = rect.y + 0.5 * rect.h;
    switch (self.text_alignment) {
        .left => {
            text_align.horizontal = .left;
            x += self.padding;
        },
        .center => {
            text_align.horizontal = .center;
            x += 0.5 * rect.w;
        },
        .right => {
            text_align.horizontal = .right;
            x += rect.w - self.padding;
        },
    }
    vg.fillColor(nvg.rgb(0, 0, 0));
    const has_newline = std.mem.indexOfScalar(u8, self.text, '\n') != null;
    if (rect.w == 0 or !has_newline) {
        vg.textAlign(text_align);
        _ = vg.text(x, rect.y + 0.5 * rect.h, self.text);
    } else {
        // NanoVG only vertically aligns the first line. So we have to do our own vertical centering.
        text_align.vertical = .top;
        vg.textAlign(text_align);
        vg.textLineHeight(14.0 / 12.0);
        var bounds: [4]f32 = undefined;
        vg.textBoxBounds(x, y, rect.w, self.text, &bounds);
        y -= 0.5 * (bounds[3] - bounds[1]);
        vg.textBox(x, y, rect.w, self.text);
    }
}

fn onMouseMove(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    if (self.pressed) {
        const size_w, const size_h = if (widget.getWindow()) |ws| ws.getSize() else .{ 0, 0 }; 
        const rect = widget.getWindowRelativeRect();
        var x = mouse_event.x / (rect.w - 1);
        const value = 0.0 + x * (size_w-rect.w - 0);
        x = (value - 0) / ((size_w/2) - 0);
        var y = mouse_event.y / (rect.h - 1);
        const value_y = 0.0 + y * (size_h-rect.y - 0);
        y = (value_y - 0) / ((size_h/2) - 0);
        widget.setPosition(rect.x + x, rect.y + y);
    }
}

pub fn onMouseDown(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    if (mouse_event.button == .left and mouse_event.click_count == 1) {
        self.pressed = true;
    }
}

fn onMouseUp(widget: *gui.Widget, mouse_event: *const gui.MouseEvent) void {
    if (mouse_event.button == .left) {
        const self: *Self = @fieldParentPtr("widget", widget);
        self.pressed = false;
    }
}

fn onEnter(widget: *gui.Widget) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    self.hovered = true;
    self.pressed = false; // only set when clicked
    if (self.onEnterFn) |enterFn| enterFn(self);
}

fn onLeave(widget: *gui.Widget) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    self.hovered = false;
    if (self.onLeaveFn) |leaveFn| leaveFn(self);
}
