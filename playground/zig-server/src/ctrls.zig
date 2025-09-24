//! 
//! control server
//!

const std = @import("std");
const Allocator = std.mem.Allocator;

const zap = @import("zap");
const WebSockets = zap.WebSockets;

const JSON = @import("json.zig").JSON;
const jsonP = @import("json.zig");

const controls = @import("controls.zig");
const osc = @import("osc_message.zig");
const OscSend = @import("osc_send.zig").OscSend;

//----------------------------------------------------------------------------------------------------------
// Globals variables...
//----------------------------------------------------------------------------------------------------------

// const address: []const u8 = "127.0.0.1";
const address: []const u8 = "192.168.1.18";
const address_port = "192.168.1.18:8080";
const port: usize = 8080;
const port_udp = 30338;

var GlobalContextManager: ContextManager = undefined;

var GlobalControls: controls.Controls = undefined;

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

pub fn start(allocator: Allocator, ip: ?[]const u8, control_json: ?[]const u8) !void {

    _ = control_json;

    GlobalContextManager = ContextManager.init(allocator, "zcreative-server", "user-");
    defer GlobalContextManager.deinit();

    // setup out going OSC socket
    var oscsend = OscSend.init(allocator);
    try oscsend.connect(false, "127.0.0.1", port_udp);

    GlobalControls = controls.Controls.init(allocator, oscsend);
    defer GlobalControls.deinit();

    _ = try GlobalControls.add(controls.Slider {
        .name = "slider1",
        .lower = 0,
        .upper = 100,
        .value = 50,
        .increment = 1,
    });

    _ = try GlobalControls.add(controls.Slider {
        .name = "gain",
        .lower = 0,
        .upper = 127,
        .value = 50,
        .increment = 1,
    });
    
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
        // .server_name = "192.168.1.18:8080",
        .server_name = if (ip) |addressp| try Allocator.dupeZ(allocator, u8, addressp) else address_port,
        // .server_name = address_port,
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
    id: u32,
    channel: []const u8,
    // we need to hold on to them and just re-use them for every incoming
    // connection
    subscribeArgs: WebsocketHandler.SubscribeArgs,
    settings: WebsocketHandler.WebSocketSettings,
};

const ContextMap  = std.AutoHashMap(u32, *Context);

const ContextManager = struct {
    allocator: std.mem.Allocator,
    channel: []const u8,
    usernamePrefix: []const u8,
    lock: std.Thread.Mutex = .{},
    contexts: ContextMap = undefined,
    nextUserId: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        channelName: []const u8,
        usernamePrefix: []const u8,
    ) ContextManager {
        return .{
            .allocator = allocator,
            .channel = channelName,
            .usernamePrefix = usernamePrefix,
            .contexts = ContextMap.init(allocator,),
            .nextUserId = 0,
        };
    }

    pub fn deinit(self: *ContextManager) void {
        var iterator = self.contexts.valueIterator();
        while (iterator.next()) |ctx| {
            self.allocator.free(ctx.*.userName);
        }
        self.contexts.deinit();
    }

    fn nextId(self: *ContextManager) u32 {
        defer { self.nextUserId = self.nextUserId + 1; }
        return self.nextUserId;
    }

    pub fn newContext(self: *ContextManager) !*Context {
        self.lock.lock();
        defer self.lock.unlock();

        const ctx = try self.allocator.create(Context);
        const id = self.nextId();
        const userName = try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ self.usernamePrefix, id },
        );
        ctx.* = .{
            .userName = userName,
            .id = id,
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
        try self.contexts.put(id, ctx);
        return ctx;
    }

    pub fn removeContext(self: *ContextManager, context: *Context) void {
       _ = self.contexts.remove(context.id); 
    }

    pub fn getContexts(self: *ContextManager) ContextMap {
        return self.contexts;
    }
};

//----------------------------------------------------------------------------------------------------------
// Websockets
//----------------------------------------------------------------------------------------------------------

fn set_slider(context: *Context, id: i64, value: i64) !void {
    _ = context;

    const uid: usize = @intCast(id);
    _ = GlobalControls.update_slider(uid, value);

    // now send the update via OSC
    _ = try GlobalControls.send("test_osc", uid);

    // var message: std.ArrayList(u8) = .empty;
    // const mgw = message.writer(allocator_g);

    const buflen = 1024; 
    var buf: [buflen]u8 = undefined;
    const message = try std.fmt.bufPrint(
        &buf,
        "{c} \"type\": \"control\", \"header\": {d}, \"values\": [{d}] {c}",
        .{'{', id, value, '}' },
    );

    std.log.info("sent control {s}\n", .{message});


    const map = GlobalContextManager.getContexts();
    var iterator = map.valueIterator();
    while (iterator.next()) |entry| {
        // TODO: don't send to updater
        WebsocketHandler.publish(.{ .channel = entry.*.channel, .message = message, .is_json = true});
    }
}

fn send_controls(context: *Context) !void {
    const obj = try jsonP.createObject(allocator_g); 
    defer obj.deinit(allocator_g);

    try jsonP.objectPut(allocator_g, obj, "type", try jsonP.createString(allocator_g, "controls"));

    const jsonArray = try jsonP.beginArray(allocator_g);

    var message: std.ArrayList(u8) = .empty;
    const mgw = message.writer(allocator_g);

    // sliders 
    for (GlobalControls.sliders.items, 0..) |slider, id| {
        // controller object
        const objControl = try jsonP.createObject(allocator_g); 

        // basic fields for controller
        try jsonP.objectPut(allocator_g, objControl, "type", try jsonP.createInteger(allocator_g, controls.SLIDER_TYPE));
        try jsonP.objectPut(allocator_g, objControl, "id", try jsonP.createInteger(allocator_g, @intCast(id)));
        try jsonP.objectPut(allocator_g, objControl, "name", try jsonP.createString(allocator_g, slider.name));
        
        // controller values
        const jsonValuesArray = try jsonP.beginArray(allocator_g);
        try jsonP.arrayAppend(allocator_g, jsonValuesArray, try jsonP.createInteger(allocator_g, slider.lower));
        try jsonP.arrayAppend(allocator_g, jsonValuesArray, try jsonP.createInteger(allocator_g, slider.upper));
        try jsonP.arrayAppend(allocator_g, jsonValuesArray, try jsonP.createInteger(allocator_g, slider.value));
        try jsonP.arrayAppend(allocator_g, jsonValuesArray, try jsonP.createInteger(allocator_g, slider.increment));
        try jsonP.objectPut(allocator_g, objControl, "values", try jsonP.createFromArray(allocator_g, jsonValuesArray));

        try jsonP.arrayAppend(allocator_g, jsonArray, try jsonP.createFromObject(allocator_g, objControl));
    }

    // TODO: add other controller types, e.g. Buttons.

    try jsonP.objectPut(allocator_g, obj, "data", try jsonP.createFromArray(allocator_g, jsonArray));

    try obj.toString(mgw);
    std.log.info("sent controls {s}\n", .{message.items});

    WebsocketHandler.publish(.{ .channel = context.channel, .message = message.items, .is_json = true});
}


fn broadcast_names(context: ?*Context) !void {
    const obj = try jsonP.createObject(allocator_g); 
    defer obj.deinit(allocator_g);

    try jsonP.objectPut(allocator_g, obj, "type", try jsonP.createString(allocator_g, "users"));

    const jsonArray = try jsonP.beginArray(allocator_g);

    var message: std.ArrayList(u8) = .empty;
    const mgw = message.writer(allocator_g);
    const map = GlobalContextManager.getContexts();

    var iterator = map.valueIterator();

    while (iterator.next()) |entry| {
        try jsonP.arrayAppend(allocator_g, jsonArray, try jsonP.createString(allocator_g, entry.*.userName));
    }

    try jsonP.objectPut(allocator_g, obj, "data", try jsonP.endArray(allocator_g, jsonArray));
    try obj.toString(mgw);

    std.log.info("sent users {s}\n", .{message.items});

    iterator = map.valueIterator();
    while (iterator.next()) |entry| {
        WebsocketHandler.publish(.{ .channel = entry.*.channel, .message = message.items, .is_json = true});
    }

    if (context != null) {

    }
    // WebsocketHandler.publish(.{ .channel = context.channel, .message = message.items});
}

//
// Websocket Callbacks
//
fn on_open_websocket(context: ?*Context, handle: WebSockets.WsHandle) !void {
    if (context) |ctx| {
        _ = try WebsocketHandler.subscribe(handle, &ctx.subscribeArgs);

        try broadcast_names(ctx);

        // send notification to all others
        std.log.info("new websocket opened", .{});
    }
}

fn on_close_websocket(context: ?*Context, uuid: isize) !void {
    _ = uuid;
    if (context) |ctx| {
        var buf: [128]u8 = undefined;
        const message = try std.fmt.bufPrint(
            &buf,
            "{s} left.",
            .{ctx.userName},
        );

        GlobalContextManager.removeContext(ctx);

        // send update user list to all others
        try broadcast_names(null);

        std.log.info("websocket closed: {s}", .{message});
    }
    std.log.info("websocket closed", .{});
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

        if (message.len == 0) {
            std.debug.print("{s}\n", .{message});
            return;
        }

        std.log.info("received: {s}\n", .{message});
        const msg_json = try jsonP.parseJson5(message, allocator_g); 

        if (msg_json.objectOrNull()) |obj| {
            if (obj.getOrNull("type")) |ty| {
                if (ty.stringOrNull()) |str| {
                    if (std.mem.eql(u8, str, "get_controls")) {
                        try send_controls(ctx);
                    }
                    else if (std.mem.eql(u8, str, "control")) {
                        if (obj.contains("header") and obj.contains("uid") and obj.contains("values")) {
                            const header = obj.get("header");
                            const uid    = obj.get("uid");
                            const values = obj.get("values");

                            if (header.type == .integer and uid.type == .integer and values.type == .array) {
                                // handle sliders
                                if (header.integer() == controls.SLIDER_TYPE) {
                                    if (values.array().getOrNull(0)) |value| {
                                        if (value.type == .integer) {
                                            try set_slider(ctx, uid.integer(), value.integer());
                                        }
                                    }
                                }

                                // TODO: handle other controller types, e.g. buttons
                            }
                        }
                    }
                }
            }
        }

        // send message
        // const buflen = 128; // arbitrary len
        // var buf: [buflen]u8 = undefined;
        //
        // const format_string = "{s}: {s}";
        // const fmt_string_extra_len = 2; // ": " between the two strings
        // //
        // const max_msg_len = buflen - ctx.userName.len - fmt_string_extra_len;
        // if (max_msg_len > 0) {
        //     // there is space for the message, because the user name + format
        //     // string extra do not exceed the buffer now, let's check: do we
        //     // need to trim the message?
        //     var trimmed_message: []const u8 = message;
        //     if (message.len > max_msg_len) {
        //         trimmed_message = message[0..max_msg_len];
        //     }
        //     const chat_message = try std.fmt.bufPrint(
        //         &buf,
        //         format_string,
        //         .{ ctx.userName, trimmed_message },
        //     );
        //
        //     // send notification to all others
        //     WebsocketHandler.publish(
        //         .{ .channel = ctx.channel, .message = chat_message },
        //     );
        //     std.log.info("{s}", .{chat_message});
        // } else {
        //     std.log.warn(
        //         "Username is very long, cannot deal with that size: {d}",
        //         .{ctx.userName.len},
        //     );
        // }
    }
}

