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

    var buf: [128]u8 = undefined;
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

        //set Read timeout to 2.5 seconds
        const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));

        // add the write timeout
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

        const read = posix.read(socket, &buf) catch |err| {
            std.debug.print("error reading: {}\n", .{err});
            continue;
        };

        //The following comments show how to perform the read and write using the Zig's Standard Library. However, it is best to use the sockets directly.
        //const stream = std.net.Stream{.handle = socket};
        //const read = try stream.read(&buf);
        //try stream.writeAll(buf[0..read]);

        if (read == 0) {
            continue;
        }

        writeMessage(socket, buf[0..read]) catch |err| {
            // This can easily happen, say if the client disconnects.
            std.debug.print("error writing: {}\n", .{err});
        };
    }
}

//fn write(socket: posix.socket_t, msg: []const u8) !void {
//    var pos: usize = 0;
//    while (pos < msg.len) {
//        const written = try posix.write(socket, msg[pos..]);
//        if (written == 0) {
//            return error.Closed;
//        pos += written;
//    }
//}

//Write message including a header with msh.len encoded in little endian and using 2 system calls to write.
//fn writeMessage(socket: posix.socket_t, msg: []const u8) !void {
//    var buf: [4]u8 = undefined;
//    std.mem.writeInt(u32, &buf, @intCast(msg.len), .little);
//    try writeAll(socket, &buf);
//    try writeAll(socket, msg);
//}

//fn writeAll(socket: posix.socket_t, msg: []const u8) !void {
//    var pos: usize = 0;
//    while (pos < msg.len) {
//        const written = try posix.write(socket, msg[pos..]);
//        if (written == 0) {
//            return error.Closed;
//        }
//        pos += written;
//    }
//}

//Write using WriteV - It's part of a family of operation known as vectored I/O or scatter/gather I/O (because we're gathering data from multiple buffers)
fn writeMessage(socket: posix.socket_t, msg: []const u8) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, @intCast(msg.len), .little);

    var vec = [2]posix.iovec_const{
        .{ .len = 4, .base = &buf },
        .{ .len = msg.len, .base = msg.ptr },
    };

    try writeAllVectored(socket, &vec);
}

fn writeAllVectored(socket: posix.socket_t, vec: []posix.iovec_const) !void {
    var i: usize = 0;
    while (true) {
        var n = try posix.writev(socket, vec[i..]);
        while (n >= vec[i].len) {
            n -= vec[i].len;
            i += 1;
            if (i >= vec.len) return;
        }
        vec[i].base += n;
        vec[i].len -= n;
    }
}

//Read
const Reader = struct {
    // This is what we'll read into and where we'll look for a complete message
    buf: []u8,

    // This is where in buf that we're read up to, any subsequent reads need
    // to start from here
    pos: usize = 0,

    // This is where our next message starts at
    start: usize = 0,

    // The socket to read from
    socket: posix.socket_t,

    fn readMessage(self: *Reader) ![]u8 {
        var buf = self.buf;

        // loop until we've read a message, or the connection was closed
        while (true) {

            // Check if we already have a message in our buffer
            if (try self.bufferedMessage()) |msg| {
                return msg;
            }

            // read data from the socket, we need to read this into buf from
            // the end of where we have data (aka, self.pos)
            const pos = self.pos;
            const n = try posix.read(self.socket, buf[pos..]);
            if (n == 0) {
                return error.Closed;
            }

            self.pos = pos + n;
        }
    }

    // Checks if there's a full message in self.buf already.
    // If there isn't, checks that we have enough spare space in self.buf for
    // the next message.
    fn bufferedMessage(self: *Reader) !?[]u8 {
        const buf = self.buf;
        // position up to where we have valid data
        const pos = self.pos;

        // position where the next message start
        const start = self.start;

        // pos - start represents bytes that we've read from the socket
        // but that we haven't yet returned as a "message" - possibly because
        // its incomplete.
        std.debug.assert(pos >= start);
        const unprocessed = buf[start..pos];

        if (unprocessed.len < 4) {
            // We always need at least 4 bytes of data (the length prefix)
            self.ensureSpace(4 - unprocessed.len) catch unreachable;
            return null;
        }

        // The length of the message
        const message_len = std.mem.readInt(u32, unprocessed[0..4], .little);

        // the length of our message + the length of our prefix
        const total_len = message_len + 4;

        if (unprocessed.len < total_len) {
            // We know the length of the message, but we don't have all the
            // bytes yet.
            try self.ensureSpace(total_len);
            return null;
        }

        // Position start at the start of the next message. We might not have
        // any data for this next message, but we know that it'll start where
        // our last message ended.
        self.start += total_len;
        return unprocessed[4..total_len];
    }

    // We want to make sure we have enough spare space in our buffer. This can
    // mean two things:
    //   1 - If we know that length of the next message, we need to make sure
    //       that our buffer is large enough for that message. If our buffer
    //       isn't large enough, we return an error (as an alternative, we could
    //       do something else, like dynamically allocate memory or pull a large
    //       buffer froma buffer pool).
    //   2 - At any point that we need to read more data, we need to make sure
    //       that our "spare" space (self.buf.len - self.start) is large enough
    //       for the required data. If it isn't, we need shift our buffer around
    //       and move whatever unprocessed data we have back to the start.
    fn ensureSpace(self: *Reader, space: usize) error{BufferTooSmall}!void {
        const buf = self.buf;
        if (buf.len < space) {
            // Even if we compacted our buffer (moving any unprocessed data back
            // to the start), we wouldn't have enough space for this message in
            // our buffer. Alternatively: dynamically allocate or pull a large
            // buffer from a buffer pool.
            return error.BufferTooSmall;
        }

        const start = self.start;
        const spare = buf.len - start;
        if (spare >= space) {
            // We have enough spare space in our buffer, nothing to do.
            return;
        }

        // At this point, we know that our buffer is larger enough for the data
        // we want to read, but we don't have enough spare space. We need to
        // "compact" our buffer, moving any unprocessed data back to the start
        // of the buffer.
        const unprocessed = buf[start..self.pos];
        std.mem.copyForwards(u8, buf[0..unprocessed.len], unprocessed);
        self.start = 0;
        self.pos = unprocessed.len;
    }
};
