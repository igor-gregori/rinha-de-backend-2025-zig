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

    // OTIMIZAÇÃO QUASE QUE BARE METAL PARA A RINHA 2025:
    // Como sabemos que 99% das consultas serão para agosto/2025 em diante,
    // pré-calculei os dias até 1º de agosto de 2025 para evitar 55 anos
    // de loops desnecessários. Isso reduz O(55) para O(1) na maioria dos casos.
    // Para datas anteriores, mantive o algoritmo original por compatibilidade.

    // Hot-path: algoritmo otimizado para datas a partir de agosto/2025
    if (year >= 2025 and (year > 2025 or month >= 8)) {
        const DAYS_TO_AUG_1_2025: i64 = 20210;

        var total_days: i64 = DAYS_TO_AUG_1_2025;

        if (year == 2025) {
            const aug_days = [_]u8{ 31, 30, 31, 30, 31 };
            var m: u8 = 8;
            while (m < month) : (m += 1) {
                total_days += aug_days[m - 8];
            }
        } else {
            total_days += 153;

            var y: i32 = 2026;
            while (y < year) : (y += 1) {
                total_days += if (isLeapYear(y)) 366 else 365;
            }

            const month_days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
            var m: u8 = 1;
            while (m < month) : (m += 1) {
                total_days += month_days[m - 1];
                if (m == 2 and isLeapYear(year)) {
                    total_days += 1;
                }
            }
        }

        total_days += day - 1;
        const seconds_in_day = @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
        return total_days * 86400 + seconds_in_day;
    }

    // Slow path: algoritmo completo para datas anteriores a agosto/2025
    var total_days: i64 = 0;

    var y: i32 = 1970;
    while (y < year) : (y += 1) {
        if (isLeapYear(y)) {
            total_days += 366;
        } else {
            total_days += 365;
        }
    }

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
