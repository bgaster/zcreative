const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const errorMsgs = @import("error.zig");
const token = @import("token.zig");
const Token = token.Token;
const Literal = token.Literal;
const TokenType = token.TokenType;


pub const ScannerOptions = struct {
    allocator: std.mem.Allocator,
    diagnostic: ?*errorMsgs.Diagnostic = null,
};

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

diagnostic: ?*errorMsgs.Diagnostic = null,

pub fn init(allocator: Allocator, source: []const u8, options: ScannerOptions) !*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        .source = source, 
        .start = 0, 
        .current = 0, 
        .line = 1, 
        .allocator = options.allocator, 
        .diagnostic = options.diagnostic, 
        .tokens = std.ArrayList(Token).init(allocator), 
        .keyword_map = token.initKeywords(allocator),
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.keyword_map.deinit();
    self.tokens.deinit();
    self.allocator.destroy(self);
}

fn skipWhitespace(self: *Self) void {
    while (!self.isAtEnd()) {
        const c = self.peek();
        if (c == ' ' or c == '\r' or c == '\t') {
            _ = self.advance();
        } else if (c == '\n') {
            self.line += 1;
            _ = self.advance();
        } else if (c == '/') {
            if (self.peekNext() == '/') {
                // A comment goes until the end of the line.
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    _ = self.advance();
                }
            } else {
                return;
            }
        } else {
            return;
        }
    }
}

pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
    while (!self.isAtEnd()) {
        self.start = self.current;
        try self.scanToken();
    }
    return self.tokens;
}

pub fn isAtEnd(self: Self) bool {
    return self.current >= self.source.len;
}

fn peek(self: *Self) u8 {
    if (self.isAtEnd()) {
        return 0; 
    }
    return self.source[self.current];
}

fn peekNext(self: *Self) u8 {
    if (self.isAtEnd()) {
        return 0; 
    }
    return self.source[self.current + 1];
}

pub fn scanToken(self: *Self) !void {
    self.skipWhitespace();
    self.start = self.current;

    if (self.isAtEnd()) {
        return self.addToken(TokenType.EOF, Literal{ .void = {} });
    }
    const c = self.advance();

    if (isDigit(c)) {
        return self.number();
    }
    if (isAlpha(c)) {
        return self.identifier();
    }
    if (c == '#') {
        return self.hash();
    }
    if (c == '\\' and self.match('$')) {
        return self.dollar();
    }

    switch(c) {
        '(' => try self.addToken(TokenType.LEFT_PAREN, Literal{ .void = {} }),
        ')' => try self.addToken(TokenType.RIGHT_PAREN, Literal{ .void = {} }),
        ';' => try self.addToken(TokenType.SEMICOLON, Literal{ .void = {} }),
        ',' => try self.addToken(TokenType.COMMA, Literal{ .void = {} }),
        '.' => try self.addToken(TokenType.DOT, Literal{ .void = {} }),
        '-' => try self.addToken(if (self.match('~')) TokenType.MINUS_DSP
                                 else TokenType.MINUS, Literal{ .void = {} }),
        '+' => try self.addToken(if (self.match('~')) TokenType.PLUS_DSP
                                 else TokenType.PLUS, Literal{ .void = {} }),
        '/' => try self.addToken(if (self.match('~')) TokenType.SLASH_DSP
                                 else TokenType.SLASH, Literal{ .void = {} }),
        '*' => try self.addToken(if (self.match('~')) TokenType.STAR_DSP
                                 else TokenType.STAR, Literal{ .void = {} }),
        else => {
            return self.make_error("Unexpected character.", error.UnknownToken);
        }
    }
}

fn dollar(self: *Scanner) !void {
    try self.addToken(TokenType.DOLLAR, Literal{ .void = {} });
    self.start = self.current;
    return self.number();
}

fn hash(self: *Scanner) !void {
    if (self.match('X')) {
        try self.addToken(TokenType.HASH_X, Literal{ .void = {} });
    }
    else if (self.match('N')) {
        try self.addToken(TokenType.HASH_N, Literal{ .void = {} });
    }
    else if (std.ascii.isHex(self.peek())) {
        while (std.ascii.isHex(self.peek())) {
                _ = self.advance();
        }
        try self.addToken(TokenType.RGB, Literal{ .str = self.source[self.start..self.current] });
    }
    else {
        try self.addToken(TokenType.HASH, Literal{ .void = {} });
    }
}

pub fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) {
        return false;
    }

    if (self.source[self.current] != expected) {
        return false;
    }

    self.current += 1;
    return true;
}

pub fn identifier(self: *Self) !void {
    while (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '.') {
        _ = self.advance();
    }

    // Check if the identifier is a reserved keyword
    var token_type = TokenType.IDENTIFIER;
    const str = self.source[self.start..self.current];
    const keyword = self.keyword_map.get(str);

    if (keyword) |value| {
        token_type = value;
        try self.addToken(token_type, Literal{ .void = {} });
    }
    else {
        try self.addToken(token_type, Literal{ .str = str });
    }
}

fn number(self: *Scanner) !void {
    var is_int = true;
    while (std.ascii.isDigit(self.peek())) {
        _ = self.advance();
    }

    if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
        is_int = false;
        _ = self.advance();
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
    }

    if (is_int) {
        const int = try std.fmt.parseInt(i64, self.source[self.start..self.current], 10);
        try self.addToken(TokenType.INT, Literal{ .int = int });
    } else {
        const float = try std.fmt.parseFloat(f64, self.source[self.start..self.current]);
        try self.addToken(TokenType.FLOAT, Literal{ .float = float });
    }
}

pub fn addToken(self: *Scanner, token_type: TokenType, literal: Literal) !void {
    const t = Token{ 
        .type = token_type, 
        .literal = literal, 
        .line = self.line, 
        .lexeme = self.source[self.start..self.current] 
    };
    try self.tokens.append(t);
    // t.print();
}

fn advance(self: *Self) u8 {
    self.current += 1;
    return self.source[self.current - 1];
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

fn make_error(self: Self, msg: []const u8, _err: anytype) @TypeOf(_err) {
    if (self.diagnostic) |d|
        d.* = .{ .msg = msg, .line = self.line };
    return _err;
}
