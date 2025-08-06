const std = @import("std");
const net = std.net;
const print = std.debug.print;
const types = @import("types.zig");
const json_parser = @import("json_parser.zig");
const storage = @import("storage.zig");
const http_utils = @import("http_utils.zig");
const HttpClient = @import("http_client.zig").HttpClient;
const PaymentQueue = @import("payment_queue.zig").PaymentQueue;
const SmartWorkerSystem = @import("smart_worker.zig").SmartWorkerSystem;
const SharedProcessorState = @import("shared_state.zig").SharedProcessorState;
const protocol = @import("storage_protocol.zig");
const StorageClient = @import("storage_client.zig").StorageClient;

pub fn main() !void {
    print("=== STARTING RINHA BACKEND ===\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    print("Allocator initialized\n", .{});

    const storage_mode = std.process.getEnvVarOwned(allocator, "STORAGE_MODE") catch null;
    defer if (storage_mode) |mode| allocator.free(mode);

    if (storage_mode) |mode| {
        print("Storage mode detected: {s}\n", .{mode});
        return runStorageService(allocator);
    } else {
        print("Gateway mode detected (no STORAGE_MODE)\n", .{});
    }

    print("Gateway mode starting...\n", .{});
    const trigger_ms = 200;
    const slave_count = 2;

    var shared_state = SharedProcessorState.init();
    var client = HttpClient.init(allocator, &shared_state, trigger_ms);
    var queue = PaymentQueue.init(allocator);
    defer queue.deinit();

    print("Creating storage client...\n", .{});
    var storage_client = StorageClient.init(allocator, "/sockets/storage.sock");
    print("Storage client created\n", .{});

    var worker_system = SmartWorkerSystem.init(allocator, &queue, &client, &storage_client, &shared_state, trigger_ms, slave_count);
    defer worker_system.deinit();

    print("Starting worker system...\n", .{});
    try worker_system.start();
    print("Worker system started successfully\n", .{});
    defer worker_system.stop();

    const socket_path = std.process.getEnvVarOwned(allocator, "SOCKET_PATH") catch "/tmp/gateway.sock";
    defer if (!std.mem.eql(u8, socket_path, "/tmp/gateway.sock")) allocator.free(socket_path);

    if (std.fs.cwd().access(socket_path, .{})) {
        try std.fs.cwd().deleteFile(socket_path);
    } else |_| {}

    const address = try net.Address.initUnix(socket_path);
    var server = address.listen(.{
        .reuse_address = true,
    }) catch |err| {
        print("Failed to bind to {s}: {}\n", .{ socket_path, err });
        return;
    };
    defer server.deinit();

    const result = std.c.chmod(@ptrCast(socket_path), 0o777);
    if (result != 0) {
        print("Warning: Failed to set socket permissions: {}\n", .{result});
    }

    print("Server listening on {s}\n", .{socket_path});

    while (true) {
        const connection = server.accept() catch |err| {
            print("Failed to accept connection: {}\n", .{err});
            continue;
        };

        handleConnection(allocator, &storage_client, &queue, connection) catch |err| {
            print("Error handling connection: {}\n", .{err});
        };
        connection.stream.close();
    }
}

fn handleConnection(allocator: std.mem.Allocator, storage_client: *StorageClient, queue: *PaymentQueue, connection: net.Server.Connection) !void {
    var buffer: [4096]u8 = undefined;
    const bytes_read = try connection.stream.read(&buffer);

    if (bytes_read == 0) return;

    const request = buffer[0..bytes_read];

    if (std.mem.startsWith(u8, request, "POST /payments")) {
        try handlePayment(allocator, queue, connection.stream, request);
    } else if (std.mem.startsWith(u8, request, "GET /payments-summary")) {
        try handleSummary(allocator, storage_client, connection.stream, request);
    } else {
        try send404(connection.stream);
    }
}

fn handlePayment(allocator: std.mem.Allocator, queue: *PaymentQueue, stream: net.Stream, request: []const u8) !void {
    _ = allocator;

    const response = "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\n\r\n";
    _ = try stream.writeAll(response);

    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return;
    const body = request[body_start + 4 ..];

    if (body.len > 0) {
        const payment = json_parser.parsePaymentRequestInPlace(body) catch return;
        queue.push(payment) catch return;
    }
}

fn handleSummary(allocator: std.mem.Allocator, storage_client: *StorageClient, stream: net.Stream, request: []const u8) !void {
    var query = types.SummaryQuery{};

    if (std.mem.indexOf(u8, request, "?")) |query_start| {
        const query_end = std.mem.indexOf(u8, request[query_start..], " ") orelse request.len - query_start;
        const query_string = request[query_start + 1 .. query_start + query_end];
        query = http_utils.parseQueryParams(query_string, allocator) catch |err| {
            print("Error parsing query params: {}\n", .{err});
            return;
        };
    }

    const summary = storage_client.getSummary(query) catch |err| {
        print("Error getting summary: {}\n", .{err});
        return;
    };

    const json_body = json_parser.createPaymentSummaryJson(summary, allocator) catch return;
    defer allocator.free(json_body);

    const response = std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}", .{ json_body.len, json_body }) catch return;
    defer allocator.free(response);

    _ = try stream.writeAll(response);
}

fn send404(stream: net.Stream) !void {
    const response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n";
    _ = try stream.writeAll(response);
}

fn runStorageService(allocator: std.mem.Allocator) !void {
    print("Starting Storage Service...\n", .{});

    var store = storage.Storage.init(allocator);
    defer store.deinit();

    const socket_path = std.process.getEnvVarOwned(allocator, "SOCKET_PATH") catch "/tmp/storage.sock";
    defer if (!std.mem.eql(u8, socket_path, "/tmp/storage.sock")) allocator.free(socket_path);

    if (std.fs.cwd().access(socket_path, .{})) {
        try std.fs.cwd().deleteFile(socket_path);
    } else |_| {}

    const address = try net.Address.initUnix(socket_path);
    var server = address.listen(.{
        .reuse_address = true,
    }) catch |err| {
        print("Failed to bind storage to {s}: {}\n", .{ socket_path, err });
        return;
    };
    defer server.deinit();

    const result = std.c.chmod(@ptrCast(socket_path), 0o777);
    if (result != 0) {
        print("Warning: Failed to set storage socket permissions: {}\n", .{result});
    }

    print("Storage Service listening on {s}\n", .{socket_path});

    while (true) {
        const connection = server.accept() catch |err| {
            print("Failed to accept storage connection: {}\n", .{err});
            continue;
        };

        handleStorageConnection(allocator, &store, connection) catch |err| {
            print("Error handling storage connection: {}\n", .{err});
        };
        connection.stream.close();
    }
}

fn handleStorageConnection(allocator: std.mem.Allocator, store: *storage.Storage, connection: net.Server.Connection) !void {
    const reader = connection.stream.reader();
    const writer = connection.stream.writer();

    const command = protocol.readCommand(reader) catch return;

    switch (command) {
        .add_payment => {
            const request = protocol.readAddPaymentRequest(reader, allocator) catch return;
            defer allocator.free(request.correlation_id);

            store.addPayment(request.correlation_id, request.amount, request.processor) catch {};

            try writer.writeByte(1);
        },
        .get_summary => {
            const request = protocol.readGetSummaryRequest(reader, allocator) catch return;
            defer if (request.from) |from| allocator.free(from);
            defer if (request.to) |to| allocator.free(to);

            const query = types.SummaryQuery{
                .from = request.from,
                .to = request.to,
            };

            const summary = store.getSummary(query);

            try protocol.writePaymentSummary(writer, summary);
        },
        .purge_payments => {
            store.reset();
            try writer.writeByte(1);
        },
    }
}
