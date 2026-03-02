package iacta

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"

Camera :: struct {
	// Camera position, in world space.
	pos:          Vec3,

	// Up, a unit vector in world space.
	// Used to determine roll, whereas yaw and pitch is determined by `view`.
	up:           Vec3,

	// View direction, a unit vector, origined at the camera. (NOT world space)
	// i.e. if looking parallel to +X direction, this would be Vec3{1,0,0}
	view:         Vec3,

	// Distance from camera position to the viewport plane ("near plane" in RT rendering convention)
	focal_length: f32,

	// Horizontal FOV of the camera.
	horz_fov:     f32,

	// width/height
	aspect_ratio: f32,
}

make_camera :: proc() -> Camera {
	return Camera {
		pos = Vec3{0, 0, 0},
		up = Vec3{0, 0, 1},
		view = Vec3{1, 0, 0},
		focal_length = 1.0,
	}
}

// Look at a point in world space, without changing the focal distance.
camera_look_at :: proc(cam: ^Camera, pt: Vec3) {
	cam.view = linalg.normalize(pt - cam.pos)
}

Intersection :: struct {
	// Which object did we hit?
	obj_id: int,
	// Where is the intersection, as parameter t along the ray \( P(t) = x_0 + dt \)? (The ray used to generated this intersection.)
	// Note that t is independent of the coordinate system, i.e. stays the same whether the ray is represented in camera-world space or object space.
	t:      f32,
	// Where is the intersection, in view-world space?
	pt:     Point3,
	// Surface normal at the point of intersection
	normal: Normal3,
}

isect_empty :: proc(isect: Intersection) -> bool {
	return isect.obj_id == -1
}

// Generate new ray, relative to the tip of surface normal at intersection.
// Returned Ray in camera-world space.
isect_spawn_ray :: proc(isect: Intersection, v: Vec3) -> Ray {
	return Ray{origin = isect.pt, dir = Vec3(isect.normal)}
}

intersect_ray_with_world :: proc(cam: ^Camera, world: ^World, ray: Ray) -> Intersection {
	isect := Intersection{}
	isect.obj_id = -1
	isect.t = math.inf_f32(+1)

	for i in 0 ..< len(world.scene_objects) {
		so := &world.scene_objects[i]
		wst := world.transforms[i]

		ray_obj_space := ray_tr_CW_to_object(ray, cam, wst)
		// ray-object hit test happens in object space, because it's easier to treat in the geometry code
		t := ray_hits(ray_obj_space, so)

		if !math.is_nan(t) && t < isect.t {
			isect.obj_id = i
			isect.t = t
			// But now, we care about the camera-world space intersection point, so calculate it on the original ray.
			isect.pt = ray_at(ray, t)
			isect.normal = surface_normal_at(so, ray_at(ray_obj_space, t))
		}
	}

	return isect
}

DEFAULT_MAX_BOUNCES :: 10

integrate_camera_ray :: proc(
	cam: ^Camera,
	world: ^World,
	ray: Ray,
	remaining_bounces: int = DEFAULT_MAX_BOUNCES,
) -> Color {
	isect := intersect_ray_with_world(cam, world, ray)
	if isect_empty(isect) {
		return world.skybox.sky_color
	}

	so := &world.scene_objects[isect.obj_id]
	wst := world.transforms[isect.obj_id]

	// Also in object space
	hit_pt := tr_CW_to_object(isect.pt, cam, wst)
	hit_normal := isect.normal
	light_emitted := light_emitted_at(so, hit_pt, hit_normal)

	// At recursion limit, just return current contribution
	if remaining_bounces <= 0 {
		return light_emitted
	}

	ωo := -ray.dir
	ωp := rand_unit_vec()

	// Otherwise, continue to next bounce
	next_ray := isect_spawn_ray(isect, ωp)
	fcos := bsdf_at(so, hit_pt, hit_normal, ωo, ωp) // * math.abs(linalg.dot(hit_normal, ωp))
	if fcos == 0.0 {
		return light_emitted
	}
	light_scattered :=
		light_emitted + fcos * integrate_camera_ray(cam, world, next_ray, remaining_bounces - 1)

	return light_scattered
}

render :: proc(
	cam: ^Camera,
	world: ^World,
	samples_per_pixel: int,

	// Dimension of the rendered image, in pixels.
	// Aspect ratio `f32(viewport_width) / f32(viewport_height)` should match the `Camera.aspect_ratio` used for rendering.
	// `viewport_width * viewport_height` should match length of `image`.
	viewport_width, viewport_height: int,
	image: []Pixel,
) {
	// In camera-world space, shoot rays and perform intersection tests.
	// In object space, do radiometry stuff.

	// Dimensions (in world space) of the focal plane
	fp_width := 2 * cam.focal_length * math.tan(cam.horz_fov / 2)
	fp_height := fp_width / cam.aspect_ratio

	// Orthonormal basis i,j,k for camera space.

	// k is Y-dierction basis, forward in camera space
	cam_k := linalg.normalize(cam.view)
	// i is X-direction basis, pointing to the *right* in camera space
	cam_i := linalg.normalize(linalg.cross(cam.view, cam.up))
	// j is Z-direction basis, pointing to the *top* in camera space
	cam_j := linalg.cross(cam_i, cam_k)

	vp_horz := cam_i * fp_width
	vp_vert := -cam_j * fp_height
	vp_origin := cam.view * cam.focal_length - vp_horz / 2 - vp_vert / 2

	pixel_delta_x := vp_horz / f32(viewport_width)
	pixel_delta_y := vp_vert / f32(viewport_height)

	sample_scaling_factor := 1 / f32(samples_per_pixel)

	for y in 0 ..< viewport_height {
		for x in 0 ..< viewport_width {
			accum := Color{}
			for _ in 0 ..< samples_per_pixel {
				sample_x_off := rand.float32_uniform(0, 1)
				sample_y_off := rand.float32_uniform(0, 1)

				pixel_center :=
					vp_origin +
					pixel_delta_x * (f32(x) + sample_x_off) +
					pixel_delta_y * (f32(y) + sample_y_off)

				// In camera-world space
				ray := Ray{Point3(0), pixel_center}

				c := integrate_camera_ray(cam, world, ray)
				// Radiance doesn't carry alpha. In any rendered image, the final alpha must be 1.
				// For convenience the light transport code path also uses the 4-component RGBA color, but the alpha channel could be removed.
				c.a = 1.0
				accum += c
			}

			pixel_color := accum * sample_scaling_factor
			image[y * viewport_width + x] = pixel_denormalize(pixel_color)
		}
	}
}
