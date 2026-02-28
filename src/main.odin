package iacta

import "core:math"
import "core:math/linalg"
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
	camera.pos = Vec3{-3, -3, 2}
	// TODO fix if camera is looking directly down, everything vanishes
	// camera.pos = Vec3{0, 0.001, 3}
	camera.horz_fov = 70.0 * math.RAD_PER_DEG
	camera.aspect_ratio = image_aspect_ratio
	camera_look_at(&camera, Vec3{0, 0, 0})

	world := make_world()
	world.skybox.sky_color = pixel_normalize(Pixel{162, 224, 242, 0xFF})

	add_obj :: proc(world: ^World, t: Transform, s: $T) {
		append(&world.scene_objects, s)
		append(&world.transforms, t)
	}
	add_obj_p :: proc(world: ^World, pos: Vec3, s: $T) {
		add_obj(world, Transform{1, 1, pos}, s)
	}
	add_obj_p(
		world,
		Vec3{0, 0, -50},
		SceneObject {
			shape = Sphere{radius = 50},
			// material = DiffuseMaterial{reflectance = 0.5},
			material = DiffuseMaterial{reflectance = rgba(104, 186, 142, 1) },
			// material = NormalDebugMaterial{},
		},
	)

	add_obj_s :: proc(world: ^World, pos: Vec3, s: $T) {
		add_obj_p(world, pos, SceneObject{shape = s, material = m})
	}
	m1 := DiffuseMaterial{reflectance = 0.8}
	m1orange := DiffuseMaterial{reflectance = rgba(223, 141, 54, 1) }
	m2 := PureColorMaterial{color = rgba(223, 141, 54, 1)  }
	m3 := NormalDebugMaterial{}
	s05 := Sphere{radius = 0.5}
	// add_obj_s(world, Vec3{0, 0, 0}, Sphere{radius = 0.5})
	add_obj_p(world, Vec3{0, 1, 0.5}, SceneObject{shape = s05, material = m1})
	rot := linalg.matrix3_rotate(0.1, Vec3{1,1,1})
	add_obj(world, Transform{rot, linalg.inverse(rot), Vec3{0, 0, 0.5}}, SceneObject{shape = s05, material = m3})
	add_obj_p(world, Vec3{0, -1, 0.5}, SceneObject{shape = s05, material = m1orange})

	image := make([dynamic]Pixel, image_width * image_height)
	render(
		&camera,
		world,
		samples_per_pixel = 50,
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
