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
const Rect = gui.geometry.Rect;
const info = @import("info.zig");

extern fn SetProcessDPIAware() callconv(.C) c_int;
// extern fn enableAppleMomentumScroll() callconv(.C) void;

// globals

// pub const CreateOptions = struct {
//     resizable: bool = true,
//     parent_id: ?u32 = null,
// };


// the following SDL struct is is based on:
//     https://github.com/fabioarnold/MiniPixel/
//
const SdlWindow = struct {
    handle: *sdl.SDL_Window,
    context: sdl.SDL_GLContext, 

    window: *gui.Window,
    dirty: bool = true,

    windowed_width: f32, // size when not maximized
    windowed_height: f32,

    video_width: f32,
    video_height: f32,
    video_scale: f32 = 1,

    fn create(title: [:0]const u8, width: u32, height: u32, options: gui.Window.CreateOptions, window: *gui.Window) !SdlWindow {
        var self: SdlWindow = SdlWindow{
            .windowed_width = @as(f32, @floatFromInt(width)),
            .windowed_height = @as(f32, @floatFromInt(height)),
            .video_width = @as(f32, @floatFromInt(width)),
            .video_height = @as(f32, @floatFromInt(height)),
            .handle = undefined,
            .context = undefined,
            .window = window,
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
        self.window.setSize(self.video_width, self.video_height);
    }

    pub fn draw(self: *SdlWindow) void {
        self.beginDraw();
        self.setupFrame();

        c.glClearColor(0.5, 0.5, 0.5, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(self.video_width, self.video_height, self.video_scale);
            // vg.rect(100,100, 120,30);
            // vg.fillColor(nvg.rgba(255,192,0,255));
            // vg.fill();
        self.window.draw(vg);
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

fn sdlProcessWindowEvent(window_event: c.SDL_WindowEvent) void {
    if (findSdlWindow(window_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        switch (window_event.event) {
            c.SDL_WINDOWEVENT_EXPOSED => {
                if (sdl_window.window.isBlockedByModal()) {
                    // TODO: find all modal windows
                    for (sdl_window.window.children.items) |child| {
                        if (child.is_modal) {
                            if (findSdlWindow(child.id)) |child_sdl_window| {
                                c.SDL_RaiseWindow(child_sdl_window.handle);
                            }
                        }
                    }
                }
            },
            c.SDL_WINDOWEVENT_ENTER => {
                var enter_event = gui.Event{ .type = .Enter };
                sdl_window.window.handleEvent(&enter_event);
            },
            c.SDL_WINDOWEVENT_LEAVE => {
                var leave_event = gui.Event{ .type = .Leave };
                sdl_window.window.handleEvent(&leave_event);
            },
            c.SDL_WINDOWEVENT_FOCUS_GAINED => {
                sdl_window.window.is_active = true;
            },
            c.SDL_WINDOWEVENT_FOCUS_LOST => {
                sdl_window.window.is_active = false;
                var leave_event = gui.Event{ .type = .Leave };
                sdl_window.window.handleEvent(&leave_event);
            },
            c.SDL_WINDOWEVENT_MINIMIZED => {
                if (sdl_window.window.isBlockedByModal()) {
                    c.SDL_RestoreWindow(sdl_window.handle);
                }
            },
            c.SDL_WINDOWEVENT_SIZE_CHANGED => {
                if (!sdl_window.isMaximized()) {
                    sdl_window.windowed_width = sdl_window.video_width;
                    sdl_window.windowed_height = sdl_window.video_height;
                }
            },
            c.SDL_WINDOWEVENT_CLOSE => app.requestWindowClose(sdl_window.window),
            else => {},
        }
    }
}

fn sdlQueryModState() u4 {
    var modifiers: u4 = 0;
    const sdl_mod_state = c.SDL_GetModState();
    if ((sdl_mod_state & c.KMOD_ALT) != 0) modifiers |= @as(u4, 1) << @intFromEnum(gui.Modifier.alt);
    if ((sdl_mod_state & c.KMOD_CTRL) != 0) modifiers |= @as(u4, 1) << @intFromEnum(gui.Modifier.ctrl);
    if ((sdl_mod_state & c.KMOD_SHIFT) != 0) modifiers |= @as(u4, 1) << @intFromEnum(gui.Modifier.shift);
    if ((sdl_mod_state & c.KMOD_GUI) != 0) modifiers |= @as(u4, 1) << @intFromEnum(gui.Modifier.super);
    return modifiers;
}

fn sdlProcessMouseMotion(motion_event: c.SDL_MouseMotionEvent) void {
    if (findSdlWindow(motion_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        if (motion_event.which == c.SDL_TOUCH_MOUSEID) {} else {
            var mx: f32 = @as(f32, @floatFromInt(motion_event.x));
            var my: f32 = @as(f32, @floatFromInt(motion_event.y));
            if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
                mx /= sdl_window.video_scale;
                my /= sdl_window.video_scale;
            }
            var me = gui.MouseEvent{
                .event = gui.Event{ .type = .MouseMove },
                .button = .none,
                .click_count = 0,
                .state = motion_event.state,
                .modifiers = sdlQueryModState(),
                .x = mx,
                .y = my,
                .wheel_x = 0,
                .wheel_y = 0,
            };
            sdl_window.window.handleEvent(&me.event);
        }
    }
}

fn sdlProcessMouseButton(button_event: c.SDL_MouseButtonEvent) void {
    if (is_touch_panning) return; // reject accidental button presses
    if (findSdlWindow(button_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        var mx: f32 = @as(f32, @floatFromInt(button_event.x));
        var my: f32 = @as(f32, @floatFromInt(button_event.y));
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }
        var me = gui.MouseEvent{
            .event = gui.Event{
                .type = if (button_event.state == c.SDL_PRESSED)
                    .MouseDown
                else
                    .MouseUp,
            },
            .button = switch (button_event.button) {
                c.SDL_BUTTON_LEFT => .left,
                c.SDL_BUTTON_MIDDLE => .middle,
                c.SDL_BUTTON_RIGHT => .right,
                c.SDL_BUTTON_X1 => .back,
                c.SDL_BUTTON_X2 => .forward,
                else => .none,
            },
            .click_count = button_event.clicks,
            .state = c.SDL_GetMouseState(null, null),
            .modifiers = sdlQueryModState(),
            .x = mx,
            .y = my,
            .wheel_x = 0,
            .wheel_y = 0,
        };
        sdl_window.window.handleEvent(&me.event);

        // TODO maybe if app gains focus?
        _ = c.SDL_CaptureMouse(if (button_event.state == c.SDL_PRESSED) c.SDL_TRUE else c.SDL_FALSE);
    }
}

fn sdlProcessMouseWheel(wheel_event: c.SDL_MouseWheelEvent) void {
    if (findSdlWindow(wheel_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;

        var x: i32 = undefined;
        var y: i32 = undefined;
        const state = c.SDL_GetMouseState(&x, &y);
        var mx: f32 = @as(f32, @floatFromInt(x));
        var my: f32 = @as(f32, @floatFromInt(y));
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }

        if (wheel_event.which == @as(c_int, @bitCast(c.SDL_TOUCH_MOUSEID)) or has_touch_mouse) {
            is_touch_panning = true;
            const magic_factor = 4; // TODO: we need floating point resolution
            var se = gui.TouchEvent{
                .event = gui.Event{ .type = .TouchPan },
                .x = mx,
                .y = my,
                .dx = magic_factor * @as(f32, @floatFromInt(wheel_event.x)),
                .dy = magic_factor * @as(f32, @floatFromInt(wheel_event.y)),
                .zoom = 0,
            };
            if (wheel_event.direction == c.SDL_MOUSEWHEEL_FLIPPED) {
                se.dx *= -1;
            }
            sdl_window.window.handleEvent(&se.event);
        } else {
            var me = gui.MouseEvent{
                .event = gui.Event{ .type = .MouseWheel },
                .button = .none,
                .click_count = 0,
                .state = state,
                .modifiers = sdlQueryModState(),
                .x = mx,
                .y = my,
                .wheel_x = wheel_event.x,
                .wheel_y = wheel_event.y, // TODO: swap if direction is inverse?
            };
            sdl_window.window.handleEvent(&me.event);
        }
    }
}

fn sdlProcessTouchFinger(finger_event: c.SDL_TouchFingerEvent) void {
    if (finger_event.touchId == @as(c_int, @bitCast(c.SDL_TOUCH_MOUSEID))) {
        // has_touch_mouse = true; // doesn't work on windows
    }
    touch_window_id = finger_event.windowID;
    if (finger_event.type == c.SDL_FINGERUP) {
        // reset touch gestures
        is_touch_panning = false;
        is_touch_zooming = false;
    }
    // std.debug.print("touchId: {}\n", .{finger_event.touchId});
}

fn translateSdlKey(sym: c.SDL_Keycode) gui.KeyCode {
    return switch (sym) {
        c.SDLK_RETURN, c.SDLK_KP_ENTER => .Return,
        c.SDLK_0, c.SDLK_KP_0 => .D0,
        c.SDLK_1, c.SDLK_KP_1 => .D1,
        c.SDLK_2, c.SDLK_KP_2 => .D2,
        c.SDLK_3, c.SDLK_KP_3 => .D3,
        c.SDLK_4, c.SDLK_KP_4 => .D4,
        c.SDLK_5, c.SDLK_KP_5 => .D5,
        c.SDLK_6, c.SDLK_KP_6 => .D6,
        c.SDLK_7, c.SDLK_KP_7 => .D7,
        c.SDLK_8, c.SDLK_KP_8 => .D8,
        c.SDLK_9, c.SDLK_KP_9 => .D9,
        c.SDLK_PERIOD, c.SDLK_KP_DECIMAL => .Period,
        c.SDLK_COMMA => .Comma,
        c.SDLK_ESCAPE => .Escape,
        c.SDLK_BACKSPACE => .Backspace,
        c.SDLK_SPACE => .Space,
        c.SDLK_PLUS, c.SDLK_KP_PLUS => .Plus,
        c.SDLK_MINUS, c.SDLK_KP_MINUS => .Minus,
        c.SDLK_ASTERISK, c.SDLK_KP_MULTIPLY => .Asterisk,
        c.SDLK_SLASH, c.SDLK_KP_DIVIDE => .Slash,
        c.SDLK_PERCENT => .Percent,
        c.SDLK_DELETE => .Delete,
        c.SDLK_HOME => .Home,
        c.SDLK_END => .End,
        c.SDLK_TAB => .Tab,
        c.SDLK_LSHIFT => .LShift,
        c.SDLK_RSHIFT => .RShift,
        c.SDLK_LCTRL => .LCtrl,
        c.SDLK_RCTRL => .RCtrl,
        c.SDLK_LALT => .LAlt,
        c.SDLK_RALT => .RAlt,
        c.SDLK_LEFT => .Left,
        c.SDLK_RIGHT => .Right,
        c.SDLK_UP => .Up,
        c.SDLK_DOWN => .Down,
        c.SDLK_a...c.SDLK_z => @as(gui.KeyCode, @enumFromInt(@intFromEnum(gui.KeyCode.A) + @as(u8, @intCast(sym - c.SDLK_a)))),
        c.SDLK_HASH => .Hash,
        else => .Unknown,
    };
}

fn sdlProcessKey(key_event: c.SDL_KeyboardEvent) void {
    if (findSdlWindow(key_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        var ke = gui.KeyEvent{
            .event = gui.Event{ .type = if (key_event.type == c.SDL_KEYDOWN) .KeyDown else .KeyUp },
            .key = translateSdlKey(key_event.keysym.sym),
            .down = key_event.state == c.SDL_PRESSED,
            .repeat = key_event.repeat > 0,
            .modifiers = sdlQueryModState(),
        };
        sdl_window.window.handleEvent(&ke.event);
    }
}

var first_surrogate_half: ?u16 = null;

fn sdlProcessTextInput(text_event: c.SDL_TextInputEvent) void {
    if (findSdlWindow(text_event.windowID)) |sdl_window| {
        sdl_window.dirty = true;
        const text = mem.sliceTo(&text_event.text, 0);

        if (std.unicode.utf8ValidateSlice(text)) {
            var te = gui.TextInputEvent{
                .text = text,
            };
            sdl_window.window.handleEvent(&te.event);
        } else if (text.len == 3) {
            _ = std.unicode.utf8Decode(text) catch |err| switch (err) {
                error.Utf8EncodesSurrogateHalf => {
                    var codepoint: u21 = text[0] & 0b00001111;
                    codepoint <<= 6;
                    codepoint |= text[1] & 0b00111111;
                    codepoint <<= 6;
                    codepoint |= text[2] & 0b00111111;
                    const surrogate = @as(u16, @intCast(codepoint));

                    if (first_surrogate_half) |first_surrogate0| {
                        const utf16 = [_]u16{ first_surrogate0, surrogate };
                        var utf8 = [_]u8{0} ** 4;
                        _ = std.unicode.utf16leToUtf8(&utf8, &utf16) catch unreachable;
                        first_surrogate_half = null;

                        var te = gui.TextInputEvent{
                            .text = &utf8,
                        };
                        sdl_window.window.handleEvent(&te.event);
                    } else {
                        first_surrogate_half = surrogate;
                    }
                },
                else => {},
            };
        }
    }
}

fn sdlProcessUserEvent(user_event: c.SDL_UserEvent) void {
    markAllWindowsAsDirty();
    switch (user_event.code) {
        sdl.SDL_USEREVENT_TIMER => {
            var timer = @as(*gui.Timer, @alignCast(@ptrCast(user_event.data1)));
            timer.onElapsed();
        },
        else => {},
    }
}

fn sdlProcessDropFile(drop_event: c.SDL_DropEvent) void {
    markAllWindowsAsDirty();
    // const file_path = std.mem.sliceTo(drop_event.file, 0);
    // editor_widget.tryLoadDocument(file_path);
    sdl.SDL_free(drop_event.file);
}

fn sdlProcessClipboardUpdate() void {
    markAllWindowsAsDirty();
    var event = gui.Event{ .type = .ClipboardUpdate };
    app.broadcastEvent(&event);
}

fn sdlProcessMultiGesture(gesture_event: sdl.SDL_MultiGestureEvent) void {
    if (gesture_event.numFingers != 2 or is_touch_panning) return;
    if (@abs(gesture_event.dDist) > 0.004) {
        is_touch_zooming = true;
    }
    if (!is_touch_zooming) return;
    // there's no window id :( -> broadcast to all windows
    for (sdl_windows.items) |*sdl_window| {
        sdl_window.dirty = true;
        var x: i32 = undefined;
        var y: i32 = undefined;
        _ = sdl.SDL_GetMouseState(&x, &y);
        var mx: f32 = @as(f32, @floatFromInt(x));
        var my: f32 = @as(f32, @floatFromInt(y));
        if (builtin.os.tag == .windows or builtin.os.tag == .linux) {
            mx /= sdl_window.video_scale;
            my /= sdl_window.video_scale;
        }

        const magic_factor = 4;
        var se = gui.TouchEvent{
            .event = gui.Event{ .type = .TouchZoom },
            .x = mx,
            .y = my,
            .dx = 0,
            .dy = 0,
            .zoom = magic_factor * gesture_event.dDist,
        };
        sdl_window.window.handleEvent(&se.event);
    }
}


fn sdlShowCursor(enable: bool) void {
    _ = sdl.SDL_ShowCursor(if (enable) sdl.SDL_ENABLE else sdl.SDL_DISABLE);
}

fn sdlCreateWindow(title: [:0]const u8, width: u32, height: u32, options: gui.Window.CreateOptions, window: *gui.Window) !u32 {
    const sdl_window = try SdlWindow.create(title, width, height, options, window);
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

fn sdlAddTimer(timer: *gui.Timer, interval: u32) u32 {
    const res = sdl.SDL_AddTimer(interval, sdlTimerCallback, timer);
    if (res == 0) {
        std.debug.print("SDL_AddTimer failed: {s}", .{sdl.SDL_GetError()});
    }
    return @as(u32, @intCast(res));
}

fn sdlCancelTimer(timer_id: u32) void {
    _ = sdl.SDL_RemoveTimer(@as(c_int, @intCast(timer_id)));
    //if (!res) std.debug.print("SDL_RemoveTimer failed: {}", .{c.SDL_GetError()});
}

const SDL_USEREVENT_TIMER = 1;

fn sdlTimerCallback(interval: u32, param: ?*anyopaque) callconv(.C) u32 {
    var userevent: sdl.SDL_UserEvent = undefined;
    userevent.type = sdl.SDL_USEREVENT;
    userevent.code = SDL_USEREVENT_TIMER;
    userevent.data1 = param;

    var event: sdl.SDL_Event = undefined;
    event.type = sdl.SDL_USEREVENT;
    event.user = userevent;

    _ = sdl.SDL_PushEvent(&event);

    return interval;
}

fn sdlSetWindowTitle(window_id: u32, title: [:0]const u8) void {
    if (findSdlWindow(window_id)) |window| {
        sdl.SDL_SetWindowTitle(window.handle, title.ptr);
    }
}

pub fn sdlHasClipboardText() bool {
    return sdl.SDL_HasClipboardText() == sdl.SDL_TRUE;
}

pub fn sdlGetClipboardText(allocator: std.mem.Allocator) !?[]const u8 {
    const sdl_text = sdl.SDL_GetClipboardText();
    if (sdl_text == null) return null;
    const text = try allocator.dupe(u8, std.mem.sliceTo(sdl_text, 0));
    sdl.SDL_free(sdl_text);
    return text;
}

pub fn sdlSetClipboardText(allocator: std.mem.Allocator, text: []const u8) !void {
    const sdl_text = try allocator.dupeZ(u8, text);
    defer allocator.free(sdl_text);
    if (sdl.SDL_SetClipboardText(sdl_text.ptr) != 0) {
        return error.SdlSetClipboardTextFailed;
    }
    sdlProcessClipboardUpdate(); // broadcasts a gui.ClipboardUpdate event to all windows
}

fn sdlHandleEvent(sdl_event: c.SDL_Event) void {
    switch (sdl_event.type) {
        sdl.SDL_WINDOWEVENT => sdlProcessWindowEvent(sdl_event.window),
        sdl.SDL_MOUSEMOTION => sdlProcessMouseMotion(sdl_event.motion),
        sdl.SDL_MOUSEBUTTONDOWN, sdl.SDL_MOUSEBUTTONUP => sdlProcessMouseButton(sdl_event.button),
        sdl.SDL_MOUSEWHEEL => sdlProcessMouseWheel(sdl_event.wheel),
        sdl.SDL_FINGERMOTION, sdl.SDL_FINGERDOWN, c.SDL_FINGERUP => sdlProcessTouchFinger(sdl_event.tfinger),
        sdl.SDL_KEYDOWN, sdl.SDL_KEYUP => sdlProcessKey(sdl_event.key),
        sdl.SDL_TEXTINPUT => sdlProcessTextInput(sdl_event.text),
        sdl.SDL_USEREVENT => sdlProcessUserEvent(sdl_event.user),
        sdl.SDL_DROPFILE => sdlProcessDropFile(sdl_event.drop),
        sdl.SDL_CLIPBOARDUPDATE => sdlProcessClipboardUpdate(),
        // c.SDL_MULTIGESTURE => sdlProcessMultiGesture(sdl_event.mgesture),
        else => {},
    }
}

//----------------------------------------------------------------------------

var sdl_windows: std.ArrayList(SdlWindow) = undefined;

var app: *gui.Application = undefined;

var window_config_file_path: ?[]u8 = null;

var vg: nvg = undefined;

var has_touch_mouse: bool = false;
var touch_window_id: c_uint = 0;
var is_touch_panning: bool = false;
var is_touch_zooming: bool = false;

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

    app = try gui.Application.init(allocator, .{
        .createWindow = sdlCreateWindow,
        .destroyWindow = sdlDestroyWindow,
        .setWindowTitle = sdlSetWindowTitle,
        .startTimer = sdlAddTimer,
        .cancelTimer = sdlCancelTimer,
        .showCursor = sdlShowCursor,
        .hasClipboardText = sdlHasClipboardText,
        .getClipboardText = sdlGetClipboardText,
        .setClipboardText = sdlSetClipboardText,
    });
    defer app.deinit();
    var main_window = try app.createWindow("zcreative", 800, 600, .{});
    // var main_window = try sdlCreateWindow("zcreative", 800, 600, .{});
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

