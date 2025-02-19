const std = @import("std");
const output = @import("output.zig");

pub fn main() !void {
    var file = try std.fs.createFileAbsolute("/tmp/user/out.tga", .{});
    defer file.close();
    var br = std.io.bufferedWriter(file.writer());

    const data = [_]u8{120} ** (32 * 32 * 4);
    try output.writeTgaImage(32, 32, &data, .fundePixel, true, br.writer());
    try br.flush();
}
