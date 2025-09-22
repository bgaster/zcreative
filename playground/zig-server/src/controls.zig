
const std = @import("std");
const Allocator = std.mem.Allocator;

// pub const ControllerType = enum {
//     Slider,
//     Button,
// };
//

pub const SLIDER_TYPE: i64 = 1;
pub const BUTTON_TYPE: i64 = 2;

pub const Slider = struct {
    name: []const u8,
    lower: i64,
    upper: i64,
    value: i64,
    increment: i64,
};

pub const Button = struct {
    value: bool, 
};

// pub const ControllerTypeUnion = union(ControllerType) {
//     slider: Slider,
//     button: Button,
// };
//
// pub const Control = struct {
//     name: [] const u8,
//     type: ControllerType,
//
//     value: ControllerTypeUnion,
// };

pub const Controls = struct {
    allocator: Allocator,

    sliders: std.ArrayList(Slider) = undefined,
    buttons: std.ArrayList(Button) = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .sliders = .empty,
            .buttons = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.sliders.deinit(self.allocator);
        self.buttons.deinit(self.allocator);
    }

    pub fn add(self: *Self, control: anytype) !usize {
        switch (@TypeOf(control)) {
            Slider => {
                try self.sliders.append(self.allocator, control);
                return self.sliders.items.len;
            },
            Button => {
                try self.buttons.append(self.allocator, control);
                return self.buttons.items.len;
            },
            else => {
                @compileError("Unsupported controller type '" ++ @typeName(@TypeOf(control)) ++ "'");
            },
        }
    }

    // pub fn numSlider(self: *Self) usize {
    //     return self.
    // }

    pub fn get(self: *Self, comptime T: type, index: usize) ?T {
        switch (T) {
            Slider => {
                if (index < self.sliders.items.len) {
                    return self.sliders.items[index];
                }
            },
            Button => {
                if (index < self.buttons.items.len) {
                    return self.buttons.items[index];
                }
            },
            else => {
                @compileError("Unsupported controller type '" ++ @typeName(T) ++ "'");
            },
        }
        return null;
    }

    pub fn update_slider(self: *Self, index: usize, value: i64) bool {
        if (index < self.sliders.items.len) {
            self.sliders.items[index].value = value;
            return true;
        }
        return false;
    }

    pub fn update_button(self: *Self, index: usize, value: bool) bool {
        if (index < self.buttons.items.len) {
            self.buttons.items[index].value = value;
            return true;
        }
        return false;
    }
};
