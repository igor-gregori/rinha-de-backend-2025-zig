const std = @import("std");
const types = @import("types.zig");
const timestamp = @import("timestamp.zig");

pub const Storage = struct {
    payments: std.ArrayList(types.PaymentRecord),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Storage {
        return Storage{
            .payments = std.ArrayList(types.PaymentRecord).init(allocator),
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Storage) void {
        self.payments.deinit();
    }

    pub fn addPayment(self: *Storage, correlation_id: []const u8, amount: f64, processor: types.ProcessorType) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        const id_copy = try self.allocator.dupe(u8, correlation_id);

        try self.payments.append(types.PaymentRecord{
            .correlation_id = id_copy,
            .amount = amount,
            .timestamp = now,
            .processor = processor,
        });
    }

    pub fn getSummary(self: *Storage, query: types.SummaryQuery) types.PaymentSummary {
        self.mutex.lock();
        defer self.mutex.unlock();

        var default_requests: u64 = 0;
        var default_amount: f64 = 0.0;
        var fallback_requests: u64 = 0;
        var fallback_amount: f64 = 0.0;

        const from_timestamp = if (query.from) |from| timestamp.parseIsoTimestamp(from) else null;
        const to_timestamp = if (query.to) |to| timestamp.parseIsoTimestamp(to) else null;

        for (self.payments.items) |payment| {
            if (from_timestamp) |from| {
                if (payment.timestamp < from) {
                    continue;
                }
            }
            if (to_timestamp) |to| {
                if (payment.timestamp > to) {
                    continue;
                }
            }

            switch (payment.processor) {
                .default => {
                    default_requests += 1;
                    default_amount += payment.amount;
                },
                .fallback => {
                    fallback_requests += 1;
                    fallback_amount += payment.amount;
                },
            }
        }

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

    pub fn reset(self: *Storage) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.payments.items) |payment| {
            self.allocator.free(payment.correlation_id);
        }
        self.payments.clearRetainingCapacity();
    }
};
