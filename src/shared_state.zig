const std = @import("std");

pub const SharedProcessorState = struct {
    default_failing: std.atomic.Value(bool),
    default_avg_latency: std.atomic.Value(u32),
    fallback_failing: std.atomic.Value(bool),
    fallback_avg_latency: std.atomic.Value(u32),
    last_update: std.atomic.Value(i64),

    pub fn init() SharedProcessorState {
        return SharedProcessorState{
            .default_failing = std.atomic.Value(bool).init(false),
            .default_avg_latency = std.atomic.Value(u32).init(100),
            .fallback_failing = std.atomic.Value(bool).init(false),
            .fallback_avg_latency = std.atomic.Value(u32).init(200),
            .last_update = std.atomic.Value(i64).init(0),
        };
    }

    pub fn updateDefaultState(self: *SharedProcessorState, success: bool, latency_ms: u32) void {
        self.default_failing.store(!success, .release);
        if (success) {
            self.default_avg_latency.store(latency_ms, .release);
        }
        self.last_update.store(std.time.timestamp(), .release);
    }

    pub fn updateFallbackState(self: *SharedProcessorState, success: bool, latency_ms: u32) void {
        self.fallback_failing.store(!success, .release);
        if (success) {
            self.fallback_avg_latency.store(latency_ms, .release);
        }
        self.last_update.store(std.time.timestamp(), .release);
    }

    pub fn isDefaultHealthy(self: *SharedProcessorState, trigger_ms: u32) bool {
        if (self.default_failing.load(.acquire)) return false;
        return self.default_avg_latency.load(.acquire) <= trigger_ms;
    }

    pub fn isFallbackHealthy(self: *SharedProcessorState, trigger_ms: u32) bool {
        if (self.fallback_failing.load(.acquire)) return false;
        return self.fallback_avg_latency.load(.acquire) <= trigger_ms;
    }

    pub fn getDefaultLatency(self: *SharedProcessorState) u32 {
        return self.default_avg_latency.load(.acquire);
    }

    pub fn getFallbackLatency(self: *SharedProcessorState) u32 {
        return self.fallback_avg_latency.load(.acquire);
    }
};
