//! 
//! zcreative server
//!

const std = @import("std");

const clap = @import("clap");

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

    const params = comptime clap.parseParamsComptime(
        \\-h, --help     Display this help and exit.
        \\--ip <str>     IP address for websocket server.
        \\<str>
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit.
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    var ip: ?[]const u8 = null;
    var file: ?[]const u8 = null;

    if (res.args.help != 0) {
        std.debug.print("--help\n", .{});
    }
    if (res.args.ip) |s| {
        ip = s;
    }
    if (res.positionals[0]) |f| {
        file = f;
    }

    // const spawnConfig = std.Thread.SpawnConfig{
    //     .allocator = allocator,
    // };

    try ctrls.start(allocator, ip, file);
    // const thread = try std.Thread.spawn(spawnConfig, ctrls.start, .{allocator});
    // thread.join();

    try stdout.flush();
}
