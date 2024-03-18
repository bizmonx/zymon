const std = @import("std");

const zap = @import("zap");
const Mustache = @import("zap").Mustache;
const xschema = @import("../xymon/schema.zig");
pub const xymon = @import("../xymon/xymon.zig");

// pub fn parseTests(allocator: *std.mem.Allocator, resp: xschema.XymonResponse) []xschema.XTest {
//     var testnames = allocator.alloc(xschema.XTest, 16) catch |err| {
//         std.debug.print("err: {}\n", .{err});
//         std.os.exit(1);
//     };

//     defer allocator.free(testnames);

//     for (resp, 0..) |item, i| {
//         std.debug.print("item from resp: {any}\n", .{item});
//         testnames[i] = xschema.XTest{ .testname = item.testname };
//     }

//     return testnames;
// }

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

pub fn renderHost(allocator: *std.mem.Allocator, hostresults: []xschema.XHostTests, resp: []xschema.XymonResponse, r: zap.Request) void {
    var mustache = Mustache.fromFile("view/components/status/host.html") catch return;
    defer mustache.deinit();

    var testnames = allocator.alloc(xschema.XTest, 16) catch |err| {
        std.debug.print("err: {}\n", .{err});
        std.os.exit(1);
    };

    defer allocator.free(testnames);

    for (resp, 0..) |item, i| {
        std.debug.print("item from resp: {any}\n", .{item});
        testnames[i] = xschema.XTest{ .testname = item.testname };
    }
    const ret = mustache.build(.{ .responses = hostresults, .columns = testnames });

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
