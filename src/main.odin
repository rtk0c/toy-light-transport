package iacta

import "core:math/rand"
import stbi "vendor:stb/image"

inverse_only_color :: proc(col: ^Pixel) {
	for i in 0 ..= 2 {
		col^[i] = 0xFF - col^[i]
	}
}

main :: proc() {
	// Use fixed RNG seed for reproducible rendering results
	rand.reset(0x531864e09a8e25d6)

	image, image_width, image_height := example_mirror()

	// Gamma correction
	// TODO image looks right with this off, but wrong with this on?
	ENABLE_GAMMA_CORRECTION :: true
	when ENABLE_GAMMA_CORRECTION {
		for &pixel in image {
			pixel = linear_to_gamma_sqrt(pixel)
		}
	}

	// [4]f32 to [4]u8 format conversoin
	image_pixels := make([]Pixel, len(image))
	for i in 0..<len(image) {
		image_pixels[i] = pixel_denormalize(image[i])
	}

	stbi.write_png(
		"./out/output.png",
		i32(image_width),
		i32(image_height),
		len(Pixel(0)),
		&image_pixels[0],
		i32(size_of(image_pixels[0]) * image_width),
	)
}
