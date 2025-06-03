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
pub const Obj = @import("widgets/Obj.zig");

const ThemeColors = struct {
    background: nvg.Color,
    shadow: nvg.Color,
    light: nvg.Color,
    border: nvg.Color,
    select: nvg.Color,
    focus: nvg.Color,
};

pub var theme_colors: ThemeColors = undefined;
pub var grid_image: nvg.Image = undefined;

fn defaultColorTheme() ThemeColors {
    return .{
        .background = nvg.rgb(224, 224, 224),
        .shadow = nvg.rgb(170, 170, 170),
        .light = nvg.rgb(255, 255, 255),
        .border = nvg.rgb(85, 85, 85),
        .select = nvg.rgba(0, 120, 247, 102),
        .focus = nvg.rgb(85, 160, 230),
    };
}

pub fn init(vg: nvg) void {
    theme_colors = defaultColorTheme();

    _ = &vg;
}

pub fn deinit(vg: nvg) void {
    _ = &vg;
}

pub fn pixelsToPoints(pixel_size: f32) f32 {
    return pixel_size * 96.0 / 72.0;
}

pub fn drawPanel(vg: nvg, x: f32, y: f32, w: f32, h: f32, depth: f32, hovered: bool, pressed: bool, selected: bool) void {
    if (w <= 0 or h <= 0) return;

    var color_bg = theme_colors.background;
    var color_shadow = theme_colors.shadow;
    var color_light = theme_colors.light;

    if (pressed) {
        color_bg = nvg.rgb(204, 204, 204);
        color_shadow = theme_colors.background;
        color_light = theme_colors.shadow;
    } else if (hovered) {
        color_bg = nvg.rgb(240, 240, 240);
    }

    // background
    vg.beginPath();
    vg.rect(x, y, w, h);
    vg.fillColor(color_bg);
    vg.fill();

    // shadow
    vg.beginPath();
    vg.moveTo(x, y + h);
    vg.lineTo(x + w, y + h);
    vg.lineTo(x + w, y);
    vg.lineTo(x + w - depth, y + depth);
    vg.lineTo(x + w - depth, y + h - depth);
    vg.lineTo(x + depth, y + h - depth);
    vg.closePath();
    vg.fillColor(color_shadow);
    vg.fill();

    // light
    vg.beginPath();
    vg.moveTo(x + w, y);
    vg.lineTo(x, y);
    vg.lineTo(x, y + h);
    vg.lineTo(x + depth, y + h - depth);
    vg.lineTo(x + depth, y + depth);
    vg.lineTo(x + w - depth, y + depth);
    vg.closePath();
    vg.fillColor(color_light);
    vg.fill();

    if (selected) {
        vg.beginPath();
        vg.strokeWidth(2);
        vg.moveTo(x + w, y);
        vg.lineTo(x, y);
        vg.lineTo(x, y + h);
        vg.lineTo(x + depth, y + h - depth);
        vg.lineTo(x + depth, y + depth);
        vg.lineTo(x + w - depth, y + depth);
        vg.closePath();
        vg.strokeColor(theme_colors.select);
        vg.stroke();
    }
}

pub fn drawPanelInset(vg: nvg, x: f32, y: f32, w: f32, h: f32, depth: f32, selected: bool) void {
    if (w <= 0 or h <= 0) return;

    var color_shadow = theme_colors.shadow;
    var color_light = theme_colors.light;

    if (selected) {
        color_shadow = theme_colors.select;
        color_light  = theme_colors.select;
    }

    // light
    vg.beginPath();
    vg.moveTo(x, y + h);
    vg.lineTo(x + w, y + h);
    vg.lineTo(x + w, y);
    vg.lineTo(x + w - depth, y + depth);
    vg.lineTo(x + w - depth, y + h - depth);
    vg.lineTo(x + depth, y + h - depth);
    vg.closePath();
    vg.fillColor(color_light);
    vg.fill();

    // shadow
    vg.beginPath();
    vg.moveTo(x + w, y);
    vg.lineTo(x, y);
    vg.lineTo(x, y + h);
    vg.lineTo(x + depth, y + h - depth);
    vg.lineTo(x + depth, y + depth);
    vg.lineTo(x + w - depth, y + depth);
    vg.closePath();
    vg.fillColor(color_shadow);
    vg.fill();
}


pub const Orientation = enum(u1) {
    horizontal,
    vertical,
};

pub const TextAlignment = enum(u8) {
    left,
    center,
    right,
};
