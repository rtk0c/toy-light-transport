package iacta

import "core:math"
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

	// TODO controllable from cli arg
	image_width := 160
	image_height := 90
	image_aspect_ratio := f32(image_width) / f32(image_height)

	camera := make_camera()
	camera.pos = Vec3{-3 + 1000000000000, -3, 2}
	camera.horz_fov = 70.0 * math.RAD_PER_DEG
	camera.aspect_ratio = image_aspect_ratio
	camera_look_at(&camera, Vec3{1000000000000, 0, 0})

	world := make_world()
	world.skybox.sky_color = pixel_normalize(Pixel{162, 224, 242, 0xFF})

	add_obj :: proc(world: ^World, pos: Vec3, s: $T) {
		append(&world.scene_objects, s)
		append(&world.transforms, Transform{pos = pos})
	}
	add_obj(
		world,
		Vec3{1000000000000, 0, -50},
		SceneObject {
			shape = Sphere{radius = 50},
			material = PureColorMaterial{color = pixel_normalize(RED_PIXEL)},
		},
	)

	add_obj_s :: proc(world: ^World, pos: Vec3, s: $T) {
		add_obj(world, pos, SceneObject{shape = s, material = NormalDebugMaterial{}})
	}
	add_obj_s(world, Vec3{1000000000000, 0, 0.5}, Sphere{radius = 0.5})
	add_obj_s(world, Vec3{1000000000000, 1, 0.5}, Sphere{radius = 0.5})
	add_obj_s(world, Vec3{1000000000000, -1, 0.5}, Sphere{radius = 0.5})

	image := make([dynamic]Pixel, image_width * image_height)
	render(
		&camera,
		world,
		samples_per_pixel = 16,
		viewport_width = image_width,
		viewport_height = image_height,
		image = image[:],
	)

	stbi.write_png(
		"./out/output.png",
		i32(image_width),
		i32(image_height),
		len(Pixel(0)),
		&image[0],
		i32(size_of(image[0]) * image_width),
	)
}
