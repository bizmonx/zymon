const std = @import("std");
const net = std.net;
const print = std.debug.print;

pub const XHost = struct {
    ip: []u8,
    name: []u8,
};

pub const XGroup = struct {
    title: []u8,
    hosts: []XHost,
};

pub const Page = struct {
    name: []u8,
    description: []u8,
    subpages: []Page,
    groups: []XGroup,
    hosts: []XHost,
};

pub const HostsLayout = struct {
    host: ?[]const u8,
    testname: ?[]const u8,
};

pub fn loadhosts(allocator: std.mem.Allocator) void {
    _ = allocator;
}
