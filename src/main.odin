package iacta

import "core:fmt"
import stbi "vendor:stb/image"

inverse_only_color :: proc(col: ^Pixel) {
	for i in 0 ..= 2 {
		col^[i] = 0xFF - col^[i]
	}
}

main :: proc() {
	WIDTH :: 160
	HEIGHT :: 80
	COMP :: len(Pixel(0))
	data := [WIDTH * HEIGHT]Pixel{}

	col0 := Pixel{0,255,0,255}
	for y in 0 ..< HEIGHT {
		col := col0
		for x in 0 ..< WIDTH {
			data[y * WIDTH + x] = col
			inverse_only_color(&col)
		}
		inverse_only_color(&col0)
	}

	stbi.write_png("./out/output.png", WIDTH, HEIGHT, COMP, &data[0], size_of(data[0]) * WIDTH)
}
