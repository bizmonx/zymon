const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub const Endpoint = enum {
    status,
    xymondboard,
    data,
};

pub const Color = enum {
    clear,
    green,
    yellow,
    red,
    purple,
    blue,
};

pub const XymonServer = struct {
    host: []const u8,
    port: u16,

    pub fn parseAddress(self: XymonServer) !net.Address {
        const peer = try net.Address.parseIp4(self.host, self.port);
        return peer;
    }
};

pub const XymonMessage = struct {
    endpoint: Endpoint,
    host: []const u8,
    testname: []const u8,
    color: ?Color = null,
    msg: ?[]const u8 = null,
    lifetime: ?[]const u8 = null,

    pub fn parseMessage(self: XymonMessage, alloc: *std.mem.Allocator) ![]u8 {
        const dot = if (std.mem.eql(u8, self.testname, "")) "" else ".";
        //const plus = if (self.lifetime == null) "" else "+";
        //var alloc = std.heap.page_allocator;

        var msg: []u8 = "";
        //defer alloc.free(msg);
        msg = try std.fmt.allocPrint(alloc.*, "{any} {s}{s}{s} ", .{ self.endpoint, self.host, dot, self.testname });

        // switch (self.endpoint) {
        //     Endpoint.xymondboard => {
        //         msg = try std.fmt.allocPrint(alloc, "{s} {?}{?}{?} ", .{ self.endpoint, self.host, dot, self.testname });
        //     },
        //     Endpoint.data => {},
        //     Endpoint.status => {
        //         msg = try std.fmt.allocPrint(alloc, "{s}{?}{?} {?}{?}{?} {?} {?} ", .{ self.endpoint, plus, self.lifetime, self.host, dot, self.testname, self.color, self.testname });
        //     },
        // }

        return msg;
    }
};

pub fn send_request(allocator: *std.mem.Allocator, message: XymonMessage, server: XymonServer) ![]u8 {
    //const port = 1985;
    //const peer = try net.Address.parseIp4("127.0.0.1", port);
    const peer = server.parseAddress() catch |err| {
        std.debug.print("Unable to parse host/port! {}\n", .{err});
        std.os.exit(1);
    };

    // Connect to peer
    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    print("Connecting to {}\n", .{peer});

    // Sending data to peer
    // const data = "xymondboard 7b5d6e9c4ad9.http";
    var alloc = std.heap.page_allocator;

    const data = message.parseMessage(&alloc) catch |err| {
        std.debug.print("Unable to parse message! {}\n", .{err});
        std.os.exit(1);
    };
    defer alloc.free(data);

    var writer = stream.writer();
    const size = try writer.write(data);
    print("Sending '{s}' to peer, total written: {d} bytes\n", .{ data, size });

    // need to tell xymon no more data is following by sending "shutdown" (SHUT_WR = 1)
    _ = try std.os.shutdown(stream.handle, std.os.ShutdownHow.send);

    // Read the response
    var buffer = try allocator.alloc(u8, 4096); // Adjust buffer size as needed

    //var reader = stream.reader();
    const bytesRead = try stream.read(buffer[0..]);
    const response = buffer[0..bytesRead];

    // Print the response to stdout and return
    std.debug.print("Received: {s}\n", .{response});
    return response;
}
