const std = @import("std");
const funde = @import("fundemental.zig");

// https://en.wikipedia.org/wiki/Truevision_TGA

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
    /// 4 bytes of B, G, R, A
    color = 2,
    /// Single byte
    greyscale = 3,
    colorRle = 10,
    greyscaleRle = 11,

    const Self = @This();

    fn isRle(self: Self) u8 {
        return @intFromEnum(self) >= 10;
    }

    fn bytesPerPixel(self: Self) u8 {
        return switch (self) {
            .color => 4,
            .greyscale => 1,
            .colorRle => 4,
            .greyscaleRle => 1,
        };
    }

    fn bitsPerPixel(self: Self) u8 {
        return self.bytesPerPixel() << 3;
    }
};

fn writeRleData(
    width: u32,
    height: u32,
    data: []const u8,
    format: TgaFormat,
    w: anytype,
) !void {
    const maxRunLen = 128;
    const bpp = format.bytesPerPixel();
    const npixels = width * height;

    var currPixel: u64 = 0;
    while (currPixel < npixels) {
        const chunkStart = currPixel * bpp;
        var currByte = currPixel * bpp;
        var runLen: u8 = 1; // number of same pixels in this run
        var raw = true; // are we outputing a run?
        while (currPixel + runLen < npixels and runLen < maxRunLen) {
            // Is current pixel the same as the next one?
            var t: u8 = 0;
            while (t < bpp and data[currByte + t] == data[currByte + t + bpp]) {
                t += 1;
            }
            const neighborSame = t == bpp;

            currByte += bpp;
            if (runLen == 1) {
                raw = !neighborSame;
            }

            if (raw and neighborSame) {
                runLen -= 1;
                break;
            }
            if (!raw and !neighborSame) {
                break;
            }
            runLen += 1;
        }
        currPixel += runLen;
        try w.writeByte(if (raw) runLen - 1 else runLen + 127);
        const chunkEnd = chunkStart + if (raw) runLen * bpp else bpp;
        try w.writeAll(data[chunkStart..chunkEnd]);
    }
}

pub fn writeTgaImage(
    width: u32,
    height: u32,
    data: []const u8,
    format: TgaFormat,
    w: anytype,
) !void {
    const header = TgaHeader{
        .idLength = 0,
        .colorMapType = 0,
        .imageType = @intFromEnum(format),
        .colorMapOrigin = 0,
        .colorMapLength = 0,
        .colorMapDepth = 0,
        .xOrigin = 0,
        .yOrigin = 0,
        .width = @intCast(width),
        .height = @intCast(height),
        .bitsPerPixel = format.bitsPerPixel(),
        .imageDescriptor = 0x20, // Origin at top-left
    };

    const developerAreaRef = [_]u8{ 0, 0, 0, 0 };
    const extensionAreaRef = [_]u8{ 0, 0, 0, 0 };

    const footer = [_]u8{ 'T', 'R', 'U', 'E', 'V', 'I', 'S', 'I', 'O', 'N', '-', 'X', 'F', 'I', 'L', 'E', '.', 0 };

    try w.writeStruct(header);

    switch (format) {
        .color => {
            for (0..data.len / 4) |i| {
                // Swap RGBA to BGRA
                // i.e. swap R and B
                const off = i * 4;
                const bgra = [_]u8{ data[off + 2], data[off + 1], data[off], data[off + 3] };
                try w.writeAll(&bgra);
            }
        },
        .greyscale => {
            try w.writeAll(data);
        },
        else => {
            // TODO I think this is broken
            try writeRleData(width, height, data, format, w);
        },
    }
    try w.writeAll(&developerAreaRef);
    try w.writeAll(&extensionAreaRef);
    try w.writeAll(&footer);
}
