const std = @import("std");
const Allocator = std.mem.Allocator;
const network = @import("network");

const OscMessage = @import("osc_message.zig").OscMessage;

pub const OscSend = struct {
    const Self = @This();

    allocator: Allocator,
    address: network.Address = undefined,
    socket: network.Socket = undefined,
    send_to_endpoint: network.EndPoint = undefined,

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .address = undefined,
            .socket = undefined,
            .send_to_endpoint = undefined,
        };
    }

    pub fn connect(self: *Self, broadcast: bool, send_to_address: []const u8, port: u16) !void {
        self.address = network.Address{ .ipv4 = network.Address.IPv4.any };

        self.socket = try network.Socket.create(.ipv4, .udp);
        try self.socket.setBroadcast(broadcast);

        const bind_address = network.EndPoint{
            .address = network.Address{ .ipv4 = network.Address.IPv4.any },
            .port = 0,
        };

        self.send_to_endpoint = network.EndPoint{
            .address = network.Address{ .ipv4 = try network.Address.IPv4.parse(send_to_address) },
            .port = port,
        };
        try self.socket.bind(bind_address);
    }

    pub fn close(self: *Self) void {
        self.socket.close();
    }

    pub fn send(self: *Self, osc_message: OscMessage) !void {
        const buffer = try osc_message.encode(self.allocator);
        _ = try self.socket.sendTo(self.send_to_endpoint, buffer);
    }
};

