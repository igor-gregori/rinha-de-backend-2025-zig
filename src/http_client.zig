const std = @import("std");
const net = std.net;
const types = @import("types.zig");
const http_utils = @import("http_utils.zig");
const SharedProcessorState = @import("shared_state.zig").SharedProcessorState;

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    shared_state: *SharedProcessorState,
    trigger_ms: u32,

    pub fn init(allocator: std.mem.Allocator, shared_state: *SharedProcessorState, trigger_ms: u32) HttpClient {
        return HttpClient{
            .allocator = allocator,
            .shared_state = shared_state,
            .trigger_ms = trigger_ms,
        };
    }

    pub fn sendPayment(self: *HttpClient, payment: types.PaymentRequest) !types.ProcessorType {
        if (self.shared_state.isDefaultHealthy(self.trigger_ms)) {
            const start_time = std.time.nanoTimestamp();

            if (self.sendToProcessor(payment, "payment-processor-default", 8080)) {
                const duration_ns = std.time.nanoTimestamp() - start_time;
                const duration_ms = @as(u32, @intCast(@divTrunc(duration_ns, 1_000_000)));

                self.shared_state.updateDefaultState(true, duration_ms);
                return .default;
            } else {
                self.shared_state.updateDefaultState(false, 0);
            }
        }

        return error.ProcessorUnavailable;
    }

    fn sendToProcessor(self: *HttpClient, payment: types.PaymentRequest, host: []const u8, port: u16) bool {
        const address = net.Address.resolveIp(host, port) catch return false;
        const stream = net.tcpConnectToAddress(address) catch return false;
        defer stream.close();

        const now = std.time.timestamp();
        const timestamp_str = http_utils.formatTimestamp(self.allocator, now) catch return false;
        defer self.allocator.free(timestamp_str);

        const body = std.fmt.allocPrint(self.allocator, "{{\"correlationId\":\"{s}\",\"amount\":{d:.2},\"requestedAt\":\"{s}\"}}", .{ payment.correlation_id, payment.amount, timestamp_str }) catch return false;
        defer self.allocator.free(body);

        const request = std.fmt.allocPrint(self.allocator, "POST /payments HTTP/1.1\r\nHost: {s}:{d}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ host, port, body.len, body }) catch return false;
        defer self.allocator.free(request);

        stream.writeAll(request) catch return false;

        var response_buffer: [1024]u8 = undefined;
        const bytes_read = stream.read(&response_buffer) catch return false;

        if (bytes_read == 0) return false;

        const response = response_buffer[0..bytes_read];
        return std.mem.startsWith(u8, response, "HTTP/1.1 200") or
            std.mem.startsWith(u8, response, "HTTP/1.0 200");
    }
};
