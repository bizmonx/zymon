const std = @import("std");

const zap = @import("zap");
const Mustache = @import("zap").Mustache;
const xschema = @import("../xymon/schema.zig");
pub const xymon = @import("../xymon/xymon.zig");

const Color = enum(u8) {
    unknown = 0,
    clear = 1,
    green = 2,
    purple = 3,
    yellow = 4,
    red = 5,

    // A helper function within the enum to determine the max color based on priority
    fn max(a: Color, b: Color) Color {
        if (@intFromEnum(a) > @intFromEnum(b)) return a;
        return b;
    }

    fn maxString(a: *[]const u8, b: []const u8) void {
        var colA = parseColor(a.*);
        var colB = parseColor(b);

        a.* = colorToString(max(colA, colB));
    }

    pub fn parseColor(value: []const u8) Color {
        if (std.mem.eql(u8, value, "clear")) {
            return Color.clear;
        } else if (std.mem.eql(u8, value, "purple")) {
            return Color.purple;
        } else if (std.mem.eql(u8, value, "green")) {
            return Color.green;
        } else if (std.mem.eql(u8, value, "yellow")) {
            return Color.yellow;
        } else if (std.mem.eql(u8, value, "red")) {
            return Color.red;
        } else {
            return Color.unknown; // Use this if the string doesn't match any known color
        }
    }

    fn colorToString(color: Color) []const u8 {
        return switch (color) {
            .clear => "clear",
            .purple => "purple",
            .green => "green",
            .yellow => "yellow",
            .red => "red",
            .unknown => "unknown",
        };
    }
};

pub fn renderTest(allocator: *std.mem.Allocator, hostresults: []xschema.XHostTests, resp: []xschema.XymonResponse, r: zap.Request) void {
    _ = resp;
    _ = allocator;
    var mustache = Mustache.fromFile("view/components/status/test.html") catch return;
    defer mustache.deinit();

    const ret = mustache.build(.{ .host = hostresults[0].hostname, .testname = hostresults[0].testresults[0].testname, .msg = hostresults[0].testresults[0].msg });

    defer ret.deinit();

    if (r.setContentType(.HTML)) {
        if (ret.str()) |s| {
            r.sendBody(s) catch return;
        } else {
            r.sendBody("<html><body><h1>mustacheBuild() failed!</h1></body></html>") catch return;
        }
    } else |err| {
        std.debug.print("Error while setting content type: {}\n", .{err});
    }
}

fn contains(list: std.ArrayList(xschema.XTest), testname: []const u8) bool {
    for (list.items) |item| {
        if (std.mem.eql(u8, item.testname, testname)) {
            return true;
        }
    }
    return false;
}

fn test_with_name_or_default(list: []xschema.XymonResponse, testname: []const u8) ?xschema.XymonResponse {
    for (list) |item| {
        if (std.mem.eql(u8, item.testname, testname)) {
            return item;
        }
    }
    return null;
}

// compare function signature requires a first void param
fn XTestCmp(_: void, a: xschema.XTest, b: xschema.XTest) bool {
    return std.mem.lessThan(u8, a.testname, b.testname);
}

fn XHostResultsCmp(_: void, a: xschema.XNormalized, b: xschema.XNormalized) bool {
    return std.mem.lessThan(u8, a.hostname, b.hostname);
}

// TODO: for now, this renders hosts, need to manage different kinds of groups and pages
pub fn renderHost(allocator: std.mem.Allocator, hostresults: []xschema.XHostTests, resp: []xschema.XymonResponse, r: zap.Request) void {
    var mustache = Mustache.fromFile("view/components/status/host.html") catch return;
    defer mustache.deinit();
    var testnames = std.ArrayList(xschema.XTest).init(allocator);

    for (resp) |item| {
        if (contains(testnames, item.testname)) {
            // std.debug.print("list already contains the test {s}\n", .{item.testname});
        } else {
            testnames.append(xschema.XTest{ .testname = item.testname }) catch |err| {
                std.debug.print("error occured here in appending to testnames: {}\n", .{err});
            };
        }
    }
    var nhostresults = std.ArrayList(xschema.XNormalized).init(allocator);

    for (hostresults) |hres| {
        var tempresults = std.ArrayList(xschema.NormalizedResponse).init(allocator);

        std.mem.sort(xschema.XTest, testnames.items, {}, XTestCmp);
        for (testnames.items) |testitem| {
            var d = test_with_name_or_default(hres.testresults, testitem.testname);
            var nr = xschema.NormalizedResponse.new(
                allocator,
                hres.hostname,
                testitem.testname,
                if (d) |testE| testE.color else null,
                if (d) |testE| testE.msg else "",
            );
            if (nr) |nresp| {
                tempresults.append(nresp) catch return;
            } else |err| {
                std.debug.print("an unexpected host test normalizing error has occured {s}\n", .{err});
            }
        }
        var nresults = xschema.XNormalized{
            .hostname = hres.hostname,
            .testresults = tempresults.items,
        };
        nhostresults.append(nresults) catch return;
    }

    std.mem.sort(xschema.XNormalized, nhostresults.items, {}, XHostResultsCmp);
    var endColor: []u8 = undefined;

    for (nhostresults.items) |nres| {
        for (nres.testresults) |nitem| {
            Color.maxString(&endColor, nitem.color);
            // std.debug.print("-> item: {s}\n", .{nitem.testname});
            // std.debug.print("---> color: {s}\n", .{nitem.color});
            // std.debug.print("---> icon: {s}\n", .{nitem.icon});
        }
    }
    const ret = mustache.build(.{ .responses = nhostresults.items, .columns = testnames.items });

    defer ret.deinit();

    if (r.setContentType(.HTML)) {
        if (ret.str()) |s| {
            //r.sendBody(s) catch return;
            var allBody = std.fmt.allocPrint(allocator, "<div hx-swap-oob=\"true\" id=\"endcolor\">{s}</div>\n{s}", .{ endColor, s }) catch "";
            r.sendBody(allBody) catch return;
        } else {
            r.sendBody("<html><body><h1>mustacheBuild() failed!</h1></body></html>") catch return;
        }
    } else |err| {
        std.debug.print("Error while setting content type: {}\n", .{err});
    }
}
