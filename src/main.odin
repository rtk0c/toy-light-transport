package iacta

import "core:fmt"
import stbi "vendor:stb/image"

toggle_color :: proc(col: ^Pixel) {
	if (col^ == BLACK_PIXEL) {
		col^ = WHITE_PIXEL
	} else {
		col^ = BLACK_PIXEL
	}
}

main :: proc() {
	WIDTH :: 160
	HEIGHT :: 80
	COMP :: len(Pixel(0))
	data := [WIDTH * HEIGHT]Pixel{}

	col0 := BLACK_PIXEL
	for y in 0 ..< HEIGHT {
		col := col0
		for x in 0 ..< WIDTH {
			data[y * WIDTH + x] = col
			toggle_color(&col)
		}
		toggle_color(&col0)
	}

	stbi.write_png("./out/output.png", WIDTH, HEIGHT, COMP, &data[0], size_of(data[0]) * WIDTH)
}
