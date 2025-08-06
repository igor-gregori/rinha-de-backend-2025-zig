const std = @import("std");
const types = @import("types.zig");

pub fn parsePaymentRequest(json_data: []const u8, allocator: std.mem.Allocator) !types.PaymentRequest {
    var parser = std.json.Parser.init(allocator, .alloc_if_needed);
    defer parser.deinit();

    var tree = try parser.parse(json_data);
    defer tree.deinit();

    const root = tree.root.object;

    const correlation_id = root.get("correlationId").?.string;
    const amount = root.get("amount").?.number_value;

    return types.PaymentRequest{
        .correlation_id = correlation_id,
        .amount = amount,
        .requested_at = "",
    };
}

pub fn parsePaymentRequestInPlace(json_data: []const u8) !types.PaymentRequest {
    var correlation_id: []const u8 = undefined;
    var amount: f64 = 0.0;

    var i: usize = 0;
    while (i < json_data.len) {
        if (std.mem.startsWith(u8, json_data[i..], "\"correlationId\"")) {
            i += 15;
            while (i < json_data.len and json_data[i] != '"') i += 1;
            i += 1;
            const start = i;
            while (i < json_data.len and json_data[i] != '"') i += 1;
            correlation_id = json_data[start..i];
        } else if (std.mem.startsWith(u8, json_data[i..], "\"amount\"")) {
            i += 8;
            while (i < json_data.len and (json_data[i] < '0' or json_data[i] > '9')) i += 1;
            const start = i;
            while (i < json_data.len and (json_data[i] >= '0' and json_data[i] <= '9' or json_data[i] == '.')) i += 1;
            amount = std.fmt.parseFloat(f64, json_data[start..i]) catch 0.0;
        }
        i += 1;
    }

    return types.PaymentRequest{
        .correlation_id = correlation_id,
        .amount = amount,
        .requested_at = "",
    };
}

pub fn createPaymentSummaryJson(summary: types.PaymentSummary, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"default\":{{\"totalRequests\":{d},\"totalAmount\":{d:.2}}},\"fallback\":{{\"totalRequests\":{d},\"totalAmount\":{d:.2}}}}}", .{ summary.default.total_requests, summary.default.total_amount, summary.fallback.total_requests, summary.fallback.total_amount });
}
