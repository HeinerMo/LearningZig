const std = @import("std");
const Prime_Sieve = @import("Prime_Sieve");

pub fn main() !void {
    const lastValue: u64 = 1_000_000_000;
    std.debug.print("Calculating prime numbers in the first {} digits\n", .{lastValue});
    try primeSieve(lastValue);
}

fn primeSieve(lastValue: u64) !void {
    //Using the arena allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    //The defer keyword allows you to schedule a piece of code to run when
    //the current block of code exits.
    defer arena.deinit();

    const allocator = arena.allocator();

    //Allocate the memory for the bolean array used by the seive algorithm.
    const sieveArray = try allocator.alloc(bool, lastValue);

    for (sieveArray) |*value| { //*value is a pointer to the boolean value. The loop variable is immutable by default.
        value.* = true; //dereference the pointer to get to the actual value.
    }

    //Calculate the prime values from the sieve.
    sieveArray[0] = false; //0 and 1 are not prime numbers
    sieveArray[1] = false;

    for (2..lastValue) |i| {
        if (sieveArray[i]) {
            std.debug.print("{}\n", .{i});
            var j: u64 = i * 2;
            while (j < lastValue) : (j += i) {
                sieveArray[j] = false;
            }
        }
    }
}
