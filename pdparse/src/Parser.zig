const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const errorMsgs = @import("error.zig");
const token = @import("token.zig");
const Token = token.Token;
const Literal = token.Literal;
const TokenType = token.TokenType;

const patch = @import("patch.zig");
const Root = patch.Root;
const Patch = patch.Patch;
const Layout = patch.Layout;
const Node = patch.Node;
const ArgType = patch.ArgType;
const Arg = patch.Arg;

pub const ParserOptions = struct {
    allocator: std.mem.Allocator,
    diagnostic: ?*errorMsgs.Diagnostic = null,
};

pub const Parser = @This();

const Self = @This();

allocator: std.mem.Allocator,
diagnostic: ?*errorMsgs.Diagnostic = null,

current_id: u32,

tokens: std.ArrayList(Token),
next_token: u32,

pub fn init(allocator: Allocator, tokens: std.ArrayList(Token), options: ParserOptions) !*Self {
    const self = try allocator.create(Self);
    self.* = Self{
        .allocator = options.allocator, 
        .diagnostic = options.diagnostic, 
        .current_id = 0,
        .tokens = tokens, 
        .next_token = 0,
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.allocator.destroy(self);
}

fn end_of_tokens(self: *Self) bool {
    return self.next_token == self.tokens.items.len;
}

fn match(self: *Self, tok: TokenType) errorMsgs.Error!Token {
    if (!self.end_of_tokens() and self.tokens.items[self.next_token].type == tok) {
        self.next_token = self.next_token + 1;
        return self.tokens.items[self.next_token-1];
    }
    return error.NoMatch;
}

fn match_peek(self: *Self, tok: TokenType) bool {
    if (!self.end_of_tokens() and self.tokens.items[self.next_token].type == tok) {
        return true;
    }
    return false;
}

pub fn next_id(self: *Self) u32 {
    self.current_id = self.current_id + 1;
    return self.current_id;
}

pub fn parse_toplevel(self: *Self) (errorMsgs.Error || error{OutOfMemory})!Root {
    var root = Root.init(self.allocator, self.current_id);

    // to avoid space leak need to catch any error and 
    // deallocate, before returning.
    if (self.handle_toplevel(&root)) |_| {
        return root;
    }
    else |err| {
        root.deinit();
        return err;
    }

    return root;
}

fn handle_toplevel(self: *Self, root: *Root) (errorMsgs.Error || error{OutOfMemory})!void {
    // consume patches
    while (!self.match_peek(TokenType.EOF)) {
        var p = Patch.init(self.allocator, self.current_id, 0, 0, 0, 0);
        try root.patches.append(p);
        try self.parse_patch(&p, root);
    }
}

pub fn parse_int(self: *Self) errorMsgs.Error!u32 {
    const i = try self.match(TokenType.INT);

    const lit = i.literal;

    return switch(lit) {
        .int => |v| @as(u32, @intCast(v)),
        else => errorMsgs.Error.InvalidLiteral,
    };
}

fn to_arg(literal: Literal) Arg {
    return switch (literal) {
        .void => .tempty,
        .int => |value| .{ .tint = @as(i32, @intCast(value)) },
        .float => |value| .{ .tfloat = @as(f32, @floatCast(value)) },
        .str => |value|  .{ .tstring = value }
    };
}

pub fn parse_arg(self: *Self) errorMsgs.Error!Arg {
    if (self.match_peek(TokenType.INT)) {
        const l = try self.match(TokenType.INT);
        return to_arg(l.literal);
    }
    else if (self.match_peek(TokenType.FLOAT)) {
        const f = try self.match(TokenType.FLOAT);
        return to_arg(f.literal);
    }
    else if (self.match_peek(TokenType.IDENTIFIER)) {
        const s = try self.match(TokenType.IDENTIFIER);
        return to_arg(s.literal);
    }

    return errorMsgs.Error.InvalidArg; 
}

pub fn parse_patch(self: *Self, p: *Patch, root: *Root) !void {
    _ = try self.match(TokenType.HASH_N);
    _ = try self.match(TokenType.CANVAS);

    p.layout.x = try self.parse_int();
    p.layout.y = try self.parse_int();
    p.layout.width = try self.parse_int();
    p.layout.height = try self.parse_int();

    _ = try self.parse_int(); // FIXME: what is this one?

    _ = try self.match(TokenType.SEMICOLON);

    // now nodes
    
    while (self.match_peek(TokenType.HASH_N) or self.match_peek(TokenType.HASH_X)) {
        // subpatch
        if (self.match_peek(TokenType.HASH_N)) {
            var subp = Patch.init(self.allocator, self.next_id(), 0, 0, 0, 0);
            try root.patches.append(subp);
            try self.parse_patch(&subp, root);
        }
        else {
            _ = try self.match(TokenType.HASH_X);
            // message
            if (self.match_peek(TokenType.MESSAGE)) {
                _ = try self.match(TokenType.MESSAGE);
                const x = try self.parse_int();
                const y = try self.parse_int();
                const arg = try self.parse_arg();

                _ = &x;
                _ = &y;
                _ = &arg;

                _ = try self.match(TokenType.SEMICOLON);
            }
            // object
            else if (self.match_peek(TokenType.OBJ)) {

            }
        }

    }

    // now connectors
    
    // handle closing subpatches
    if (p.id != 0) {

    }
}

pub fn parse_node(self: *Self) !Node {
    _ = try self.match(TokenType.HASH_X);
}
