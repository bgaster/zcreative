
const std = @import("std");
const Allocator = std.mem.Allocator;

const osc = @import("osc_message.zig");
const OscSend = @import("osc_send.zig").OscSend;

const json = @import("json.zig");

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
    osc_prefix: []const u8,
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

    osc: OscSend = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator, udp_address: []const u8, udp_port: u16) !Self {
        // setup out going OSC socket
        var oscsend = OscSend.init(allocator);
        try oscsend.connect(false, udp_address, udp_port);

        return .{
            .allocator = allocator,
            .sliders = .empty,
            .buttons = .empty,
            .osc = oscsend,
        };
    }

    pub fn deinit(self: *Self) void {
        self.sliders.deinit(self.allocator);
        self.buttons.deinit(self.allocator);
        self.osc.close();
    }

    pub fn add_from_json(self: *Self, controls_json: *json.JsonValue) !void {
        if (controls_json.objectOrNull()) |obj| {
            if (obj.getOrNull("controls")) |cs| {
                if (cs.objectOrNull()) |os| {
                    if (os.getOrNull("sliders")) |ss| {
                        if (ss.arrayOrNull()) |sa| {
                            for (sa.items()) |s| {
                                if (s.objectOrNull()) |so| {
                                    if (so.contains("name") and so.contains("lower") and so.contains("upper") and 
                                        so.contains("value") and so.contains("increment") and so.contains("osc_prefix")) {

                                        const name = so.get("name");
                                        const lower = so.get("lower");
                                        const upper = so.get("upper");
                                        const value = so.get("value");
                                        const increment = so.get("increment");
                                        const osc_prefix = so.get("osc_prefix");

                                        if (name.type == .string and lower.type == .integer and upper.type == .integer
                                            and value.type == .integer and increment.type == .integer) {
                                            _ = try self.add(Slider{
                                                .name = try Allocator.dupe(self.allocator, u8, name.string()),
                                                .lower = lower.integer(),
                                                .upper = upper.integer(),
                                                .value = value.integer(),
                                                .increment = increment.integer(),
                                                .osc_prefix = try Allocator.dupe(self.allocator, u8, osc_prefix.string()),
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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

    pub fn send(self: *Self, index: usize) !bool {
        if (index < self.sliders.items.len) {
            const buflen = 256; 
            var buf: [buflen]u8 = undefined;
            const address = try std.fmt.bufPrint(
                &buf,
                // "/control/slider/{s}",
                "/{s}/{s}",
                .{ self.sliders.items[index].osc_prefix, self.sliders.items[index].name},
            );
            const msg = osc.OscMessage.init(address, &[_]osc.OscArgument{.{ .i = @intCast(self.sliders.items[index].value) }});
            try self.osc.send(msg);
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
