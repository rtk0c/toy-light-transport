package iacta

import "core:fmt"
import stbi "vendor:stb/image"

main :: proc() {
	WIDTH :: 32
	HEIGHT :: 32
	COMP :: 4 // rgba
	data := []u8 {
		0 ..< (WIDTH * HEIGHT * 4) = 0,
	}
	col: u8 = 0
    // black and white grid
	for i in 0 ..< WIDTH * HEIGHT {
		for j in 0 ..< COMP - 1 {
			data[i * COMP + j] = col
		}
		data[i * COMP + (COMP - 1)] = 255
		if (col == 0) {
			col = 255
		} else {
			col = 0
		}
	}

	stbi.write_png("./out/grid.png", WIDTH, HEIGHT, COMP, &data, size_of(data[0]) * COMP)
}
