const std = @import("std");
const net = std.net;
const types = @import("types.zig");
const http_utils = @import("http_utils.zig");

pub const HttpClient = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return HttpClient{
            .allocator = allocator,
        };
    }

    pub fn sendPayment(self: *HttpClient, payment: types.PaymentRequest) !bool {
        const address = try net.Address.resolveIp("payment-processor-default", 8080);
        const stream = net.tcpConnectToAddress(address) catch return false;
        defer stream.close();

        const now = std.time.timestamp();
        const timestamp_str = try http_utils.formatTimestamp(self.allocator, now);
        defer self.allocator.free(timestamp_str);

        const body = try std.fmt.allocPrint(self.allocator, "{{\"correlationId\":\"{s}\",\"amount\":{d:.2},\"requestedAt\":\"{s}\"}}", .{ payment.correlation_id, payment.amount, timestamp_str });
        defer self.allocator.free(body);

        const request = try std.fmt.allocPrint(self.allocator, "POST /payments HTTP/1.1\r\nHost: payment-processor-default:8080\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
        defer self.allocator.free(request);

        stream.writeAll(request) catch return false;

        var response_buffer: [1024]u8 = undefined;
        const bytes_read = stream.read(&response_buffer) catch return false;

        if (bytes_read == 0) return false;

        const response = response_buffer[0..bytes_read];
        return std.mem.startsWith(u8, response, "HTTP/1.1 200") or std.mem.startsWith(u8, response, "HTTP/1.0 200");
    }
};
