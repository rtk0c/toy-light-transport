package iacta

import "core:fmt"
import "core:math"
import "core:math/linalg"

example_basic_camera_setup :: proc(camera: ^Camera) {
	camera.horz_fov = 70.0 * math.RAD_PER_DEG
	camera.pos = Vec3{-3, -3, 2}
	// TODO fix if camera is looking directly down, everything vanishes
	// camera.pos = Vec3{0, 0.001, 3}
	camera_look_at(camera, Vec3{0, 0, 0})
}

example_basic_world :: proc() -> ^World {
	world := make_world()
	world.skybox.sky_color = rgb(162, 224, 242)

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
			material = DiffuseMaterial{reflectance = rgb(104, 186, 142) },
			// material = NormalDebugMaterial{},
		},
	)

	add_obj_s :: proc(world: ^World, pos: Vec3, s: $T) {
		add_obj_p(world, pos, SceneObject{shape = s, material = m})
	}
	m1 := DiffuseMaterial{reflectance = 0.8}
	m1orange := DiffuseMaterial{reflectance = rgb(223, 141, 54) }
	m2 := PureColorMaterial{color = rgb(223, 141, 54)  }
	m3 := NormalDebugMaterial{}
	s05 := Sphere{radius = 0.5}
	// add_obj_s(world, Vec3{0, 0, 0}, Sphere{radius = 0.5})
	add_obj_p(world, Vec3{0, 1, 0.5}, SceneObject{shape = s05, material = m1})
	// add_obj_p(world, Vec3{0, 0, 0.5}, SceneObject{shape = s05, material = m2})
	add_obj_p(world, Vec3{0, -1, 0.5}, SceneObject{shape = s05, material = m1orange})
	rot: Mat3
	// rot = linalg.matrix3_rotate(math.PI/2, Vec3{1,1,1})
	// add_obj(world, Transform{rot, linalg.inverse(rot), Vec3{0, 1, 0.5}}, SceneObject{shape = s05, material = m3})
	rot = linalg.matrix3_rotate(0.1, Vec3{1,1,1})
	add_obj(world, Transform{rot, linalg.inverse(rot), Vec3{0, 0, 0.5}}, SceneObject{shape = s05, material = m3})
	// rot = linalg.matrix3_rotate(math.PI*3/2, Vec3{1,1,1})
	// add_obj(world, Transform{rot, linalg.inverse(rot), Vec3{0, -1, 0.5}}, SceneObject{shape = s05, material = m3})

	return world
}

example_basic :: proc() -> (image: [dynamic]Color, width, height: int) {
	width = 16*80
	height = 9*80
	image = make([dynamic]Color, width * height)

	world := example_basic_world()

	camera := make_camera()
	camera.aspect_ratio = f32(width) / f32(height)
	example_basic_camera_setup(&camera)

	rp := RenderParams{
		cam = &camera,
		world = world,
		samples_per_pixel = 20,
		max_bounces = 10,

		viewport_width = width, 
		viewport_height = height,
	}
	rt := make_default_render_target(image[:], &rp)
	render(&rp, &rt)

	return
}

example_mirror_camera_setup :: proc(camera: ^Camera) {
	camera.horz_fov = 70.0 * math.RAD_PER_DEG
	camera.pos = Vec3{-3, 0, 2}
	camera_look_at(camera, Vec3{0, 0, 0})
}

example_mirror_world :: proc() -> ^World {
	world := make_world()
	world.skybox.sky_color = rgb(162, 224, 242)

	add_obj :: proc(world: ^World, pos: Vec3, s: $T) {
		append(&world.scene_objects, s)
		append(&world.transforms, Transform{1, 1, pos})
	}

	// Ground
	add_obj(world, Vec3{0, 0, -50}, SceneObject{shape = Sphere{radius = 50}, material = DiffuseMaterial{reflectance = rgb(104, 186, 142) }},)

	// 2 mirrors on the side showing 1 diffuse in the middle
	s05 := Sphere{radius = 0.5}
	mirror := MirrorMaterial{reflectance = Color{0.98, 0.98, 0.98, 1}}
	diff := DiffuseMaterial{reflectance = rgb(223, 141, 54)}
	add_obj(world, Vec3{0, 1, 0.5}, SceneObject{shape = s05, material = mirror})
	add_obj(world, Vec3{-0.5, 0, 0.5}, SceneObject{shape = s05, material = diff})
	add_obj(world, Vec3{0, -1, 0.5}, SceneObject{shape = s05, material = mirror})

	return world
}

example_mirror :: proc() -> (image: [dynamic]Color, width, height: int) {
	width = 16*20
	height = 9*20
	image = make([dynamic]Color, width * height)

	world := example_mirror_world()

	camera := make_camera()
	camera.aspect_ratio = f32(width) / f32(height)
	example_mirror_camera_setup(&camera)

	rp := RenderParams{
		cam = &camera,
		world = world,
		samples_per_pixel = 50,
		max_bounces = 10,

		viewport_width = width, 
		viewport_height = height,
	}
	rt := make_default_render_target(image[:], &rp)
	render(&rp, &rt)

	return
}

example_gamma_test_camera_setup :: proc(camera: ^Camera) {
	camera.focal_length = 1
	camera.horz_fov = 90.0 * math.RAD_PER_DEG
	camera.pos = Vec3{0, 1.5, 0}
	camera.view = Vec3{0, -1, 0}
}

example_gamma_test_world :: proc() -> ^World {
	world := make_world()
	world.skybox.sky_color = rgb(128, 178, 255)

	diffuse := DiffuseMaterial{reflectance = rgb(127, 127, 127)}
	// Object to look at
	append(&world.scene_objects, SceneObject{shape = Sphere{radius = 0.5}, material = diffuse})
	append(&world.transforms, Transform{1, 1, Vec3{0, 0, 0}})
	// Ground
    append(&world.scene_objects, SceneObject{shape = Sphere{radius = 100}, material = diffuse})
	append(&world.transforms, Transform{1, 1, Vec3{0, 0, -100.5}})

	return world
}

example_gamma_test :: proc() -> (image: [dynamic]Color, width, height: int) {
	width = 16*20 // when changing this, keep a factor of 5 so we don't get rounding errors :)
	height = 9*20
	image = make([dynamic]Color, width * height)

	world := example_gamma_test_world()

	camera := make_camera()
	camera.aspect_ratio = f32(width) / f32(height)
	example_gamma_test_camera_setup(&camera)

	rp := RenderParams{
		cam = &camera,
		world = world,
		samples_per_pixel = 50,
		max_bounces = 10,

		viewport_width = width,
		viewport_height = height,
	}
	
	reflectances := [?]f32{ 0.1, 0.3, 0.5, 0.7, 0.9 }
	section_width := width / len(reflectances)

	rt := RenderTarget{
		storage = image[:],
		line_stride = width,
		t_y0 = 0,
		t_y1 = height,
	}
	
	for i in 0 ..< len(reflectances) {
		// if i == 0 do continue
		for &so in world.scene_objects {
			so.material = DiffuseMaterial{reflectance = reflectances[i]}
		}
		rt.t_x0 = i * section_width
		rt.t_x1 = (i+1) * section_width
		render(&rp, &rt)
	}

	return
}
