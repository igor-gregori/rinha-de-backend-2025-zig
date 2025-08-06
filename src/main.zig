const std = @import("std");
const net = std.net;
const print = std.debug.print;
const types = @import("types.zig");
const json_parser = @import("json_parser.zig");
const storage = @import("storage.zig");
const http_utils = @import("http_utils.zig");
const HttpClient = @import("http_client.zig").HttpClient;
const PaymentQueue = @import("payment_queue.zig").PaymentQueue;
const PaymentWorker = @import("payment_worker.zig").PaymentWorker;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var store = storage.Storage.init(allocator);
    defer store.deinit();

    var client = HttpClient.init(allocator);
    var queue = PaymentQueue.init(allocator);
    defer queue.deinit();

    var worker = PaymentWorker.init(&queue, &client, &store);
    try worker.start();
    defer worker.stop();

    const socket_path = "/tmp/gateway.sock";

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

    print("Server listening on {s}\n", .{socket_path});

    while (true) {
        const connection = server.accept() catch |err| {
            print("Failed to accept connection: {}\n", .{err});
            continue;
        };

        handleConnection(allocator, &store, &queue, connection) catch |err| {
            print("Error handling connection: {}\n", .{err});
        };
        connection.stream.close();
    }
}

fn handleConnection(allocator: std.mem.Allocator, store: *storage.Storage, queue: *PaymentQueue, connection: net.Server.Connection) !void {
    var buffer: [4096]u8 = undefined;
    const bytes_read = try connection.stream.read(&buffer);

    if (bytes_read == 0) return;

    const request = buffer[0..bytes_read];

    if (std.mem.startsWith(u8, request, "POST /payments")) {
        try handlePayment(allocator, queue, connection.stream, request);
    } else if (std.mem.startsWith(u8, request, "GET /payments-summary")) {
        try handleSummary(allocator, store, connection.stream, request);
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

fn handleSummary(allocator: std.mem.Allocator, store: *storage.Storage, stream: net.Stream, request: []const u8) !void {
    var query = types.SummaryQuery{};

    if (std.mem.indexOf(u8, request, "?")) |query_start| {
        const query_end = std.mem.indexOf(u8, request[query_start..], " ") orelse request.len - query_start;
        const query_string = request[query_start + 1 .. query_start + query_end];
        query = http_utils.parseQueryParams(query_string, allocator) catch types.SummaryQuery{};
    }

    const summary = store.getSummary(query);
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
