const std = @import("std");

pub const Literal = union(enum) { 
    void,
    int: i64, 
    float: f64, 
    str: []const u8 
};

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    COMMA,
    DOT,
    PLUS,
    PLUS_DSP,
    MINUS,
    MINUS_DSP,
    SEMICOLON,
    SLASH,
    STAR,
    STAR_DSP,
    HASH,
    HASH_N,
    HASH_X,
    SEMI,

    // literals
    IDENTIFIER,
    TEXT,
    INT,
    FLOAT,

    // Keywords.
    AND,
    BANG,
    LOADBANG,
    CONNECT,
    CANVAS,
    OR,
    XOR,
    NOT,
    IF,
    ELSE,
    PRINT,
    MESSAGE,
    OBJ,
    FLOATATOM,
    EMPTY,

    ERROR,

    EOF,
};

pub fn initKeywords(allocator: std.mem.Allocator) std.StringHashMap(TokenType) {
    var keywords = std.StringHashMap(TokenType).init(allocator);
    keywords.put("and", TokenType.AND) catch unreachable;
    keywords.put("bng", TokenType.BANG) catch unreachable;
    keywords.put("loadbang", TokenType.LOADBANG) catch unreachable;
    keywords.put("empty", TokenType.EMPTY) catch unreachable;
    keywords.put("floatatom", TokenType.FLOATATOM) catch unreachable;
    keywords.put("msg", TokenType.MESSAGE) catch unreachable;
    keywords.put("connect", TokenType.CONNECT) catch unreachable;
    keywords.put("canvas", TokenType.CANVAS) catch unreachable;
    keywords.put("obj", TokenType.OBJ) catch unreachable;
    keywords.put("else", TokenType.ELSE) catch unreachable;
    keywords.put("if", TokenType.IF) catch unreachable;
    keywords.put("not", TokenType.NOT) catch unreachable;
    keywords.put("or", TokenType.OR) catch unreachable;
    keywords.put("print", TokenType.PRINT) catch unreachable;
    keywords.put("xor", TokenType.XOR) catch unreachable;
    return keywords;
}

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: Literal,
    line: usize,

    pub fn print(self: Token) void {
        switch (self.literal) {
            .void => std.debug.print("{s} ", .{@tagName(self.type)}),
            .int => |value| std.debug.print("({s}: {d}) ", .{ @tagName(self.type), value }),
            .float => |value| std.debug.print("({s}: {d:.2}) ", .{ @tagName(self.type), value }),
            .str => |value| std.debug.print("({s}: {s}) ", .{ @tagName(self.type), value }),
        }
    }
};

