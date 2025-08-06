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

pub fn formatTimestamp(allocator: std.mem.Allocator, timestamp: i64) ![]u8 {
    const epoch_seconds = @as(u64, @intCast(timestamp));
    const days_since_epoch = epoch_seconds / 86400;
    const seconds_today = epoch_seconds % 86400;

    const hours = seconds_today / 3600;
    const minutes = (seconds_today % 3600) / 60;
    const seconds = seconds_today % 60;

    const year = @as(u32, @intCast(1970 + days_since_epoch / 365));
    const day_of_year = days_since_epoch % 365;
    const month = @min(12, @as(u32, @intCast(day_of_year / 30 + 1)));
    const day = @as(u32, @intCast(day_of_year % 30 + 1));

    return try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.000Z", .{ year, month, day, hours, minutes, seconds });
}
