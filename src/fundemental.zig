const zl = @import("zalgebra");

pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    const Self = @This();

    pub inline fn nm(self: Self) zl.Vec4 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    const Self = @This();

    pub inline fn fix(self: Self) Pixel {
        return .{
            .r = @intFromFloat(self.x * 255),
            .g = @intFromFloat(self.y * 255),
            .b = @intFromFloat(self.z * 255),
            .a = @intFromFloat(self.w * 255),
        };
    }
};

pub fn pixmul(p: Pixel, q: Pixel) Vec4 {
    const p_ = p.nm();
    const q_ = q.nm();
    return .{
        .r = p_.x * q_.x,
        .g = p_.y * q_.y,
        .b = p_.z * q_.z,
        .a = p_.w * q_.w,
    };
}
