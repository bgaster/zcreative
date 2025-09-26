//! 
//! zcreative server
//!

const std = @import("std");

const clap = @import("clap");

const ctrls = @import("ctrls.zig");

const json = @import("json.zig");

fn readFile(file_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Open the file for reading
    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    // Get the file size
    const file_size = try file.getEndPos();

    // Allocate buffer for the file content
    const buffer = try allocator.alloc(u8, file_size);

    // Read the file into the buffer
    _ = try file.readAll(buffer);

    return buffer;
}

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

    // var ip: ?[]const u8 = null;
    // var controls: ?*json.JsonValue = null;

    if (res.args.help != 0) {
        std.debug.print("--help\n", .{});
    }
    // see if ip address 
    const ip: []const u8 = if (res.args.ip) |s| s else "192.168.1.18:8080";

    // get control input
    if (res.positionals[0]) |file_path| {
        // Reading from the file
        const file = try readFile(file_path, allocator);
        const controls = try json.parse(file, allocator);
        allocator.free(file);
        try ctrls.start(allocator, ip, controls);
    }

    // const spawnConfig = std.Thread.SpawnConfig{
    //     .allocator = allocator,
    // };

    // const thread = try std.Thread.spawn(spawnConfig, ctrls.start, .{allocator});
    // thread.join();

    try stdout.flush();
}
