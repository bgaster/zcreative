const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

pub const Id = u32;

pub const Root = struct {
    root_patch_id: Id,
    patches: std.ArrayList(Patch),

    pub fn init(allocator: Allocator, id: u32) @This() {
       return .{
            .root_patch_id = id,
            .patches = std.ArrayList(Patch).init(allocator), 
        };
 
    }

    pub fn deinit(self: @This()) void {
        self.patches.deinit();
    }


    pub fn print(self: @This(), writer: anytype) !void {
        for (self.patches.items) |patch| {
            try patch.print(writer);
        }
    }
};

pub const Layout = struct {
    x: u32 = 0,
    y: u32 = 0,
    size: u32 = 0,
    hold: u32 = 0,
    interrupt: u32 = 0,
    width_in_chars: u32 = 0,
    label_pos: u32 = 0,
    label: []const u8 = "",
    label_font: u32 = 0,
    label_font_size: u32 = 0,
    bg_colour: []const u8 = "",
    fg_colour: []const u8 = "",
    label_colour: []const u8 = "",

    pub fn init(
        x: u32,
        y: u32,
        size: u32,
        hold: u32,
        interrupt: u32,
        width_in_chars: u32,
        label_pos: u32,
        label: []const u8,
        label_font: u32,
        label_font_size: u32,
        bg_colour: []const u8,
        fg_colour: []const u8,
        label_colour: []const u8) @This() {
        
        return .{
            .x = x, 
            .y = y, 
            .size = size,
            .hold = hold, 
            .interrupt = interrupt,
            .width_in_chars = width_in_chars,
            .label_pos = label_pos,
            .label = label,
            .label_font = label_font,
            .label_font_size = label_font_size,
            .bg_colour = bg_colour,
            .fg_colour = fg_colour,
            .label_colour = label_colour
        };
    }
};

pub const Patch = struct {
    id: u32,
    layout: struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    },
    args: std.ArrayList(Arg),
    nodes: std.ArrayList(Node),
    connections: std.ArrayList(Connection),

    pub fn init(allocator: Allocator, id: u32, x: u32, y: u32, width: u32, height: u32) @This() {
        return .{
            .id = id,
            .layout = . {
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .args = std.ArrayList(Arg).init(allocator), 
            .nodes = std.ArrayList(Node).init(allocator), 
            .connections = std.ArrayList(Connection).init(allocator), 
        };
    }

    pub fn deinit(self: @This()) void {
        self.args.patches.deinit();
        self.nodes.patches.deinit();
        self.connections.patches.deinit();
    }

    pub fn print(self: @This(), writer: anytype) !void {
        try writer.print("#N canvas {} {} {} {}", .{ self.layout.x, self.layout.y, self.layout.width, self.layout.height });
    }
};

pub const ArgType = enum {
    tfloat,
    tint,
    tsignal,
    tstring,
    tempty,
};

pub const Arg = union(ArgType) {
    tfloat: f32,
    tint: i32,
    tsignal: f32,
    tstring: []const u8,
    tempty: void,
};

pub const NodeType = enum {
    floatatom,
    intatom,

    print,
    msg,
    bng,

    // non signals
    plus,

    // signals
    splus, 
};

pub const NodeClass = enum {
    control, 
    generic,
    subpatch,
};

pub const Node = struct {
    id: Id,
    ttype: NodeType,
    args: std.ArrayList(Arg),
    class: NodeClass,
    layout: Layout,
};

pub const Port = struct {
    id: Id,
    index: Id,
};

pub const Connection = struct {
    source: Port,
    sink: Port,
};
