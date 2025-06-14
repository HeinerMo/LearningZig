const std = @import("std");
const sorting = @import("sorting");

pub fn main() !void {
    std.debug.print("Testing sorting algos.\n", .{});

    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();

    defer arenaAllocator.deinit();

    const values = try createRandomArray(allocator, 1000);

    _ = bubbleSort(values);

    for (values) |value| {
        std.debug.print("{}\n", .{value});
    }
}

fn createRandomArray(allocator: std.mem.Allocator, size: usize) ![]i32 {
    const values = try allocator.alloc(i32, size);
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    for (values) |*value| {
        value.* = prng.random().int(i32);
    }

    return values;
}

fn bubbleSort(values: []i32) []i32 {
    var n: usize = values.len;
    var newn: usize = 0;
    while (n >= 1) {
        newn = 0;
        for (0..values.len - 1) |i| {
            if (values[i + 1] < values[i]) {
                const temp = values[i + 1];
                values[i + 1] = values[i];
                values[i] = temp;
                newn = i;
            }
            n = newn;
        }
    }
    return values;
}
