const std = @import("std");
const net = std.net;
const posix = std.posix;
const server = @import("server");

// Following the tutorial on:
// https://www.openmymind.net/TCP-Server-In-Zig-Part-1-Single-Threaded/

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 5882); //Parse the string and port to a valid Address (std.net.Address

    const tpe: u32 = posix.SOCK.STREAM; // specify the socket type from the posix module and SOCK namespace. SOCK.STREAM = TCP and SOCK.DGRAM = UDP
    const protocol = posix.IPPROTO.TCP; // specify the protocol from the posix module and the IPROTO namespace.
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    //posix.connect = client
    //posix.listen = server

    //posix.setsockopt (set socket options)
    //listener(socket handle)
    //posix.SO.REUSEADDR (Allows socket to bind to an address already in use, usefull for running the program multiple times without errors)
    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1))); //set the SO_REUSEADDR option on the listener socket, allowing it to reuse the address

    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128); //the 128 represents the max number of pending connections the socket can queue.

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            // Rare that this happens, but in later parts we'll
            // see examples where it does.
            std.debug.print("error accept: {}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        std.debug.print("{} connected\n", .{client_address});

        write(socket, "Hello (and goodbye)") catch |err| {
            // This can easily happen, say if the client disconnects.
            std.debug.print("error writing: {}\n", .{err});
        };
    }
}

fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
