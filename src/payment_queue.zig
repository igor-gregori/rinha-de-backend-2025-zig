const std = @import("std");
const types = @import("types.zig");

pub const PaymentQueue = struct {
    items: std.ArrayList(types.PaymentRequest),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PaymentQueue {
        return PaymentQueue{
            .items = std.ArrayList(types.PaymentRequest).init(allocator),
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PaymentQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.items.items) |item| {
            self.allocator.free(item.correlation_id);
        }
        self.items.deinit();
    }

    pub fn push(self: *PaymentQueue, payment: types.PaymentRequest) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const id_copy = try self.allocator.dupe(u8, payment.correlation_id);
        const payment_copy = types.PaymentRequest{
            .correlation_id = id_copy,
            .amount = payment.amount,
            .requested_at = payment.requested_at,
        };

        try self.items.append(payment_copy);
    }

    pub fn pop(self: *PaymentQueue) ?types.PaymentRequest {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.items.items.len == 0) return null;

        return self.items.orderedRemove(0);
    }

    pub fn len(self: *PaymentQueue) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.items.items.len;
    }
};
