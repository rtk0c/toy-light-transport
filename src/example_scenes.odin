package iacta

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
	world.skybox.sky_color = rgba(162, 224, 242, 1)

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

example_mirror_camera_setup :: proc(camera: ^Camera) {
	camera.horz_fov = 70.0 * math.RAD_PER_DEG
	camera.pos = Vec3{-3, 0, 2}
	camera_look_at(camera, Vec3{0, 0, 0})
}

example_mirror_world :: proc() -> ^World {
	world := make_world()
	world.skybox.sky_color = rgba(162, 224, 242, 1)

	add_obj :: proc(world: ^World, pos: Vec3, s: $T) {
		append(&world.scene_objects, s)
		append(&world.transforms, Transform{1, 1, pos})
	}

	// Ground
	add_obj(world, Vec3{0, 0, -50}, SceneObject{shape = Sphere{radius = 50}, material = DiffuseMaterial{reflectance = rgba(104, 186, 142, 1) }},)

	// 2 mirrors on the side showing 1 diffuse in the middle
	s05 := Sphere{radius = 0.5}
	mirror := MirrorMaterial{reflectance = Color{0.98, 0.98, 0.98, 1}}
	diff := DiffuseMaterial{reflectance = rgba(223, 141, 54, 1)}
	add_obj(world, Vec3{0, 1, 0.5}, SceneObject{shape = s05, material = mirror})
	add_obj(world, Vec3{-0.5, 0, 0.5}, SceneObject{shape = s05, material = diff})
	add_obj(world, Vec3{0, -1, 0.5}, SceneObject{shape = s05, material = mirror})

	return world
}
