package iacta

import "core:strings"
import "core:fmt"
import "core:math"
import "core:math/rand"
import stbi "vendor:stb/image"

inverse_only_color :: proc(col: ^Pixel) {
	for i in 0 ..= 2 {
		col^[i] = 0xFF - col^[i]
	}
}

do_render :: proc(offset: int) {
	x := f32(offset)

	// Use fixed RNG seed for reproducible rendering results
	rand.reset(0x531864e09a8e25d6)

	// TODO controllable from cli arg
	image_width := 160
	image_height := 90
	image_aspect_ratio := f32(image_width) / f32(image_height)

	camera := make_camera()
	camera.pos = Vec3{x - 3, -3, 2}
	camera.horz_fov = 70.0 / 180 * math.PI
	camera.aspect_ratio = image_aspect_ratio
	camera_look_at(&camera, Vec3{x, 0, 0})

	world := make_world()
	world.skybox.sky_color = pixel_normalize(Pixel{162, 224, 242, 0xFF})
	add_obj :: proc(world: ^World, s: $T) {
		append(&world.scene_objects, SceneObject{shape = s, material = NormalDebugMaterial{}})
	}
	add_obj(world, Sphere{center = Vec3{x, 0, 0.5}, radius = 0.5})
	add_obj(world, Sphere{center = Vec3{x, 1, 0.5}, radius = 0.5})
	add_obj(world, Sphere{center = Vec3{x, -1, 0.5}, radius = 0.5})
	append(
		&world.scene_objects,
		SceneObject {
			shape = Sphere{center = Vec3{x, 0, -50}, radius = 50},
			material = PureColorMaterial{color = pixel_normalize(RED_PIXEL)},
		},
	)


	image := make([dynamic]Pixel, image_width * image_height)
	render(
		&camera,
		world,
		samples_per_pixel = 16,
		viewport_width = image_width,
		viewport_height = image_height,
		image = image[:],
	)

	filename := fmt.aprintf("./out/output%d.png", offset)

	stbi.write_png(
		strings.clone_to_cstring(filename),
		i32(image_width),
		i32(image_height),
		len(Pixel(0)),
		&image[0],
		i32(size_of(image[0]) * image_width),
	)
}

main :: proc() {
	offsets := []int{0, 1000, 1_000_000, 1_000_000_000}
	for offset in offsets {
		do_render(offset)
	}
}
