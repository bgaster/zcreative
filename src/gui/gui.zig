const std = @import("std");

const nvg = @import("nanovg");
pub const geometry = @import("geometry.zig");
const Rect = geometry.Rect;
const Point = geometry.Point;
pub usingnamespace @import("event.zig");
pub const Timer = @import("Timer.zig");
pub const Application = @import("Application.zig");
pub const Window = @import("Window.zig");
pub const Widget = @import("Widget.zig");

pub fn init(vg: nvg) void {
    _ = &vg;
}

pub fn deinit(vg: nvg) void {
    _ = &vg;
}
