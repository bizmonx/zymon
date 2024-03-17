const std = @import("std");
const zap = @import("zap");
const Mustache = @import("zap").Mustache;
const xschema = @import("xymon/schema.zig");
pub const xymon = @import("xymon/xymon.zig");

var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;

pub const XTest = struct { testname: []const u8 };

fn dispatch_routes(r: zap.Request) void {
    // dispatch
    if (r.path) |the_path| {
        if (routes.get(the_path)) |route| {
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

    var mustache = Mustache.fromFile("view/components/status/index.html") catch return;
    defer mustache.deinit();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator(); // General-purpose allocator

    var server = xschema.XymonServer{
        .host = xymon_host,
        .port = xymon_port,
    };

    const message = xschema.XymonMessage{ .endpoint = xschema.Endpoint.xymondboard, .host = "7b5d6e9c4ad9", .testname = "zig" };

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
            std.debug.print("cool! {}\n", .{value});
        } else |err| {
            std.debug.print("err: {}\n", .{err});
        }
    }
    var columns = std.ArrayList(struct { value: []const u8 }).init(allocator);
    defer columns.deinit();

    var iter = hostMap.iterator();
    while (iter.next()) |item| {
        std.debug.print("hostname: {s}\n", .{item.key_ptr.*});
        var testiter = item.value_ptr.*.items;
        for (testiter) |value| {
            var d = value.testname;
            std.debug.print("testname: {s}\n", .{d});
            var n = columns.append(.{ .value = d });
            if (n) |vae| {
                _ = vae;
            } else |err| {
                std.debug.print("err: {}\n", .{err});
            }
        }
    }

    // var columns = std.ArrayList([]const u8).init(allocator);
    // defer columns.deinit();

    // var keys = ncolumns.keyIterator();

    // while (keys.next()) |k| {
    //     var p = columns.append(k.*);
    //     if (p) |val| {
    //         _ = val;
    //     } else |err| {
    //         std.debug.print("err: {}\n", .{err});
    //     }
    // }
    var testnames = allocator.alloc(XTest, 16) catch |err| {
        std.debug.print("err: {}\n", .{err});
        std.os.exit(1);
    };
    for (resp, 0..) |item, i| {
        testnames[i] = XTest{ .testname = item.testname };
    }

    defer allocator.free(testnames);

    const ret = mustache.build(.{ .responses = resp, .columns = testnames });

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
