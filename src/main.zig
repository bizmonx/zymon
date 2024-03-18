const std = @import("std");
const zap = @import("zap");
const Mustache = @import("zap").Mustache;
const xschema = @import("xymon/schema.zig");
const render = @import("view/render.zig");
pub const xymon = @import("xymon/xymon.zig");

// pub const XTest = struct { testname: []const u8 };

// pub const XHostTests = struct { hostname: []const u8, testresults: []xschema.XymonResponse };

var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;

fn dispatch_routes(r: zap.Request) void {
    // dispatch
    if (r.path) |rt| {
        if (routes.get(rt)) |route| {
            route(r);
            return;
        }
    }
    // or default: present fallback
    r.sendBody(
        \\ <html>
        \\   <body>
        \\     <p>This is not the page you are looking for...</p>
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

fn readFileToString(allocator: *std.mem.Allocator, path: []const u8) []u8 {
    // Attempt to open the file, return an empty string on failure
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open file: {}\n", .{err});
        return &[_]u8{};
    };
    defer file.close();

    // Attempt to read the file, return an empty string on failure
    const fileSize = file.getEndPos() catch |err| {
        std.debug.print("Failed to get file size: {}\n", .{err});
        return &[_]u8{};
    };

    var buffer = allocator.alloc(u8, fileSize) catch |err| {
        std.debug.print("Failed to allocate buffer: {}\n", .{err});
        return &[_]u8{};
    };
    //defer allocator.free(buffer);

    // Attempt to read the file into the buffer
    _ = file.read(buffer) catch |err| {
        std.debug.print("Failed to read file: {}\n", .{err});
        return &[_]u8{};
    };

    return buffer;
}

fn get_home(r: zap.Request) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    const navbarTemplate = readFileToString(&allocator, "view/components/navbar/index.html");

    defer allocator.free(navbarTemplate);

    var mustache = Mustache.fromFile("view/layout/index.html") catch return;
    defer mustache.deinit();

    const ret = mustache.build(.{ .navbar = navbarTemplate });
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

fn init_xymon() xschema.XymonServer {
    const xymon_env_hostname = "XYMON_HOST";
    const xymon_env_port = "XYMON_PORT";
    // Attempt to read the first environment variable
    const xymon_host = std.os.getenv(xymon_env_hostname) orelse "127.0.0.1";

    // Attempt to read the second environment variable
    const xymon_port_str = std.os.getenv(xymon_env_port) orelse "1984";

    var xymon_port: u16 = 1984;
    var p = std.fmt.parseInt(u16, xymon_port_str, 10);
    if (p) |val| {
        xymon_port = val;
    } else |err| {
        std.debug.print("err parsing xymon port: {}\n", .{err});
    }

    // Print the values of the environment variables
    std.debug.print("Value of {s} is '{s}'\n", .{ xymon_env_hostname, xymon_host });
    std.debug.print("Value of {s} is '{d}'\n", .{ xymon_env_port, xymon_port });

    var server = xschema.XymonServer{
        .host = xymon_host,
        .port = xymon_port,
    };

    return server;
}

fn send_xymon(r: zap.Request) void {
    const query = (r.query);
    //var queryParams = xschema.XymonQueryParams{ .host = null, .testname = null };
    var message = xschema.XymonMessage{ .endpoint = xschema.Endpoint.xymondboard };
    if (query) |q| {
        std.debug.print("query from request: {s}\n", .{q});
        var it = std.mem.tokenize(u8, q, "&");
        while (it.next()) |kv| {
            var parts = std.mem.split(u8, kv, "=");
            const key = parts.next().?;
            const value = parts.next().?;

            if (std.mem.eql(u8, key, "host")) {
                message.host = value;
            } else if (std.mem.eql(u8, key, "testname")) {
                message.testname = value;
            } else {
                // Handle unexpected keys or ignore
            }
        }
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    // const message = xschema.XymonMessage{ .endpoint = xschema.Endpoint.xymondboard, .host = "7b5d6e9c4ad9", .testname = "zig" };
    const server = init_xymon();

    var resp = xymon.send_request(&allocator, message, server) catch return;
    defer allocator.free(resp);

    var hostMap = std.StringHashMap(std.ArrayList(xschema.XymonResponse)).init(allocator);

    for (resp) |response| {
        var v = hostMap.getOrPut(response.host) catch |err| {
            std.debug.print("err: {}\n", .{err});
            return;
        };
        if (!v.found_existing) {
            var valueMap = std.ArrayList(xschema.XymonResponse).init(allocator);
            v.value_ptr.* = valueMap;

            var n = valueMap.append(response);
            if (n) |value| {
                std.debug.print("cool! {}\n", .{value});
            } else |err| {
                std.debug.print("err: {}\n", .{err});
            }
        }
        var n = v.value_ptr.*.append(response);
        if (n) |value| {
            _ = value;
        } else |err| {
            std.debug.print("err: {}\n", .{err});
        }
    }

    var hostresults = allocator.alloc(xschema.XHostTests, 1) catch |err| {
        std.debug.print("err: {}\n", .{err});
        std.os.exit(1);
    };
    defer allocator.free(hostresults);
    var h_iter = hostMap.iterator();
    var idx: usize = 0;
    while (h_iter.next()) |r_item| {
        std.debug.print("from the last iter: {s}\n", .{r_item.key_ptr.*});
        // var testr = r_item.value_ptr.*.items;
        // for (testr) |vk| {
        //     std.debug.print("rrrrr: {s}\n", .{vk.color});
        // }

        hostresults[idx] = xschema.XHostTests{
            .hostname = r_item.key_ptr.*,
            .testresults = r_item.value_ptr.*.items,
        };
        idx += 1;
    }
    if (message.testname) |t| {
        std.debug.print("we got testname ### {s} ###\n", .{t});
        render.renderTest(&allocator, hostresults, resp, r);
    } else {
        render.renderHost(&allocator, hostresults, resp, r);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    try setup_routes(gpa.allocator());
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
