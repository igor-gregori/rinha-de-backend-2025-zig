const std = @import("std");

pub const PaymentRequest = struct {
    correlation_id: []const u8,
    amount: f64,
    requested_at: []const u8,
};

pub const PaymentRecord = struct {
    correlation_id: []const u8,
    amount: f64,
    timestamp: i64,
    processor: ProcessorType,
};

pub const ProcessorType = enum {
    default,
    fallback,
};

pub const PaymentSummary = struct {
    default: ProcessorSummary,
    fallback: ProcessorSummary,
};

pub const ProcessorSummary = struct {
    total_requests: u64,
    total_amount: f64,
};

pub const SummaryQuery = struct {
    from: ?[]const u8 = null,
    to: ?[]const u8 = null,
};
