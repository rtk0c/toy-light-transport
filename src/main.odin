package iacta

import "core:fmt"
import "core:math"
import "core:math/linalg"
import stbi "vendor:stb/image"

inverse_only_color :: proc(col: ^Pixel) {
	for i in 0 ..= 2 {
		col^[i] = 0xFF - col^[i]
	}
}

main :: proc() {
	VP_WIDTH :: 160
	VP_HEIGHT :: 80
	ASPECT_RATIO :: VP_WIDTH / VP_HEIGHT

	COMP :: len(Pixel(0))
	data := [VP_WIDTH * VP_HEIGHT]Pixel{}

	sphere := new(Sphere)
	sphere.center = Vec3{0, 0, 0}
	sphere.radius = 0.5

	sphere_color := RED_PIXEL
	sky_color := Pixel{162, 224, 242, 0xFF}

	camera := make_camera()
	camera.pos = Vec3{-2, 0, 1}
	camera_look_at(&camera, Vec3{0, 0, 0})

	camera.focal_distance = 1.0
	camera.viewport_height = 1.0
	camera.viewport_width = camera.viewport_height * ASPECT_RATIO

	// Just get a slightly different vector, on the same vertical plane
	camera_view_flat := camera.view
	camera_view_flat.z = -camera_view_flat.z
	// Viewport coordiante: TV style, aka X right, Y down
	vp_horz_vec :=
		linalg.normalize(linalg.cross(camera.view, camera_view_flat)) * camera.viewport_width
	vp_vert_vec :=
		linalg.normalize(linalg.cross(camera.view, vp_horz_vec)) * camera.viewport_height
	vp_origin :=
		camera.pos + camera.view * camera.focal_distance - vp_horz_vec / 2 - vp_vert_vec / 2

	pixel_delta_x := vp_horz_vec / VP_WIDTH
	pixel_delta_y := vp_vert_vec / VP_HEIGHT

	for y in 0 ..< VP_HEIGHT {
		row_offset := y * VP_WIDTH
		for x in 0 ..< VP_WIDTH {
			offset := row_offset + x

			pixel_center :=
				vp_origin + pixel_delta_x * (f32(x) + 0.5) + pixel_delta_y * (f32(y) + 0.5)
			view_ray := Ray{camera.pos, pixel_center - camera.pos}

			t := ray_intersects(&view_ray, sphere)
			if math.is_nan(t) {
				data[offset] = sky_color
			} else {
				data[offset] = sphere_color
			}
		}
	}

	stbi.write_png(
		"./out/output.png",
		VP_WIDTH,
		VP_HEIGHT,
		COMP,
		&data[0],
		size_of(data[0]) * VP_WIDTH,
	)
}
