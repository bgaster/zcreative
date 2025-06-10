const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;


pub const Scanner = @This();

const Self = @This();

start: usize,
current: usize,
line: usize,

// the running list of tokens we scan from the source code
tokens: std.ArrayList(Token),
allocator: std.mem.Allocator,

// all the source code from our file or user input
source: []const u8,

// string to TokenType (enum) map (e.g. "and" -> TokenType.AND)
keyword_map: std.StringHashMap(TokenType),


pub fn init(allocator: Allocator) !*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        .source = "", 
        .start = 0, 
        .current = 0, 
        .line = 1, 
        .allocator = allocator, 
        .tokens = std.ArrayList(Token).init(allocator), 
        .keyword_map = token.initKeywords(allocator),
    };

    return self;
}

pub fn deinit(self: *Scanner) void {
    _ = self;
}
