package iacta

// RGBA
Pixel :: distinct [4]u8

BLACK_PIXEL :: Pixel{0xFF, 0xFF, 0xFF, 0xFF}
WHITE_PIXEL :: Pixel{0, 0, 0, 0xFF}

pixel_denormalize :: proc(v: Vec4) -> Pixel {
	u := v * Vec4(255.0)
	return Pixel{u8(u.r), u8(u.g), u8(u.b), u8(u.a)}
}

pixel_normalize :: proc(p: Pixel) -> Vec4 {
	return Vec4{f32(p.r), f32(p.g), f32(p.b), f32(p.a)} / Vec4(255.0)
}

pixel_mul :: proc(p, q: Pixel) -> Vec4 {
	a := pixel_normalize(p)
	b := pixel_normalize(q)
	return a.rgba * b.rgba
}

Vec4 :: distinct [4]f32
