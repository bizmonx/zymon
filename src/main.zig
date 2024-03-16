const std = @import("std");
const zap = @import("zap");
const Mustache = @import("zap").Mustache;
pub const xymon = @import("xymon/xymon.zig");

var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;

fn dispatch_routes(r: zap.Request) void {
    // dispatch
    if (r.path) |the_path| {
        if (routes.get(the_path)) |foo| {
            foo(r);
            return;
        }
    }
    // or default: present menu
    r.sendBody(
        \\ <html>
        \\   <body>
        \\     <p><a href="/static">static</a></p>
        \\     <p><a href="/dynamic">dynamic</a></p>
        \\   </body>
        \\ </html>
    ) catch return;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.HttpRequestFn).init(a);
    try routes.put("/", get_home);
    try routes.put("/xymon", send_xymon);
}

// straight from the zap examples, keeping it for ref for now
fn get_users(r: zap.Request) void {
    var mustache = Mustache.fromFile("view/users.html") catch return;
    defer mustache.deinit();

    const User = struct {
        name: []const u8,
        id: isize,
    };

    const ret = mustache.build(.{
        .users = [_]User{
            .{
                .name = "Rene",
                .id = 1,
            },
            .{
                .name = "Caro",
                .id = 6,
            },
        },
        .nested = .{
            .item = "nesting works",
        },
    });
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

fn get_home(r: zap.Request) void {
    var mustache = Mustache.fromFile("view/index.html") catch return;
    defer mustache.deinit();

    const ret = mustache.build(.{});
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

fn send_xymon(r: zap.Request) void {
    const xymon_env_hostname = "XYMON_HOST";
    const xymon_env_port = "XYMON_PORT";

    // Attempt to read the first environment variable
    const xymon_host = std.os.getenv(xymon_env_hostname) orelse {
        std.debug.print("Environment variable '{s}' not found.\n", .{xymon_env_hostname});
        return;
    };

    // Attempt to read the second environment variable
    const xymon_port_str = std.os.getenv(xymon_env_port) orelse {
        std.debug.print("Environment variable '{s}' not found.\n", .{xymon_env_port});
        return;
    };

    const xymon_port = std.fmt.parseInt(u16, xymon_port_str, 10) catch {
        std.debug.print("Failed to parse '{d}' as u32.\n", .{xymon_port_str});
        return;
    };

    // Print the values of the environment variables
    std.debug.print("Value of {s} is '{s}'\n", .{ xymon_env_hostname, xymon_host });
    std.debug.print("Value of {s} is '{d}'\n", .{ xymon_env_port, xymon_port });

    var mustache = Mustache.fromFile("view/hoststatus.html") catch return;
    defer mustache.deinit();
    var allocator = std.heap.page_allocator; // General-purpose allocator

    var server = xymon.XymonServer{
        .host = xymon_host,
        .port = xymon_port,
    };

    const message = xymon.XymonMessage{ .endpoint = xymon.Endpoint.xymondboard, .host = "7b5d6e9c4ad9", .testname = "zig" };

    const resp = xymon.send_request(&allocator, message, server) catch return;
    defer allocator.free(resp);

    const ret = mustache.build(.{ .responses = resp });

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

pub fn main() !void {
    try setup_routes(std.heap.page_allocator);
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
        .public_folder = "public",
        .log = true,
    });
    try listener.listen();

    // zap.enableDebugLog();
    // zap.debug("ZAP debug logging is on\n", .{});

    // // we can also use facilio logging
    // zap.Log.fio_set_log_level(zap.Log.fio_log_level_debug);
    // zap.Log.fio_log_debug("hello from fio\n");

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
