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
        for (self.patches.items) |patch| patch.deinit();
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
        self.args.deinit();

        for (self.nodes.items) |node| node.deinit();
        self.nodes.deinit();
        self.connections.deinit();
    }

    pub fn print(self: @This(), writer: anytype) !void {
        try writer.print("#N canvas {} {} {} {};\n", .{ self.layout.x, self.layout.y, self.layout.width, self.layout.height });
        for (self.nodes.items) |node| {
            try node.print(writer);
        }

        for (self.connections.items) |connection| {
            try connection.print(writer);
        }
    }
};

pub const ArgType = enum {
    tfloat,
    tint,
    tdollar,
    tsignal,
    tstring,
    tempty,
};

pub const Arg = union(ArgType) {
    tfloat: f32,
    tint: i32,
    tdollar: i32,
    tsignal: f32,
    tstring: []const u8,
    tempty: void,

    pub fn print(self: @This(), writer: anytype) !void {
        switch (self) {
            .tfloat => |f| try writer.print("{d:.2}", .{f}),
            .tint   => |i| try writer.print("{}", .{i}),
            .tdollar => |i| try writer.print("\\${}", .{i}),
            .tsignal => |f| try writer.print("{d:.2}", .{f}),
            .tstring => |s| try writer.print("{s}", .{s}),
            .tempty => try writer.print("empty", .{}),
        }
    }
};

pub const NodeType = enum {
    floatatom,
    intatom,

    print,
    msg,
    bng,
    loadbang,
    receive,
    send,
    text,

    // non signals
    plus,
    minus,
    star,
    slash,

    // signals
    splus, 
    sminus, 
    sstar, 
    sslash, 

    undefined,
};

pub const NodeClass = enum {
    control, 
    generic,
    subpatch,
    undefined,
};

pub const Node = struct {
    id: Id,
    ttype: NodeType,
    args: std.ArrayList(Arg),
    class: NodeClass,
    layout: Layout,

    pub fn init(allocator: Allocator) @This() {
        return .{
            .id = 0,
            .ttype = .undefined,
            .args = std.ArrayList(Arg).init(allocator), 
            .class = .undefined,
            .layout = . {
                .x = 0,
                .y = 0,
            },
        };
    }

    pub fn deinit(self: @This()) void {
        self.args.deinit();
    }

    pub fn print(self: @This(), writer: anytype) !void {
        try writer.print("#X ", .{});
        var is_obj = false;
        var is_text = false;
        const str = switch(self.ttype) {
            .floatatom => "floatatom",
            .intatom   => "intatom",
            .print     => value: { 
                is_obj = true; 
                break :value "print"; 
            },
            .msg       => "msg",
            .bng       => "bng",
            .plus      => value: {
                is_obj = true;
                break :value "+";
            },
            .minus      => value: {
                is_obj = true;
                break :value "-";
            },
            .star      => value: {
                is_obj = true;
                break :value "*";
            },
            .receive      => value: {
                is_obj = true;
                break :value "r";
            },
            .send      => value: {
                is_obj = true;
                break :value "s";
            },
            .text      => value: {
                is_text = true;
                break :value "text";
            },
            .slash      => value: {
                is_obj = true;
                break :value "/";
            },
            .loadbang      => value: {
                is_obj = true;
                break :value "loadbang";
            },
            .splus      => value: {
                is_obj = true;
                break :value "+~";
            },
            .sminus     => value: {
                is_obj = true;
                break :value "-~";
            },
            .sstar     => value: {
                is_obj = true;
                break :value "*~";
            },
            .sslash     => value: {
                is_obj = true;
                break :value "/~";
            },
            .undefined => "undefined",
        };
        if (is_obj) {
            try writer.print("obj {} {} {s}", .{ self.layout.x, self.layout.y, str });
        }
        else {
            try writer.print("{s} {} {}", .{ str, self.layout.x, self.layout.y });
        }
        for (self.args.items) |arg| {
            try writer.print(" ", .{});
            try arg.print(writer);
        }
        try writer.print(";\n", .{});
    }
};

pub const Port = struct {
    id: Id,
    index: Id,
};

pub const Connection = struct {
    source: Port,
    sink: Port,

    pub fn print(self: @This(), writer: anytype) !void {
        try writer.print("#X connect {} {} {} {};\n", .{ self.source.id, self.source.index, self.sink.id, self.sink.index });
    }
};
