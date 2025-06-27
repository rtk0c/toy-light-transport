const std = @import("std");
const output = @import("output.zig");

pub fn main() !void {
    var file = try std.fs.createFileAbsolute("/tmp/user/out.tga", .{});
    defer file.close();
    var br = std.io.bufferedWriter(file.writer());

    var data = [_]u8{0} ** (32 * 32 * 4);
    var col: u8 = 0;
    for (0..(32 * 32)) |i| {
        for (0..3) |j| {
            data[i * 4 + j] = col;
        }
        data[i * 4 + 3] = 255;
        // col +%= 1;
        if (col == 0) {
            col = 255;
        } else {
            col = 0;
        }
    }
    try output.writeTgaImage(32, 32, &data, .color, br.writer());
    try br.flush();
}
