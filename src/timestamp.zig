const std = @import("std");

pub fn parseIsoTimestamp(iso_string: []const u8) ?i64 {
    if (iso_string.len < 19) return null;

    const year = std.fmt.parseInt(i32, iso_string[0..4], 10) catch return null;
    const month = std.fmt.parseInt(u8, iso_string[5..7], 10) catch return null;
    const day = std.fmt.parseInt(u8, iso_string[8..10], 10) catch return null;
    const hour = std.fmt.parseInt(u8, iso_string[11..13], 10) catch return null;
    const minute = std.fmt.parseInt(u8, iso_string[14..16], 10) catch return null;
    const second = std.fmt.parseInt(u8, iso_string[17..19], 10) catch return null;

    if (year < 1970) return null;

    var total_days: i64 = 0;

    if (year == 2025) {
        // Hot-path
        total_days += 20089;
    } else {
        // Slow path
        var y: i32 = 1970;
        while (y < year) : (y += 1) {
            if (isLeapYear(y)) {
                total_days += 366;
            } else {
                total_days += 365;
            }
        }
    }

    // TODO: Ver se compensa fazer um Hot-path para o mês de agosto...
    const month_days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        total_days += month_days[m - 1];
        if (m == 2 and isLeapYear(year)) {
            total_days += 1;
        }
    }

    total_days += day - 1;

    const seconds_in_day = @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
    return total_days * 86400 + seconds_in_day;
}

fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or (@mod(year, 400) == 0);
}
