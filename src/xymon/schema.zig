const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub const XTest = struct { testname: []const u8 };

pub const XHostTests = struct { hostname: []const u8, testresults: []XymonResponse };

pub const XymonQueryParams = struct {
    host: ?[]const u8,
    testname: ?[]const u8,
};

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

pub const XymonResponses = struct {
    host: []const u8,
    results: []XymonResponse,
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
    host: ?[]const u8 = "",
    testname: ?[]const u8 = null,
    color: ?Color = null,
    msg: ?[]const u8 = null,
    lifetime: ?[]const u8 = null,

    pub fn parseMessage(self: XymonMessage, alloc: *std.mem.Allocator) ![]u8 {
        var msg: []u8 = "";
        if ((self.host != null) and (self.testname != null)) {
            const h = self.host orelse "";
            const t = self.testname orelse "";
            msg = try std.fmt.allocPrint(alloc.*, "{s} {s}{s}{s} {s} ", .{ self.endpoint.toString(), h, ".", t, "" });
        } else {
            msg = try std.fmt.allocPrint(alloc.*, "{s} {any} {s}{s}", .{ self.endpoint.toString(), self.host, "", "" });
        }

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
