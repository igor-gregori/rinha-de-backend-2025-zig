const std = @import("std");
const types = @import("types.zig");

pub const StorageCommand = enum(u8) {
    add_payment = 1,
    get_summary = 2,
    purge_payments = 3,
};

pub const AddPaymentRequest = struct {
    correlation_id: []const u8,
    amount: f64,
    processor: types.ProcessorType,
};

pub const GetSummaryRequest = struct {
    from: ?[]const u8,
    to: ?[]const u8,
};

pub fn writeCommand(writer: anytype, command: StorageCommand) !void {
    try writer.writeByte(@intFromEnum(command));
}

pub fn readCommand(reader: anytype) !StorageCommand {
    const byte = try reader.readByte();
    return @enumFromInt(byte);
}

pub fn writeString(writer: anytype, str: []const u8) !void {
    try writer.writeInt(u32, @intCast(str.len), .little);
    try writer.writeAll(str);
}

pub fn readString(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len = try reader.readInt(u32, .little);
    const str = try allocator.alloc(u8, len);
    _ = try reader.readAll(str);
    return str;
}

pub fn writeAddPaymentRequest(writer: anytype, req: AddPaymentRequest) !void {
    try writeString(writer, req.correlation_id);
    try writer.writeInt(u64, @bitCast(req.amount), .little);
    try writer.writeByte(@intFromEnum(req.processor));
}

pub fn readAddPaymentRequest(reader: anytype, allocator: std.mem.Allocator) !AddPaymentRequest {
    const correlation_id = try readString(reader, allocator);
    const amount_bits = try reader.readInt(u64, .little);
    const amount: f64 = @bitCast(amount_bits);
    const processor_byte = try reader.readByte();
    const processor: types.ProcessorType = @enumFromInt(processor_byte);

    return AddPaymentRequest{
        .correlation_id = correlation_id,
        .amount = amount,
        .processor = processor,
    };
}

pub fn writeGetSummaryRequest(writer: anytype, req: GetSummaryRequest) !void {
    if (req.from) |from| {
        try writer.writeByte(1);
        try writeString(writer, from);
    } else {
        try writer.writeByte(0);
    }

    if (req.to) |to| {
        try writer.writeByte(1);
        try writeString(writer, to);
    } else {
        try writer.writeByte(0);
    }
}

pub fn readGetSummaryRequest(reader: anytype, allocator: std.mem.Allocator) !GetSummaryRequest {
    const has_from = try reader.readByte();
    const from = if (has_from == 1) try readString(reader, allocator) else null;

    const has_to = try reader.readByte();
    const to = if (has_to == 1) try readString(reader, allocator) else null;

    return GetSummaryRequest{
        .from = from,
        .to = to,
    };
}

pub fn writePaymentSummary(writer: anytype, summary: types.PaymentSummary) !void {
    try writer.writeInt(u64, summary.default.total_requests, .little);
    try writer.writeInt(u64, @bitCast(summary.default.total_amount), .little);
    try writer.writeInt(u64, summary.fallback.total_requests, .little);
    try writer.writeInt(u64, @bitCast(summary.fallback.total_amount), .little);
}

pub fn readPaymentSummary(reader: anytype) !types.PaymentSummary {
    const default_requests = try reader.readInt(u64, .little);
    const default_amount_bits = try reader.readInt(u64, .little);
    const default_amount: f64 = @bitCast(default_amount_bits);

    const fallback_requests = try reader.readInt(u64, .little);
    const fallback_amount_bits = try reader.readInt(u64, .little);
    const fallback_amount: f64 = @bitCast(fallback_amount_bits);

    return types.PaymentSummary{
        .default = types.ProcessorSummary{
            .total_requests = default_requests,
            .total_amount = default_amount,
        },
        .fallback = types.ProcessorSummary{
            .total_requests = fallback_requests,
            .total_amount = fallback_amount,
        },
    };
}
