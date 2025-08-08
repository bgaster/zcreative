const std = @import("std");

const Allocator = std.mem.Allocator;

pub const JSON = struct {
    empty: bool,
    array_count: u32,
    // str: std.ArrayList(u8),
    // w: std.ArrayList(u8).Writer,

    pub fn init(w: std.ArrayList(u8).Writer) !JSON {
        // var str = std.ArrayList(u8).init(allocator);
        // var w = str.writer();
        _ = try w.write("{");

        return .{
            .empty = true,
            .array_count = 0,
            // .str = str,
            // .w = w,
        };
    }

    pub fn deinit(self: *JSON) void {
        _ = self;
    }

    fn add_comma(self: *JSON, w: std.ArrayList(u8).Writer) !void {
        if (!self.empty) {
            _ = try w.write(", ");
        }
        else {
            self.empty = false;
        }
    }

    pub fn add_tagged_string(self: *JSON, tag: []const u8, str: [] const u8, w: std.ArrayList(u8).Writer) !void {
        try self.add_comma(w);
        _ = try w.write("\"");
        _ = try w.write(tag);
        _ = try w.write("\": \"");
        _ = try w.write(str);
        _ = try w.write("\"");
    } 

    pub fn begin_array(self: *JSON, tag: []const u8, w: std.ArrayList(u8).Writer) !void {
        try self.add_comma(w);
        _ = try w.write("\"");
        _ = try w.write(tag);
        _ = try w.write("\": ");
        _ = try w.write("[");
        self.array_count = 0;
    }

    pub fn add_array_element(self: *JSON, bytes:[]const u8, w: std.ArrayList(u8).Writer) !void {
        if (self.array_count > 0) {
            _ = try w.write(", ");
        }
        _ = try w.write("\"");
        _ = try w.write(bytes);
        _ = try w.write("\"");
        self.array_count = self.array_count + 1;
    }

    pub fn end_array(self: *JSON, w: std.ArrayList(u8).Writer) !void {
        _ = try w.write("]");
        self.array_count = 0;
    }

    pub fn end(self: *JSON, w: std.ArrayList(u8).Writer) !void {
        _ = self;
        _ = try w.write("}");
    }
};


