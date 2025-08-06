const std = @import("std");
const types = @import("types.zig");
const PaymentQueue = @import("payment_queue.zig").PaymentQueue;
const HttpClient = @import("http_client.zig").HttpClient;
const Storage = @import("storage.zig").Storage;

pub const PaymentWorker = struct {
    queue: *PaymentQueue,
    client: *HttpClient,
    storage: *Storage,
    running: std.atomic.Value(bool),
    thread: ?std.Thread,

    pub fn init(queue: *PaymentQueue, client: *HttpClient, storage: *Storage) PaymentWorker {
        return PaymentWorker{
            .queue = queue,
            .client = client,
            .storage = storage,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
        };
    }

    pub fn start(self: *PaymentWorker) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, workerLoop, .{self});
    }

    pub fn stop(self: *PaymentWorker) void {
        self.running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    fn workerLoop(self: *PaymentWorker) void {
        while (self.running.load(.acquire)) {
            if (self.queue.pop()) |payment| {
                const success = self.client.sendPayment(payment) catch false;

                if (success) {
                    self.storage.addPayment(payment.correlation_id, payment.amount, .default) catch {};
                }

                self.queue.allocator.free(payment.correlation_id);
            } else {
                std.time.sleep(1_000_000);
            }
        }
    }
};
