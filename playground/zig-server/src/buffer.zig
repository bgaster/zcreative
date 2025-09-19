const std = @import("std");

const Allocator = std.mem.Allocator;

// const BufferType = enum { jsonString, streamSource };

/// Wrapper around an array (to be removed) or StreamSource (which is itself a wrapper around a buffer or stream).
/// This was introduced as an intermediate step before transitioning directly to a stream source. However,
/// StreamSources behave a bit...disparate, so it might stick around.
pub const Buffer = struct {
    /// A string or StreamSource
    buffer: []const u8,
    /// The position in the array or the position of the StreamSource
    /// Note: StreamSource does support getPos but only for seekable streams
    position: u64 = 0,
    /// The last byte read
    last: ?u8 = null,
    /// A peek byte - doesn't count towards position* or being read.
    /// Note: It does actually count towards position but its existence subtracts from the returned position
    peekByte: ?u8 = null,
    /// A peek^2 byte - doesn't count towards position* or being read.
    /// Note: It does actually count towards position but its existence subtracts from the returned position
    peekNextByte: ?u8 = null,
    /// Returns the position of the next unread byte
    pub fn getPos(self: *Buffer) BufferErrors!u64 {
        return self.position;
    }
    /// Returns the total size of the buffer or maxInt if the size is unavailable
    pub fn getEndPos(self: *Buffer) BufferErrors!u64 {
        return self.buffer.len;
    }
    /// Skips over count bytes
    /// Note: Clears the last byte read if count > 0
    pub fn skipBytes(self: *Buffer, count: u64) BufferErrors!void {
        if (count == 0) return;
        self.position = self.position + count;
    }
    /// Reads a byte from the buffer
    pub fn readByte(self: *Buffer) BufferErrors!u8 {
        defer self.position += 1;
        self.last = self.buffer[try self.getPos()];
        return self.last.?;
    }
    /// Reads buffer.len worth of bytes into buffer
    pub fn read(self: *Buffer, buffer: []u8) BufferErrors!u64 {
        var index: u64 = 0;
        while (index != buffer.len) {
            buffer[index] = try self.readByte();
            index += 1;
        }
        self.last = buffer[buffer.len - 1];
        return index;
    }
    /// Reads up to len bytes into buffer
    pub fn readN(self: *Buffer, buffer: []u8, len: u64) BufferErrors!u64 {
        if (len >= buffer.len) unreachable;
        var index: u64 = 0;
        while (index != len and index != buffer.len) {
            buffer[index] = try self.readByte();
            index += 1;
        }
        self.last = buffer[buffer.len - 1];
        return index;
    }
    /// Returns the next byte but doesn't advance the read position
    pub fn peek(self: *Buffer) BufferErrors!u8 {
        return self.buffer[try self.getPos()];
    }
    /// Returns the second next byte but doesn't advance the read position
    pub fn peekNext(self: *Buffer) BufferErrors!u8 {
        return self.buffer[try self.getPos() + 1];
    }
    /// Returns the last byte
    pub fn lastByte(self: *Buffer) ?u8 {
        return self.last;
    }
};

pub const BufferErrors = BufferError;

pub const BufferError = error{ReadError};

pub fn bufferFromText(text: []const u8) Buffer {
    return Buffer{ .buffer = text };
}
