const std = @import("std");
const net = std.net;
const types = @import("types.zig");
const protocol = @import("storage_protocol.zig");

pub const StorageClient = struct {
    allocator: std.mem.Allocator,
    socket_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, socket_path: []const u8) StorageClient {
        return StorageClient{
            .allocator = allocator,
            .socket_path = socket_path,
        };
    }

    pub fn addPayment(self: *StorageClient, correlation_id: []const u8, amount: f64, processor: types.ProcessorType) !void {
        const stream = net.connectUnixSocket(self.socket_path) catch return;
        defer stream.close();

        const writer = stream.writer();
        const reader = stream.reader();

        try protocol.writeCommand(writer, .add_payment);

        const request = protocol.AddPaymentRequest{
            .correlation_id = correlation_id,
            .amount = amount,
            .processor = processor,
        };

        try protocol.writeAddPaymentRequest(writer, request);

        const response = try reader.readByte();
        _ = response;
    }

    pub fn getSummary(self: *StorageClient, query: types.SummaryQuery) !types.PaymentSummary {
        const stream = net.connectUnixSocket(self.socket_path) catch return error.ConnectionFailed;
        defer stream.close();

        const writer = stream.writer();
        const reader = stream.reader();

        try protocol.writeCommand(writer, .get_summary);

        const request = protocol.GetSummaryRequest{
            .from = query.from,
            .to = query.to,
        };

        protocol.writeGetSummaryRequest(writer, request) catch |err| {
            std.debug.print("Error writing get summary request: {}\n", .{err});
            return error.ConnectionFailed;
        };

        return try protocol.readPaymentSummary(reader);
    }

    pub fn purgePayments(self: *StorageClient) !void {
        const stream = net.connectUnixSocket(self.socket_path) catch return;
        defer stream.close();

        const writer = stream.writer();
        const reader = stream.reader();

        try protocol.writeCommand(writer, .purge_payments);

        const response = try reader.readByte();
        _ = response;
    }
};
