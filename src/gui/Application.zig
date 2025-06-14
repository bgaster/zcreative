const std = @import("std");
const nvg = @import("nanovg");
const gui = @import("gui.zig");
usingnamespace @import("event.zig");
const Point = @import("geometry.zig").Point;

const Application = @This();

pub const SystemFunctions = struct {
    // essential
    createWindow: *const fn ([:0]const u8, u32, u32, gui.Window.CreateOptions, *gui.Window) anyerror!u32,
    destroyWindow: *const fn (u32) void,
    setWindowTitle: *const fn (u32, [:0]const u8) void,

    // optional
    startTimer: ?*const fn (*gui.Timer, u32) u32 = null,
    cancelTimer: ?*const fn (u32) void = null,
    showCursor: ?*const fn (bool) void = null,
    hasClipboardText: ?*const fn () bool = null,
    getClipboardText: ?*const fn (std.mem.Allocator) anyerror!?[]const u8 = null,
    setClipboardText: ?*const fn (std.mem.Allocator, []const u8) anyerror!void = null,
};

var system: SystemFunctions = undefined;

allocator: std.mem.Allocator,
windows: std.ArrayList(*gui.Window),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, system_functions: SystemFunctions) !*Self {
    system = system_functions;
    const self = try allocator.create(Application);
    self.* = Self{
        .allocator = allocator,
        .windows = std.ArrayList(*gui.Window).init(allocator),
    };
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.windows.items) |window| {
        self.allocator.destroy(window);
    }
    self.windows.deinit();
    self.allocator.destroy(self);
}

pub fn createWindow(self: *Self, title: [:0]const u8, width: f32, height: f32, options: gui.Window.CreateOptions) !*gui.Window {
    var window = try gui.Window.init(self.allocator, self);
    errdefer self.allocator.destroy(window);

    const system_window_id = try system.createWindow(
        title,
        @as(u32, @intFromFloat(width)),
        @as(u32, @intFromFloat(height)),
        options,
        window,
    );

    window.id = system_window_id;
    window.width = width;
    window.height = height;

    try self.windows.append(window);

    return window;
}

pub fn setWindowTitle(window_id: u32, title: [:0]const u8) void {
    system.setWindowTitle(window_id, title);
}

pub fn requestWindowClose(self: *Self, window: *gui.Window) void {
    if (window.isBlockedByModal()) return;

    if (window.onCloseRequestFn) |onCloseRequest| {
        if (!onCloseRequest(window.close_request_context)) return; // request denied
    }

    system.destroyWindow(window.id);

    // remove reference from parent
    if (window.parent) |parent| {
        parent.removeChild(window);
        window.parent = null;
    }
    // NOTE: isBlockedByModal is updated at this point

    if (window.onClosedFn) |onClosed| {
        onClosed(window.closed_context);
    }

    if (std.mem.indexOfScalar(*gui.Window, self.windows.items, window)) |i| {
        _ = self.windows.swapRemove(i);
        window.setMainWidget(null); // also removes reference to this window in main_widget
        window.deinit();
    }
}

pub fn showCursor(show: bool) void {
    if (system.showCursor) |systemShowCursor| {
        systemShowCursor(show);
    }
}

pub fn hasClipboardText() bool {
    if (system.hasClipboardText) |systemHasClipboardText| {
        return systemHasClipboardText();
    }
    return false;
}

pub fn setClipboardText(allocator: std.mem.Allocator, text: []const u8) !void {
    if (system.setClipboardText) |systemSetClipboardText| {
        try systemSetClipboardText(allocator, text);
    }
}

pub fn getClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
    if (system.getClipboardText) |systemGetClipboardText| {
        return try systemGetClipboardText(allocator);
    }
    return null;
}

pub fn startTimer(timer: *gui.Timer, interval: u32) u32 {
    if (system.startTimer) |systemStartTimer| {
        return systemStartTimer(timer, interval);
    }
    return 0;
}

pub fn cancelTimer(id: u32) void {
    if (system.cancelTimer) |systemCancelTimer| {
        systemCancelTimer(id);
    }
}

pub fn broadcastEvent(self: *Self, event: *gui.Event) void {
    for (self.windows.items) |window| {
        window.handleEvent(event);
    }
}
