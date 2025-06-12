const std = @import("std");

const Scanner = @import("Scanner.zig");

pub const Pd = struct {

	pub fn scanFile(path: []const u8, allocator: std.mem.Allocator) !void {
        // Open the file at the specified path in the current working directory.
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.log.err("Failed to open file: {s} {s}", .{ path, @errorName(err) });
            return;
        };
        defer file.close();

        // Read the entire file into memory, allocating space using the provided allocator.
        const source = file.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch |err| {
            std.log.err("Failed to read file: {s}", .{@errorName(err)});
            return;
        };
        defer allocator.free(source);

        var scanner = try Scanner.init(allocator, source);
        defer scanner.deinit();

        const out = std.io.getStdOut().writer();

        while (!scanner.isAtEnd()) {
            try scanner.scanToken(); 
            try out.print("\n", .{});
        }

    }

    pub fn scanPrompt(allocator: std.mem.Allocator) !void {
        const in = std.io.getStdIn().reader();
        const out = std.io.getStdOut().writer();

        // Enter an infinite loop to continuously prompt the user for input.
        while (true) {
            try out.print("> ", .{});
            // Read a line of input from the user, allocating memory for the line.
            const source = try in.readUntilDelimiterAlloc(allocator, ';', std.math.maxInt(usize));

            // If the input isn't empty or just a newline, process the input.
            if (source.len > 0 and !std.ascii.eqlIgnoreCase(source, " ")) {
                var scanner = try Scanner.init(allocator, source);
                defer scanner.deinit();

                while (!scanner.isAtEnd()) {
                    try scanner.scanToken(); 
                    try out.print("\n", .{});
                }
            }
        }
    }
};
