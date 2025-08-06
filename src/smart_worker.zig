const std = @import("std");
const types = @import("types.zig");
const PaymentQueue = @import("payment_queue.zig").PaymentQueue;
const HttpClient = @import("http_client.zig").HttpClient;
const StorageClient = @import("storage_client.zig").StorageClient;
const SharedProcessorState = @import("shared_state.zig").SharedProcessorState;

pub const SmartWorkerSystem = struct {
    queue: *PaymentQueue,
    client: *HttpClient,
    storage_client: *StorageClient,
    shared_state: *SharedProcessorState,
    trigger_ms: u32,
    running: std.atomic.Value(bool),
    master_thread: ?std.Thread,
    slave_threads: std.ArrayList(std.Thread),
    slave_notify: std.Thread.ResetEvent,
    slave_count: usize,

    pub fn init(allocator: std.mem.Allocator, queue: *PaymentQueue, client: *HttpClient, storage_client: *StorageClient, shared_state: *SharedProcessorState, trigger_ms: u32, slave_count: usize) SmartWorkerSystem {
        return SmartWorkerSystem{
            .queue = queue,
            .client = client,
            .storage_client = storage_client,
            .shared_state = shared_state,
            .trigger_ms = trigger_ms,
            .running = std.atomic.Value(bool).init(false),
            .master_thread = null,
            .slave_threads = std.ArrayList(std.Thread).init(allocator),
            .slave_notify = std.Thread.ResetEvent{},
            .slave_count = slave_count,
        };
    }

    pub fn deinit(self: *SmartWorkerSystem) void {
        self.slave_threads.deinit();
    }

    pub fn start(self: *SmartWorkerSystem) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);

        self.master_thread = try std.Thread.spawn(.{}, masterWorkerLoop, .{self});

        for (0..self.slave_count) |_| {
            const thread = try std.Thread.spawn(.{}, slaveWorkerLoop, .{self});
            try self.slave_threads.append(thread);
        }
    }

    pub fn stop(self: *SmartWorkerSystem) void {
        self.running.store(false, .release);
        self.slave_notify.set();

        if (self.master_thread) |thread| {
            thread.join();
            self.master_thread = null;
        }

        for (self.slave_threads.items) |thread| {
            thread.join();
        }
        self.slave_threads.clearRetainingCapacity();
    }

    fn masterWorkerLoop(self: *SmartWorkerSystem) void {
        std.debug.print("Master worker started\n", .{});
        while (self.running.load(.acquire)) {
            if (self.queue.pop()) |payment| {
                std.debug.print("Master processing payment: {s}\n", .{payment.correlation_id});
                const start_time = std.time.nanoTimestamp();

                const processor_type = self.client.sendPayment(payment) catch {
                    std.debug.print("Payment failed\n", .{});
                    self.queue.allocator.free(payment.correlation_id);
                    continue;
                };
                std.debug.print("Payment processed\n", .{});

                const duration_ns = std.time.nanoTimestamp() - start_time;
                const duration_ms = @as(u32, @intCast(@divTrunc(duration_ns, 1_000_000)));

                self.storage_client.addPayment(payment.correlation_id, payment.amount, processor_type) catch {};

                if (duration_ms <= self.trigger_ms) {
                    self.slave_notify.set();

                    while (self.queue.len() > 0 and duration_ms <= self.trigger_ms) {
                        if (self.queue.pop()) |next_payment| {
                            const next_start = std.time.nanoTimestamp();

                            const next_processor = self.client.sendPayment(next_payment) catch {
                                self.queue.allocator.free(next_payment.correlation_id);
                                break;
                            };

                            const next_duration_ns = std.time.nanoTimestamp() - next_start;
                            const next_duration_ms = @as(u32, @intCast(@divTrunc(next_duration_ns, 1_000_000)));

                            self.storage_client.addPayment(next_payment.correlation_id, next_payment.amount, next_processor) catch {};

                            self.queue.allocator.free(next_payment.correlation_id);

                            if (next_duration_ms > self.trigger_ms) break;
                        }
                    }
                }

                self.queue.allocator.free(payment.correlation_id);
            } else {
                std.time.sleep(1_000_000);
            }
        }
    }

    fn slaveWorkerLoop(self: *SmartWorkerSystem) void {
        while (self.running.load(.acquire)) {
            self.slave_notify.wait();

            if (!self.running.load(.acquire)) break;

            while (self.queue.len() > 0 and
                self.shared_state.isDefaultHealthy(self.trigger_ms) and
                self.shared_state.getDefaultLatency() <= self.trigger_ms)
            {
                if (self.queue.pop()) |payment| {
                    const processor_type = self.client.sendPayment(payment) catch {
                        self.queue.allocator.free(payment.correlation_id);
                        break;
                    };

                    self.storage_client.addPayment(payment.correlation_id, payment.amount, processor_type) catch {};

                    self.queue.allocator.free(payment.correlation_id);

                    if (!self.shared_state.isDefaultHealthy(self.trigger_ms)) break;
                } else {
                    break;
                }
            }
        }
    }
};
