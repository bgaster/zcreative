const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const nvg = @import("nanovg");
const gui = @import("gui.zig");
const event = @import("event.zig");
const Point = @import("geometry.zig").Point;
const Rect = @import("geometry.zig").Rect;

const Layout = struct {
    grow: bool = false,
};

const debug_focus = false;

const Widget = @This();

window: ?*gui.Window = null,
parent: ?*Widget = null,
children: ArrayList(*Widget),
relative_rect: Rect(f32), // Relative to parent
layout: Layout = Layout{},
focus_policy: event.FocusPolicy = event.FocusPolicy{},
enabled: bool = true,
visible: bool = true,

drawFn: *const fn (*Widget, vg: nvg) void = drawChildren,

onResizeFn: *const fn (*Widget, *event.ResizeEvent) void = onResize,
onMouseMoveFn: *const fn (*Widget, *event.MouseEvent) void = onMouseMove,
onMouseDownFn: *const fn (*Widget, *event.MouseEvent) void = onMouseDown,
onMouseUpFn: *const fn (*Widget, *event.MouseEvent) void = onMouseUp,
onMouseWheelFn: *const fn (*Widget, *event.MouseEvent) void = onMouseWheel,
onTouchPanFn: *const fn (*Widget, *event.TouchEvent) void = onTouchPan,
onTouchZoomFn: *const fn (*Widget, *event.TouchEvent) void = onTouchZoom,
onKeyDownFn: *const fn (*Widget, *event.KeyEvent) void = onKeyDown,
onKeyUpFn: *const fn (*Widget, *event.KeyEvent) void = onKeyUp,
onTextInputFn: *const fn (*Widget, *event.TextInputEvent) void = onTextInput,
onFocusFn: *const fn (*Widget, *event.FocusEvent) void = onFocus,
onBlurFn: *const fn (*Widget, *event.FocusEvent) void = onBlur,
onEnterFn: *const fn (*Widget) void = onEnter,
onLeaveFn: *const fn (*Widget) void = onLeave,
onClipboardUpdateFn: *const fn (*Widget) void = onClipboardUpdate,

const Self = @This();

pub fn init(allocator: Allocator, rect: Rect(f32)) Self {
    return Self{ .children = ArrayList(*Self).init(allocator), .relative_rect = rect };
}

pub fn deinit(self: *Self) void {
    self.children.deinit();
}

pub fn addChild(self: *Self, child: *Widget) !void {
    std.debug.assert(child.parent == null);
    child.parent = self;
    try self.children.append(child);
}

pub fn getWindow(self: *Self) ?*gui.Window {
    if (self.parent) |parent| {
        return parent.getWindow();
    }
    return self.window;
}

pub fn getApplication(self: *Self) ?*gui.Application {
    const window = self.getWindow() orelse return null;
    return window.application;
}

pub fn isEnabled(self: Self) bool {
    if (!self.enabled) return false;
    if (self.parent) |parent| {
        return parent.isEnabled();
    }
    return true;
}

pub fn isFocused(self: *Self) bool {
    if (self.getWindow()) |window| {
        return window.is_active and window.focused_widget == self;
    }
    return false;
}

pub fn setFocus(self: *Self, focus: bool, source: gui.FocusSource) void {
    if (focus and !self.acceptsFocus(source)) return;
    if (self.getWindow()) |window| {
        window.setFocusedWidget(if (focus) self else null, source);
    }
}

// local without position
pub fn getRect(self: Self) Rect(f32) {
    return .{ .x = 0, .y = 0, .w = self.relative_rect.w, .h = self.relative_rect.h };
}

// position relative to containing window
pub fn getWindowRelativeRect(self: *Self) Rect(f32) {
    if (self.parent) |parent| {
        const offset = parent.getWindowRelativeRect().getPosition();
        return self.relative_rect.translated(offset);
    } else {
        return self.relative_rect;
    }
}

pub fn setPosition(self: *Self, x: f32, y: f32) void {
    self.relative_rect.x = x;
    self.relative_rect.y = y;
}

// also fires event
pub fn setSize(self: *Self, width: f32, height: f32) void {
    if (width != self.relative_rect.w or height != self.relative_rect.h) {
        var re = event.ResizeEvent{
            .old_width = self.relative_rect.w,
            .old_height = self.relative_rect.h,
            .new_width = width,
            .new_height = height,
        };
        self.relative_rect.w = width;
        self.relative_rect.h = height;

        self.handleEvent(&re.event);
    }
}

pub fn drawChildren(self: *Self, vg: nvg) void {
    vg.save();
    defer vg.restore();
    const offset = self.relative_rect.getPosition();
    vg.translate(offset.x, offset.y);
    // std.debug.print("hello {}", .{self.children.items.len});
    for (self.children.items) |child| {
        child.draw(vg);
    }
}

pub fn draw(self: *Self, vg: nvg) void {
    if (!self.visible) return;
    if (self.relative_rect.w <= 0 or self.relative_rect.h <= 0) return;

    self.drawFn(self, vg);

    if (debug_focus) {
        if (self.isFocused()) {
            vg.beginPath();
            const r = self.relative_rect;
            vg.rect(r.x, r.y, r.w - 1, r.h - 1);
            vg.strokeColor(nvg.rgbf(1, 0, 0));
            vg.stroke();
        }
    }
}

pub const HitTestResult = struct {
    widget: *Widget,
    local_position: Point(f32),
};

pub fn hitTest(self: *Self, position: Point(f32)) HitTestResult {
    const relative_position = position.subtracted(self.relative_rect.getPosition());
    for (self.children.items) |child| {
        if (child.visible and child.relative_rect.contains(relative_position)) {
            return child.hitTest(relative_position);
        }
    }
    return HitTestResult{ .widget = self, .local_position = relative_position };
}

fn onResize(self: *Self, resize_event: *event.ResizeEvent) void {
    _ = resize_event;
    _ = self;
}

fn onMouseMove(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseDown(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseUp(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onMouseWheel(self: *Self, mouse_event: *event.MouseEvent) void {
    _ = mouse_event;
    _ = self;
}

fn onTouchPan(self: *Self, touch_event: *event.TouchEvent) void {
    _ = touch_event;
    _ = self;
}

fn onTouchZoom(self: *Self, touch_event: *event.TouchEvent) void {
    _ = touch_event;
    _ = self;
}

pub fn onKeyDown(self: *Self, key_event: *event.KeyEvent) void {
    if (key_event.key == .Tab) {
        if (key_event.modifiers == 0) {
            self.focusNextWidget(.keyboard);
            key_event.event.accept();
            return;
        } else if (key_event.isSingleModifierPressed(.shift)) {
            self.focusPreviousWidget(.keyboard);
            key_event.event.accept();
            return;
        }
    }
    key_event.event.ignore();
}

fn onKeyUp(self: *Self, key_event: *event.KeyEvent) void {
    _ = self;
    key_event.event.ignore();
}

fn onTextInput(self: *Self, text_input_event: *event.TextInputEvent) void {
    _ = text_input_event;
    _ = self;
}

fn onFocus(self: *Self, focus_event: *event.FocusEvent) void {
    _ = focus_event;
    _ = self;
}

fn onBlur(self: *Self, focus_event: *event.FocusEvent) void {
    _ = focus_event;
    _ = self;
}

fn onEnter(self: *Self) void {
    _ = self;
}

fn onLeave(self: *Self) void {
    _ = self;
}

fn onClipboardUpdate(self: *Self) void {
    _ = self;
}

/// bubbles event up until it is accepted
pub fn dispatchEvent(self: *Self, e: *event.Event) void {
    var maybe_target: ?*Self = self;
    while (maybe_target) |target| : (maybe_target = target.parent) {
        target.handleEvent(e);
        if (e.is_accepted) break;
    }
}

pub fn handleEvent(self: *Self, e: *event.Event) void {

    switch (e.type) {
        .Resize => {
            const resize_event: *event.ResizeEvent = @alignCast(@fieldParentPtr("event", e));
            self.onResizeFn(self, resize_event);
        },
        .MouseMove => {
            const mouse_event: *event.MouseEvent = @alignCast(@fieldParentPtr("event", e));
            self.onMouseMoveFn(self, mouse_event);
        },
        .MouseDown => {
            const mouse_event: *event.MouseEvent = @alignCast(@fieldParentPtr("event", e));
            if (self.acceptsFocus(.mouse)) {
                self.setFocus(true, .mouse);
            }
            self.onMouseDownFn(self, mouse_event);
        },
        .MouseUp => {
            const mouse_event: *event.MouseEvent = @alignCast(@fieldParentPtr("event", e));
            self.onMouseUpFn(self, mouse_event);
        },
        .MouseWheel => {
            const mouse_event: *event.MouseEvent = @alignCast(@fieldParentPtr("event", e));
            self.onMouseWheelFn(self, mouse_event);
        },
        .TouchPan => {
            const touch_event: *event.TouchEvent = @alignCast(@fieldParentPtr("event", e));
            self.onTouchPanFn(self, touch_event);
        },
        .TouchZoom => {
            const touch_event: *event.TouchEvent = @alignCast(@fieldParentPtr("event", e));
            self.onTouchZoomFn(self, touch_event);
        },
        .KeyDown => {
            const key_event: *event.KeyEvent = @alignCast(@fieldParentPtr("event", e));
            self.onKeyDownFn(self, key_event);
        },
        .KeyUp => {
            const key_event: *event.KeyEvent = @alignCast(@fieldParentPtr("event", e));
            self.onKeyUpFn(self, key_event);
        },
        .TextInput => {
            const text_input_event: *event.TextInputEvent = @alignCast(@fieldParentPtr("event", e));
            self.onTextInputFn(self, text_input_event);
        },
        .Focus => {
            const focus_event: *event.FocusEvent = @alignCast(@fieldParentPtr("event", e));
            self.onFocusFn(self, focus_event);
        },
        .Blur => {
            const focus_event: *event.FocusEvent = @alignCast(@fieldParentPtr("event", e));
            self.onBlurFn(self, focus_event);
        },
        .Enter => {
            self.onEnterFn(self);
        },
        .Leave => {
            self.onLeaveFn(self);
        },
        .ClipboardUpdate => {
            self.onClipboardUpdateFn(self);
        },
    }
}

pub fn acceptsFocus(self: Self, source: event.FocusSource) bool {
    return self.visible and self.focus_policy.accepts(source) and self.isEnabled();
}

fn focusNextWidget(self: *Self, source: event.FocusSource) void {
    if (!self.acceptsFocus(source)) return;
    const window = self.getWindow() orelse return;
    var focusable_widgets = std.ArrayList(*gui.Widget).init(self.children.allocator);
    defer focusable_widgets.deinit();
    window.collectFocusableWidgets(&focusable_widgets, source) catch return;

    if (std.mem.indexOfScalar(*gui.Widget, focusable_widgets.items, self)) |i| {
        const next_i = (i + 1) % focusable_widgets.items.len;
        focusable_widgets.items[next_i].setFocus(true, .keyboard);
    }
}

fn focusPreviousWidget(self: *Self, source: event.FocusSource) void {
    if (!self.acceptsFocus(source)) return;
    const window = self.getWindow() orelse return;
    var focusable_widgets = std.ArrayList(*gui.Widget).init(self.children.allocator);
    defer focusable_widgets.deinit();
    window.collectFocusableWidgets(&focusable_widgets, source) catch return;

    if (std.mem.indexOfScalar(*gui.Widget, focusable_widgets.items, self)) |i| {
        const n = focusable_widgets.items.len;
        const previous_i = (i + n - 1) % n;
        focusable_widgets.items[previous_i].setFocus(true, .keyboard);
    }
}
