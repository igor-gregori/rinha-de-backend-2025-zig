const std = @import("std");
const types = @import("types.zig");

pub fn parseQueryParams(query_string: []const u8, allocator: std.mem.Allocator) !types.SummaryQuery {
    _ = allocator;

    var from: ?[]const u8 = null;
    var to: ?[]const u8 = null;

    var iter = std.mem.splitSequence(u8, query_string, "&");
    while (iter.next()) |param| {
        if (std.mem.startsWith(u8, param, "from=")) {
            from = param[5..];
        } else if (std.mem.startsWith(u8, param, "to=")) {
            to = param[3..];
        }
    }

    return types.SummaryQuery{
        .from = from,
        .to = to,
    };
}
