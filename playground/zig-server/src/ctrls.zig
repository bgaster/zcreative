//! 
//! control server
//!

const std = @import("std");
const Allocator = std.mem.Allocator;

const zap = @import("zap");
const WebSockets = zap.WebSockets;

const JSON = @import("json.zig").JSON;

//----------------------------------------------------------------------------------------------------------
// Globals variables...
//----------------------------------------------------------------------------------------------------------

const address: []const u8 = "192.168.1.18:8080";
const port: usize = 8080;

var GlobalContextManager: ContextManager = undefined;

const WebsocketHandler = WebSockets.Handler(Context);

var allocator_g: Allocator = undefined;

//----------------------------------------------------------------------------------------------------------
// Main thread controller
//----------------------------------------------------------------------------------------------------------

// pub fn init(allocator: Allocator) void {
//     GlobalContextManager = ContextManager.init(allocator, "controllers", "user-");
//     defer GlobalContextManager.deinit();
// }

fn help_and_exit(filename: []const u8, err: anyerror) void {
    std.debug.print(
        \\ Error: File `{s}` : {any}
        \\
        \\ To generate both the certificate file and the key file, use the following command:
        \\
        \\ **********************************************************************************************
        \\ openssl req -x509 -nodes -days 365 -sha256 -newkey rsa:2048 -keyout mykey.pem -out mycert.pem
        \\ **********************************************************************************************
        \\
        \\ After that, run this example again
    ,
        .{ filename, err },
    );
    std.process.exit(1);
}

pub fn start(allocator: Allocator) void {
    GlobalContextManager = ContextManager.init(allocator, "controllers", "user-");
    defer GlobalContextManager.deinit();
    allocator_g = allocator;

    const CERT_FILE = "./cert/cert.pem";
    const KEY_FILE = "./cert/key.pem";

    std.fs.cwd().access(CERT_FILE, .{}) catch |err| {
        help_and_exit(CERT_FILE, err);
    };

    std.fs.cwd().access(KEY_FILE, .{}) catch |err| {
        help_and_exit(KEY_FILE, err);
    };

    const tls = zap.Tls.init(.{
        .server_name = "192.168.1.18:8080",
        .public_certificate_file = CERT_FILE,
        .private_key_file = KEY_FILE,
    }) catch return;
    defer tls.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = on_request,
        .on_upgrade = on_upgrade,
        .max_clients = 1000,
        .public_folder = "app",
        .max_body_size = 1 * 1024,
        .tls = tls,
        .log = true,
    });
    listener.listen() catch return;

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}

//----------------------------------------------------------------------------------------------------------
// HTTP stuff
//----------------------------------------------------------------------------------------------------------

fn on_request(r: zap.Request) !void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }
    try r.setHeader("Server", "zcreative controller");
    try r.sendBody("<html><body><h1>zcreative control connect with wss://192.168.1.18:8080</h1></body></html>");
}

fn on_upgrade(r: zap.Request, target_protocol: []const u8) !void {
    // make sure we're talking the right protocol
    if (!std.mem.eql(u8, target_protocol, "websocket")) {
        std.log.warn("received illegal protocol: {s}", .{target_protocol});
        r.setStatus(.bad_request);
        r.sendBody("400 - BAD REQUEST") catch unreachable;
        return;
    }
    var context = GlobalContextManager.newContext() catch |err| {
        std.log.err("Error creating context: {any}", .{err});
        return;
    };

    try WebsocketHandler.upgrade(r.h, &context.settings);
    std.log.info("connection upgrade OK", .{});
}

//----------------------------------------------------------------------------------------------------------
// Contexts
//----------------------------------------------------------------------------------------------------------

const Context = struct {
    userName: []const u8,
    channel: []const u8,
    // we need to hold on to them and just re-use them for every incoming
    // connection
    subscribeArgs: WebsocketHandler.SubscribeArgs,
    settings: WebsocketHandler.WebSocketSettings,
};

const ContextList = std.ArrayList(*Context);

const ContextManager = struct {
    allocator: std.mem.Allocator,
    channel: []const u8,
    usernamePrefix: []const u8,
    lock: std.Thread.Mutex = .{},
    contexts: ContextList = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        channelName: []const u8,
        usernamePrefix: []const u8,
    ) ContextManager {
        return .{
            .allocator = allocator,
            .channel = channelName,
            .usernamePrefix = usernamePrefix,
            .contexts = ContextList.init(allocator),
        };
    }

    pub fn deinit(self: *ContextManager) void {
        for (self.contexts.items) |ctx| {
            self.allocator.free(ctx.userName);
        }
        self.contexts.deinit();
    }

    pub fn newContext(self: *ContextManager) !*Context {
        self.lock.lock();
        defer self.lock.unlock();

        const ctx = try self.allocator.create(Context);
        const userName = try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ self.usernamePrefix, self.contexts.items.len },
        );
        ctx.* = .{
            .userName = userName,
            .channel = self.channel,
            // used in subscribe()
            .subscribeArgs = .{
                .channel = self.channel,
                .force_text = true,
                .context = ctx,
            },
            // used in upgrade()
            .settings = .{
                .on_open = on_open_websocket,
                .on_close = on_close_websocket,
                .on_message = handle_websocket_message,
                .context = ctx,
            },
        };
        try self.contexts.append(ctx);
        return ctx;
    }

    pub fn getContexts(self: *ContextManager) ContextList {
        return self.contexts;
    }
};

//----------------------------------------------------------------------------------------------------------
// Websockets
//----------------------------------------------------------------------------------------------------------

//
// Websocket Callbacks
//
fn on_open_websocket(context: ?*Context, handle: WebSockets.WsHandle) !void {
    if (context) |ctx| {
        _ = try WebsocketHandler.subscribe(handle, &ctx.subscribeArgs);

        var message = std.ArrayList(u8).init(allocator_g);
        const mgw = message.writer();
        var json = try JSON.init(mgw);
        defer json.deinit();

        try json.add_tagged_string("type", "users", mgw);
        try json.begin_array("data", mgw);
        const list = GlobalContextManager.getContexts();
        for (list.items) |item| {
            try json.add_array_element(item.userName, mgw);
        }
        try json.end_array(mgw);
        try json.end(mgw);
        std.debug.print("{s}\n", .{message.items});

        // var message = std.ArrayList(u8).init(allocator_g);
        // const msgw = message.writer();

        // _ = try msgw.write("{ \"type\" : \"users\", ");
        // _ = try msgw.write("\"data\" : [");
        // // const list = GlobalContextManager.getContexts();
        // for (list.items, 0..) |item, i| {
        //     _ = try msgw.write("\"");
        //     _ = try msgw.write(item.userName);
        //     _ = try msgw.write("\"");
        //     if (i != list.items.len-1) {
        //         _ = try msgw.write(",");
        //     }
        // }
        // _ = try msgw.write("] }");

        // send notification to all others
        WebsocketHandler.publish(.{ .channel = ctx.channel, .message = message.items});
        std.log.info("new websocket opened: {s}", .{message.items});
    }
}

fn on_close_websocket(context: ?*Context, uuid: isize) !void {
    _ = uuid;
    if (context) |ctx| {
        // say goodbye
        var buf: [128]u8 = undefined;
        const message = try std.fmt.bufPrint(
            &buf,
            "{s} left the chat.",
            .{ctx.userName},
        );

        // send notification to all others
        WebsocketHandler.publish(.{ .channel = ctx.channel, .message = message });
        std.log.info("websocket closed: {s}", .{message});
    }
}

fn handle_websocket_message(
    context: ?*Context,
    handle: WebSockets.WsHandle,
    message: []const u8,
    is_text: bool,
) !void {
    _ = handle;
    _ = is_text;

    if (context) |ctx| {

        if (message.len != 0) {
            std.debug.print("{s}\n", .{message});
            return;
        }
        // send message
        const buflen = 128; // arbitrary len
        var buf: [buflen]u8 = undefined;

        const format_string = "{s}: {s}";
        const fmt_string_extra_len = 2; // ": " between the two strings
        //
        const max_msg_len = buflen - ctx.userName.len - fmt_string_extra_len;
        if (max_msg_len > 0) {
            // there is space for the message, because the user name + format
            // string extra do not exceed the buffer now, let's check: do we
            // need to trim the message?
            var trimmed_message: []const u8 = message;
            if (message.len > max_msg_len) {
                trimmed_message = message[0..max_msg_len];
            }
            const chat_message = try std.fmt.bufPrint(
                &buf,
                format_string,
                .{ ctx.userName, trimmed_message },
            );

            // send notification to all others
            WebsocketHandler.publish(
                .{ .channel = ctx.channel, .message = chat_message },
            );
            std.log.info("{s}", .{chat_message});
        } else {
            std.log.warn(
                "Username is very long, cannot deal with that size: {d}",
                .{ctx.userName.len},
            );
        }
    }
}

