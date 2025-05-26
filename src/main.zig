//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const builtin = @import("builtin");

const win32 = @import("win32");
const foundation = win32.foundation;
const windows = win32.ui.windows_and_messaging;

const mem = std.mem;
const Allocator = mem.Allocator;

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("glfw/glfw3.h");
});

const sdl = @import("sdl2");
const nvg = @import("nanovg");

const gui = @import("gui/gui.zig");
const info = @import("info.zig");

extern fn SetProcessDPIAware() callconv(.C) c_int;
// extern fn enableAppleMomentumScroll() callconv(.C) void;

// globals

pub const CreateOptions = struct {
    resizable: bool = true,
    parent_id: ?u32 = null,
};


// the following SDL struct is is based on:
//     https://github.com/fabioarnold/MiniPixel/
//
const SdlWindow = struct {
    handle: *sdl.SDL_Window,
    context: sdl.SDL_GLContext, 

    // window: *gui.Window,
    dirty: bool = true,

    windowed_width: f32, // size when not maximized
    windowed_height: f32,

    video_width: f32,
    video_height: f32,
    video_scale: f32 = 1,

    fn create(title: [:0]const u8, width: u32, height: u32, options: CreateOptions) !SdlWindow {
        var self: SdlWindow = SdlWindow{
            .windowed_width = @as(f32, @floatFromInt(width)),
            .windowed_height = @as(f32, @floatFromInt(height)),
            .video_width = @as(f32, @floatFromInt(width)),
            .video_height = @as(f32, @floatFromInt(height)),
            .handle = undefined,
            .context = undefined,
            // .window = window,
        };

        // here for when we add nexted windows
        const display_index: c_uint = 0;

        var window_flags: c_uint = sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_ALLOW_HIGHDPI | sdl.SDL_WINDOW_HIDDEN;
        if (options.resizable) 
            window_flags |= sdl.SDL_WINDOW_RESIZABLE;

        var window_width: c_int = undefined;
        var window_height: c_int = undefined;
        if (builtin.os.tag == .macos) {
            window_width = @as(c_int, @intFromFloat(self.video_width));
            window_height = @as(c_int, @intFromFloat(self.video_height));
        } else {
            window_width = @as(c_int, @intFromFloat(self.video_scale * self.video_width));
            window_height = @as(c_int, @intFromFloat(self.video_scale * self.video_height));
        }
        const maybe_window = sdl.SDL_CreateWindow(
            title.ptr,
            @as(c_int, @bitCast(sdl.SDL_WINDOWPOS_UNDEFINED_DISPLAY(display_index))),
            @as(c_int, @bitCast(sdl.SDL_WINDOWPOS_UNDEFINED_DISPLAY(display_index))),
            window_width,
            window_height,
            window_flags,
        );
        if (maybe_window) |sdl_window| {
            self.handle = sdl_window;
        } else {
            sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
            return error.SDLCreateWindowFailed;
        }
        errdefer sdl.SDL_DestroyWindow(self.handle);

        self.context = sdl.SDL_GL_CreateContext(self.handle);
        if (self.context == null) {
            sdl.SDL_Log("Unable to create gl context: %s", sdl.SDL_GetError());
            return error.SDLCreateGLContextFailed;
        }

        // if (!options.resizable) {
        //     var sys_info: sdl.SDL_SysWMinfo = undefined;
        //     sdl.SDL_GetVersion(&sys_info.version);
        //     _ = sdl.SDL_GetWindowWMInfo(self.handle, &sys_info);
        //     if (builtin.os.tag == .windows) {
        //         if (sys_info.subsystem == c.SDL_SYSWM_WINDOWS) {
        //             const hwnd = @as(foundation.HWND, @ptrCast(sys_info.info.win.window));
        //             const style = windows.GetWindowLong(hwnd, windows.GWL_STYLE);
        //             const no_minimizebox = ~@as(i32, @bitCast(@intFromEnum(windows.WS_MINIMIZEBOX)));
        //             _ = windows.SetWindowLong(hwnd, windows.GWL_STYLE, style & no_minimizebox);
        //         }
        //     }
        // }

        return self;
    }

    fn destroy(self: SdlWindow) void {
        sdl.SDL_GL_DeleteContext(self.context);
        sdl.SDL_DestroyWindow(self.handle);
    }

    fn getId(self: SdlWindow) u32 {
        return sdl.SDL_GetWindowID(self.handle);
    }

    fn getDisplayIndex(self: SdlWindow) i32 {
        return sdl.SDL_GetWindowDisplayIndex(self.handle);
    }

    fn isMinimized(self: SdlWindow) bool {
        return sdl.SDL_GetWindowFlags(self.handle) & sdl.SDL_WINDOW_MINIMIZED != 0;
    }

    fn isMaximized(self: SdlWindow) bool {
        return sdl.SDL_GetWindowFlags(self.handle) & sdl.SDL_WINDOW_MAXIMIZED != 0;
    }

    fn maximize(self: *SdlWindow) void {
        sdl.SDL_MaximizeWindow(self.handle);
    }

    fn setSize(self: *SdlWindow, width: i32, height: i32) void {
        self.video_width = @as(f32, @floatFromInt(width));
        self.video_height = @as(f32, @floatFromInt(height));
        self.window.setSize(self.video_width, self.video_height);
        switch (builtin.os.tag) {
            .windows, .linux => {
                self.updateVideoScale();
                const scaled_width = self.video_scale * self.video_width;
                const scaled_height = self.video_scale * self.video_height;
                sdl.SDL_SetWindowSize(self.handle, @as(c_int, @intFromFloat(scaled_width)), @as(c_int, @intFromFloat(scaled_height)));
            },
            .macos => sdl.SDL_SetWindowSize(self.handle, width, height),
            else => unreachable, // unsupported
        }
    }

    fn setDisplay(self: SdlWindow, display_index: i32) void {
        const pos = @as(i32, @bitCast(sdl.SDL_WINDOWPOS_CENTERED_DISPLAY(@as(u32, @bitCast(display_index)))));
        sdl.SDL_SetWindowPosition(self.handle, pos, pos);
    }

    fn beginDraw(self: SdlWindow) void {
        _ = sdl.SDL_GL_MakeCurrent(self.handle, self.context);
    }

    const default_dpi: f32 = 96;

    fn updateVideoScale(self: *SdlWindow) void {
        switch (builtin.os.tag) {
            .windows, .linux => {
                const dpi = self.getLogicalDpi();
                self.video_scale = dpi / default_dpi;
            },
            .macos => {
                var drawable_width: i32 = undefined;
                var drawable_height: i32 = undefined;
                sdl.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);
                var window_width: i32 = undefined;
                var window_height: i32 = undefined;
                sdl.SDL_GetWindowSize(self.handle, &window_width, &window_height);
                self.video_scale = @as(f32, @floatFromInt(drawable_width)) / @as(f32, @floatFromInt(window_width));
            },
            else => unreachable,
        }
    }

    fn getLogicalDpi(self: SdlWindow) f32 {
        // SDL_GetDisplayDPI returns the physical DPI on Linux/X11. But we want the logical DPI.
        if (builtin.os.tag == .linux) {
            var sys_info: sdl.SDL_SysWMinfo = undefined;
            sdl.SDL_GetVersion(&sys_info.version);
            if (sdl.SDL_GetWindowWMInfo(self.handle, &sys_info) == sdl.SDL_TRUE and sys_info.subsystem == sdl.SDL_SYSWM_X11) {
                if (sdl.XGetDefault(sys_info.info.x11.display, "Xft", "dpi")) |dpi_str| {
                    if (std.fmt.parseFloat(f32, std.mem.sliceTo(dpi_str, 0))) |dpi| {
                        return dpi;
                    } else |_| {}
                }
            }
            // We don't want the physical value from SDL_GetDisplayDPI.
            return default_dpi;
        }

        const display = self.getDisplayIndex();
        var dpi: f32 = undefined;
        const sdl_error = sdl.SDL_GetDisplayDPI(display, &dpi, null, null);
        if (sdl_error == 0) {
            return dpi;
        }

        return default_dpi;
    }

    fn setupFrame(self: *SdlWindow) void {
        var drawable_width: i32 = undefined;
        var drawable_height: i32 = undefined;
        sdl.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);

        switch (builtin.os.tag) {
            .windows, .linux => {
                const dpi = self.getLogicalDpi();
                const new_video_scale = dpi / default_dpi;
                if (new_video_scale != self.video_scale) { // detect DPI change
                    //std.debug.print("new_video_scale {} {}\n", .{ new_video_scale, dpi });
                    self.video_scale = new_video_scale;
                    const window_width = @as(i32, @intFromFloat(self.video_scale * self.video_width));
                    const window_height = @as(i32, @intFromFloat(self.video_scale * self.video_height));
                    sdl.SDL_SetWindowSize(self.handle, window_width, window_height);
                    sdl.SDL_GL_GetDrawableSize(self.handle, &drawable_width, &drawable_height);
                }
            },
            .macos => {
                var window_width: i32 = undefined;
                var window_height: i32 = undefined;
                sdl.SDL_GetWindowSize(self.handle, &window_width, &window_height);
                self.video_scale = @as(f32, @floatFromInt(drawable_width)) / @as(f32, @floatFromInt(window_width));
            },
            else => unreachable, // unsupported
        }

        c.glViewport(0, 0, drawable_width, drawable_height);

        // only when window is resizable
        self.video_width = @as(f32, @floatFromInt(drawable_width)) / self.video_scale;
        self.video_height = @as(f32, @floatFromInt(drawable_height)) / self.video_scale;
        //FIXME:
        // self.window.setSize(self.video_width, self.video_height);
    }

    pub fn draw(self: *SdlWindow) void {
        self.beginDraw();
        self.setupFrame();

        c.glClearColor(0.5, 0.5, 0.5, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(self.video_width, self.video_height, self.video_scale);
            vg.rect(100,100, 120,30);
            vg.fillColor(nvg.rgba(255,192,0,255));
            vg.fill();
        // self.window.draw(vg);
        vg.endFrame();

        // c.glFlush();
        if (sdl.SDL_GetWindowFlags(self.handle) & sdl.SDL_WINDOW_HIDDEN != 0) {
            sdl.SDL_ShowWindow(self.handle);
        }
        sdl.SDL_GL_SwapWindow(self.handle);
        // c.glFinish();
        self.dirty = false;
    }
};

// utilty sdl functions

fn findSdlWindow(id: u32) ?*SdlWindow {
    for (sdl_windows.items) |*sdl_window| {
        if (sdl_window.getId() == id) return sdl_window;
    }
    return null;
}

fn markAllWindowsAsDirty() void {
    for (sdl_windows.items) |*sdl_window| {
        sdl_window.dirty = true;
    }
}

fn sdlShowCursor(enable: bool) void {
    _ = c.SDL_ShowCursor(if (enable) c.SDL_ENABLE else c.SDL_DISABLE);
}

fn sdlCreateWindow(title: [:0]const u8, width: u32, height: u32, options: CreateOptions) !u32 {
    const sdl_window = try SdlWindow.create(title, width, height, options);
    try sdl_windows.append(sdl_window);
    return sdl_window.getId();
}

fn sdlDestroyWindow(id: u32) void {
    var i: usize = 0;
    while (i < sdl_windows.items.len) {
        if (sdl_windows.items[i].getId() == id) {
            sdl_windows.items[i].destroy();
            _ = sdl_windows.swapRemove(i);
        } else i += 1;
    }
}

fn sdlEventWatch(userdata: ?*anyopaque, sdl_event_ptr: [*c]sdl.SDL_Event) callconv(.C) c_int {
    _ = userdata; // unused
    const sdl_event = sdl_event_ptr[0];
    if (sdl_event.type == sdl.SDL_WINDOWEVENT) {
        if (sdl_event.window.event == sdl.SDL_WINDOWEVENT_RESIZED) {
            if (findSdlWindow(sdl_event.window.windowID)) |sdl_window| {
                sdl_window.draw();
            }
            return 0;
        }
    }
    return 1; // unhandled
}

//----------------------------------------------------------------------------

var sdl_windows: std.ArrayList(SdlWindow) = undefined;

var window_config_file_path: ?[]u8 = null;

var vg: nvg = undefined;

const MainloopType = enum {
    wait_event, // updates only when an event occurs
    regular_interval, // runs at monitor refrsh rate
};
var mainloop_type: MainloopType = .wait_event;

var gpa = std.heap.GeneralPurposeAllocator(.{
    .enable_memory_limit = true,
}){};

pub fn main() !void {
    defer {
        if (builtin.mode == .Debug) {
            const check = gpa.deinit();
            if (check == .leak) @panic("Memory leak :(");
        }
    }
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    _ = &allocator;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("zcreative...\n", .{});

    if (builtin.os.tag == .windows) {
        _ = SetProcessDPIAware();
    }
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_TIMER | sdl.SDL_INIT_EVENTS) != 0) {
        sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    if (sdl.SDL_GetPrefPath(info.org_name, info.app_name)) |sdl_pref_path| {
        defer sdl.SDL_free(sdl_pref_path);
        const user_pref_path = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(sdl_pref_path)), 0);
        window_config_file_path = try std.fs.path.join(allocator, &.{ user_pref_path, "window.json" });
    }
    defer {
        if (window_config_file_path) |path| allocator.free(path);
    }

    if (builtin.os.tag == .macos) {
        //FIXME:...
        // enableAppleMomentumScroll();
    }

    // enable multitouch gestures from touchpads
    _ = sdl.SDL_SetHint(sdl.SDL_HINT_MOUSE_TOUCH_EVENTS, "1");

    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_STENCIL_SIZE, 1);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_MULTISAMPLESAMPLES, 4);
    _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);

    sdl_windows = std.ArrayList(SdlWindow).init(allocator);
    defer {
        // TODO: destroy all windows
        sdl_windows.deinit();
    }
    var main_window = try sdlCreateWindow("zcreative", 800, 600, .{});
    _ = &main_window;

    mainloop_type = .wait_event;
    _ = sdl.SDL_GL_SetSwapInterval(0); // VSync off

    _ = c.gladLoadGL();

    sdl.SDL_AddEventWatch(sdlEventWatch, null);


    //TODO: add .gui.Application struct ...
    
    vg = try nvg.gl.init(allocator, .{});
    defer vg.deinit();

    // quit app when there are no more windows open
    while (true) {
        var sdl_event: sdl.SDL_Event = undefined;
        switch (mainloop_type) {
            .wait_event => if (sdl.SDL_WaitEvent(&sdl_event) == 0) {
                sdl.SDL_Log("SDL_WaitEvent failed: %s", sdl.SDL_GetError());
            } else {
                // sdlHandleEvent(sdl_event);
            },
            .regular_interval => while (sdl.SDL_PollEvent(&sdl_event) != 0) {
                // sdlHandleEvent(sdl_event);
            },
        }

        for (sdl_windows.items) |*sdl_window| {
            if (sdl_window.isMinimized()) continue;
            if (sdl_window.dirty or mainloop_type == .regular_interval) sdl_window.draw();
        }
    }

        // vg.beginFrame(@floatFromInt(win_width), @floatFromInt(win_height), pxRatio);
        //     vg.rect(100,100, 120,30);
        //     vg.fillColor(nvg.rgba(255,192,0,255));
        //     vg.fill();
        // vg.endFrame();
        //

    try bw.flush(); // Don't forget to flush!
}

