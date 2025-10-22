package iacta

import "core:fmt"
import stbi "vendor:stb/image"

toggle_color :: proc(col: ^u8) {
	if (col^ == 0) {
		col^ = 0xFF
	} else {
		col^ = 0
	}
}

main :: proc() {
	WIDTH :: 160
	HEIGHT :: 80
	COMP :: 3 // rgb
	data := []u8 {
		0 ..< (WIDTH * HEIGHT * COMP) = 0,
	}
	col0: u8 = 0
	// black and white grid
	for y in 0 ..< HEIGHT {
		col := col0
		for x in 0 ..< WIDTH {
			for i in 0 ..< COMP {
				data[(y * WIDTH + x) * COMP + i] = col
			}
			toggle_color(&col)
		}
		toggle_color(&col0)
	}

	stbi.write_png(
		"./out/output.png",
		WIDTH,
		HEIGHT,
		COMP,
		&data[0],
		size_of(data[0]) * COMP * WIDTH,
	)
}
