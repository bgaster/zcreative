const std = @import("std");
const builtin = @import("builtin");

const pdparse = @import("pdparse");

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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try pdparse.Pd.scanPrompt(allocator);
    } else if (args.len == 2) {
        try pdparse.Pd.scanFile(args[1], allocator);
    } else {
        std.log.err("usage: pdparse example.pd", .{});
        return;
    }
}
