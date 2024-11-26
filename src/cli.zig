const std = @import("std");
const clap = @import("clap");

const VERSION = "0.0.1";

pub var sample_rate: usize = undefined;
pub var buffer_size: usize = undefined;

pub fn parseArguments() bool {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    //     \\-c, --configure             Configure all values on initialization.
    const help =
        \\-h, --help                  Display this help and exit.
        \\-v, --version               Output version information and exit.
        \\-s, --sample_rate <usize>   Sample rate.
        \\-b, --buffer_size <usize>   Audio buffer size.
    ;

    const params = comptime clap.parseParamsComptime(help);

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch {
        std.debug.print("Error: Invalid usage.\n\n", .{});
        std.debug.print("usage: guitarz [<args>]\n{s}\n", .{help});
        return false;
    };

    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("usage: guitarz [<args>]\n{s}", .{help});
        return false;
    }

    if (res.args.version != 0) {
        std.debug.print("guitarz version is {s}.\n", .{VERSION});
        return false;
    }

    if (res.args.sample_rate) |rate|
        sample_rate = rate;

    if (res.args.buffer_size) |size|
        buffer_size = size;

    return true;
}
