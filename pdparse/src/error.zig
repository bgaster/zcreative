const std = @import("std");

pub const ScannerError = error{
    UnknownToken,
};

/// Optional diagnostics used for reporting useful errors
/// based on the approach taken in https://github.com/Hejsil/zig-clap/
pub const Diagnostic = struct {
    msg: []const u8 = "",
    line: usize = 0,
    // name: Names = Names{},

    pub fn report(diag: Diagnostic, stream: anytype, err: anyerror) !void {
        switch (err) {
            ScannerError.UnknownToken => try stream.print(
                "{s} (UnknownToken) at line {}\n",
                .{ diag.msg, diag.line },
            ),
            else => try stream.print("Error while parsing: {s}\n", .{@errorName(err)}),
        }
    }
};
