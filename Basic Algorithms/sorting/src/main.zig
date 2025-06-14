const std = @import("std");
const sorting = @import("sorting");

pub fn main() !void {
    std.debug.print("Testing sorting algorithms.\n", .{});

    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();

    defer arenaAllocator.deinit();

    const values = try allocator.alloc(i32, @intCast(10_000));
    _ = try populateRandomArray(values);

    //Quick Sort
    std.debug.print("Quick Sort: \n", .{});
    quickSort(values, 0, @intCast(values.len - 1));
    printArray(values);

    //Bubble Sort
    _ = try populateRandomArray(values);
    std.debug.print("Bubble Sort: \n", .{});
    bubbleSort(values);
    printArray(values);
}

fn printArray(array: []i32) void {
    for (array) |value| {
        std.debug.print("{} ", .{value});
    }
    std.debug.print("\n", .{});
}

fn populateRandomArray(array: []i32) !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    for (array) |*i| {
        i.* = prng.random().int(i32);
    }
}

fn bubbleSort(values: []i32) void {
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
}

//Quick Sort
fn quickSort(values: []i32, lo: i64, hi: i64) void {
    if (lo >= 0 and hi >= 0 and lo < hi) {
        const pivot = partition(values, lo, hi);
        quickSort(values, lo, pivot);
        quickSort(values, pivot + 1, hi);
    }
}

fn partition(values: []i32, lo: i64, hi: i64) i64 {
    const pivot: i32 = values[@intCast(lo)];

    var i: i64 = lo - 1;
    var j: i64 = hi + 1;

    while (true) {
        i += 1;
        while (values[@intCast(i)] < pivot) {
            i += 1;
        }

        j -= 1;
        while (values[@intCast(j)] > pivot) {
            j -= 1;
        }

        if (i >= j) {
            return j;
        }

        const temp: i32 = values[@intCast(i)];
        values[@intCast(i)] = values[@intCast(j)];
        values[@intCast(j)] = temp;
    }
}
