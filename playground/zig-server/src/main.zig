//! 
//! zcreative server
//!

const std = @import("std");

const ctrls = @import("ctrls.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("zcreative server\n", .{});
    try bw.flush(); 

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();

    // const spawnConfig = std.Thread.SpawnConfig{
    //     .allocator = allocator,
    // };

    ctrls.start(allocator);
    // const thread = try std.Thread.spawn(spawnConfig, ctrls.start, .{allocator});
    // thread.join();

    try bw.flush(); // Don't forget to flush!
}
