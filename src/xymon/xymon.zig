const schema = @import("schema.zig");
const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub fn send_request(allocator: *std.mem.Allocator, message: schema.XymonMessage, server: schema.XymonServer) ![]schema.XymonResponse {
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
    const xymon_responses = schema.XymonResponse.parseXResponse(response, allocator) catch |err| {
        std.debug.print("Error parsing response: {}\n", .{err});
        return error.ParsingFailed;
    };

    // for (xymon_responses) |xresp| {
    //     std.debug.print("Test: {s}\n", .{xresp.testname});
    // }

    return xymon_responses;
}
