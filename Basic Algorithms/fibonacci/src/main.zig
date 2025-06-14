const std = @import("std");
const fibonacci = @import("fibonacci");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    const count: u8 = 90;
    std.debug.print("Calculating fibonacci up to the {} digit\n", .{count});
    var digit: usize = 0;
    for (1..count + 1) |i| {
        digit = calculateFibonacci(i);
        std.debug.print("{}:{}\n", .{ i, digit });
    }
}

fn calculateFibonacci(value: usize) usize {
    var previousValue: usize = 0;
    var currentValue: usize = 1;
    var nextValue: usize = 0;

    for (1..value) |_| {
        nextValue = previousValue + currentValue;
        previousValue = currentValue;
        currentValue = nextValue;
    }
    return previousValue;
}
