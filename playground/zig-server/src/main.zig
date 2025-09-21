//! 
//! zcreative server
//!

const std = @import("std");

const ctrls = @import("ctrls.zig");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;

    const stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    try stdout.print("zcreative server\n", .{});
    try stdout.flush();

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();

    // const spawnConfig = std.Thread.SpawnConfig{
    //     .allocator = allocator,
    // };

    try ctrls.start(allocator);
    // const thread = try std.Thread.spawn(spawnConfig, ctrls.start, .{allocator});
    // thread.join();

    try stdout.flush();
}
