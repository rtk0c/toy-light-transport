const std = @import("std");
const output = @import("output.zig");

pub fn main() !void {
    const data = [_]u8{255} ** (32 * 32 * 4);
    output.writeTgaImage(32, 32, &data, .fundePixel, false, "out.tga");
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
