const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub const Endpoint = enum {
    status,
    xymondboard,
    data,

    pub fn toString(self: Endpoint) []const u8 {
        return switch (self) {
            .status => "status",
            .xymondboard => "xymondboard",
            .data => "data",
        };
    }
};

pub const Color = enum {
    clear,
    green,
    yellow,
    red,
    purple,
    blue,

    pub fn stringToColor(colorStr: []const u8) !Color {
        if (std.mem.eql(u8, colorStr, "clear")) {
            return Color.clear;
        } else if (std.mem.eql(u8, colorStr, "green")) {
            return Color.green;
        } else if (std.mem.eql(u8, colorStr, "yellow")) {
            return Color.yellow;
        } else if (std.mem.eql(u8, colorStr, "red")) {
            return Color.red;
        } else if (std.mem.eql(u8, colorStr, "purple")) {
            return Color.purple;
        } else if (std.mem.eql(u8, colorStr, "blue")) {
            return Color.blue;
        } else {
            return error.UnknownColor;
        }
    }
};

pub const XymonServer = struct {
    host: []const u8,
    port: u16,

    pub fn parseAddress(self: XymonServer) !net.Address {
        const peer = try net.Address.parseIp4(self.host, self.port);
        return peer;
    }
};

// https://xymon.sourceforge.io/xymon/help/manpages/man1/xymon.1.html
pub const XymonResponse = struct {
    host: []const u8,
    testname: []const u8,
    color: []const u8,
    flags: []const u8,
    lastchange: []const u8,
    logtime: []const u8,
    validtime: []const u8,
    acktime: []const u8,
    disabletime: []const u8,
    sender: []const u8,
    cookie: []const u8,
    line1: []const u8,
    ackmsg: []const u8,
    dismsg: []const u8,
    msg: []const u8,

    pub fn parseXResponse(rawResponse: []u8, allocator: *std.mem.Allocator) ![]XymonResponse {
        var responses = std.ArrayList(XymonResponse).init(allocator.*);
        defer responses.deinit(); // Consider ownership if you return this directly

        // Split the raw response into lines
        var lines = std.mem.tokenize(u8, rawResponse, "\n");
        while (lines.next()) |line| {
            var fields = std.mem.tokenize(u8, line, "|");

            // Assuming each line has the correct number of fields
            var response = XymonResponse{
                .host = fields.next() orelse "",
                .testname = fields.next() orelse "",
                // .color = Color.stringToColor(fields.next().?) catch Color.clear, // need to convert to Color
                .color = fields.next() orelse "",
                .flags = fields.next() orelse "",
                .lastchange = fields.next() orelse "",
                .logtime = fields.next() orelse "",
                .validtime = fields.next() orelse "",
                .acktime = fields.next() orelse "",
                .disabletime = fields.next() orelse "",
                .sender = fields.next() orelse "",
                .cookie = fields.next() orelse "",
                .line1 = fields.next() orelse "",
                .ackmsg = fields.next() orelse "",
                .dismsg = fields.next() orelse "",
                .msg = fields.next() orelse "",
            };

            try responses.append(response);
        }

        return responses.toOwnedSlice();
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
        var msg: []u8 = "";
        msg = try std.fmt.allocPrint(alloc.*, "{s} {s}{s}{s} ", .{ self.endpoint.toString(), self.host, "", "" });

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

pub fn send_request(allocator: *std.mem.Allocator, message: XymonMessage, server: XymonServer) ![]XymonResponse {
    const peer = server.parseAddress() catch |err| {
        std.debug.print("Unable to parse host/port! {}\n", .{err});
        std.os.exit(1);
    };

    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    print("Connecting to {}\n", .{peer});

    var data = message.parseMessage(allocator) catch |err| {
        std.debug.print("Unable to parse message! {}\n", .{err});
        std.os.exit(1);
    };

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

    //var resp_alloc = std.heap.page_allocator;
    const xymon_responses = XymonResponse.parseXResponse(response, allocator) catch |err| {
        std.debug.print("Error parsing response: {}\n", .{err});
        return error.ParsingFailed;
    };
    //defer resp_alloc.free(xymon_responses);

    for (xymon_responses) |xresp| {
        std.debug.print("Test: {s}\n", .{xresp.testname});
    }

    return xymon_responses;
}
