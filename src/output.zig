const std = @import("std");
const funde = @import("fundemental.zig");

// Laied out in TGA order
pub const TgaPixel = packed struct {
    b: u8,
    g: u8,
    r: u8,
    a: u1,
};

pub const TgaHeader = packed struct {
    // field 1 - 1 byte
    idLength: u8,
    // field 2 - 1 byte
    colorMapType: u8,
    // field 3 - 5 bytes
    imageType: u8,
    colorMapOrigin: i16,
    colorMapLength: i16,
    // field 4 - 11 bytes
    colorMapDepth: u8,
    xOrigin: i16,
    yOrigin: i16,
    width: i16,
    height: i16,
    bitsPerPixel: u8,
    imageDescriptor: u8,
};

pub const TgaFormat = enum(u8) {
    //==== TGA encoded ====//
    /// Single byte
    grayscale = 1,
    /// 3 bytes of B, G, R
    rgb = 3,
    /// 4 bytes of B, G, R, A
    rgba = 4,
    /// 4 bytes of R, G, B, A
    fundePixel = 255,

    const Self = @This();

    fn bitsPerPixel(self: Self) u8 {
        return self << 3;
    }
};

pub fn writeTgaImage(
    width: u32,
    height: u32,
    data: []const u8,
    format: TgaFormat,
    runLengthEncoding: bool,
    outPath: []const u8,
) void {
    comptime {
        if (width * height != data.len)
            @compileError("width and height must make up for all the pixel data");
    }

    const file = try std.fs.openFileAbsolute(outPath, .{});
    defer file.close();
    var br = try std.io.bufferedWriter(file);

    var header = TgaHeader{};
    header.bitsPerPixel = format.bitsPerPixel();
    header.width = width;
    header.height = height;
    header.imageType = if (format == .grayscale)
        if (runLengthEncoding) 11 else 3
    else if (runLengthEncoding) 10 else 2;
    header.imageDescriptor = 0x20; // Origin at top-left

    const developerAreaRef = []u8{ 0, 0, 0, 0 };
    const extensionAreaRef = []u8{ 0, 0, 0, 0 };

    const footer = []u8{ 'T', 'R', 'U', 'E', 'V', 'I', 'S', 'I', 'O', 'N', '-', 'X', 'F', 'I', 'L', 'E', '.', 0 };

    br.write(std.mem.asBytes(header));
    if (runLengthEncoding) {
        // TODO
    } else if (format == .fundePixel) {
        for (0..data.len / 4) |i| {
            // Swap RGBA to BGRA
            // i.e. swap R and B
            const off = i * 4;
            const bgra = [_]u8{ data[off + 2], data[off + 1], data[off], data[off + 3] };
            br.write(bgra);
        }
    } else {
        br.write(data);
    }
    br.write(developerAreaRef);
    br.write(extensionAreaRef);
    br.write(footer);
}
