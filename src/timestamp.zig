const std = @import("std");

pub fn parseIsoTimestamp(iso_string: []const u8) ?i64 {
    if (iso_string.len < 19) return null;

    const year = std.fmt.parseInt(i32, iso_string[0..4], 10) catch return null;
    const month = std.fmt.parseInt(u8, iso_string[5..7], 10) catch return null;
    const day = std.fmt.parseInt(u8, iso_string[8..10], 10) catch return null;
    const hour = std.fmt.parseInt(u8, iso_string[11..13], 10) catch return null;
    const minute = std.fmt.parseInt(u8, iso_string[14..16], 10) catch return null;
    const second = std.fmt.parseInt(u8, iso_string[17..19], 10) catch return null;

    const days_since_epoch = daysSinceEpoch(year, month, day);
    const seconds_in_day = @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);

    return days_since_epoch * 86400 + seconds_in_day;
}

fn daysSinceEpoch(year: i32, month: u8, day: u8) i64 {
    var y = year;
    var m = @as(i32, month);

    if (m <= 2) {
        y -= 1;
        m += 12;
    }

    const a = @divFloor(y, 100);
    const b = @divFloor(a, 4);
    const c = 2 - a + b;
    const e = @as(i64, @intFromFloat(@floor(365.25 * @as(f64, @floatFromInt(y + 4716)))));
    const f = @as(i64, @intFromFloat(@floor(30.6001 * @as(f64, @floatFromInt(m + 1)))));

    return c + @as(i64, day) + e + f - 2442448;
}
