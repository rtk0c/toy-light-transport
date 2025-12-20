// Object space.
// World space.
// Camera space. Origin at camera (so rays come out of 0,0), but rotation and scaling is the same as world space.
// Camera-world space, or CW-space.

// Abbreviations
// =============
// tr		transform
// so		scene object
// wst		world space transform (of a scene object)

package iacta

import "core:fmt"
import "core:math"
import "core:math/linalg"

Transform :: struct {
	pos: Vec3,
}

tr_world_to_object :: proc(v: Vec3, wst: Transform) -> Vec3 {
	return v - wst.pos
}

tr_object_to_world :: proc(v: Vec3, wst: Transform) -> Vec3 {
	return wst.pos + v
}

tr_CW_to_object :: proc(v: Vec3, cam: ^Camera, wst: Transform) -> Vec3 {
	// IMPORTANT to not compute this as `((v + cam.pos) - wst.pos)`.
	// The whole point of doing rendering in camera-world space is to give most of the IEEE-754 precision to objects closer to the camera.
	// If that had been done, when both the camera and the object are really far from origin of world space, the `(v + cam.pos)` step already destroys most the precision in `v`, because `cam.pos` is a big number.
	// But by precomputing the cumulative offset, because both `cam.pos` and `wst.pos` are big numbers, `cum_offset` will be a small number. Then `v + cum_offset` will be a small number plus another small number, keeping most of the precision.
	cum_offset := -wst.pos + cam.pos
	return v + cum_offset
}

tr_object_to_CW :: proc(v: Vec3, cam: ^Camera, wst: Transform) -> Vec3 {
	// # object -> world
	// We want (0,0) in object to map to `wst.pos` in world, so `v + wst.pos`
	//
	// # world -> camera-world
	// We want `camera.pos` in world to map to (0,0) in world, so `... - camera.pos`
	cum_offset := wst.pos - cam.pos
	return v + cum_offset
}

// A ray modeled by equation \( P(t) = x_0 + dt \)
// where \(x_0\) is `origin`, \(d\) is `dir`.
Ray :: struct {
	origin: Vec3,
	dir:    Vec3,
}

ray_at :: proc(ray: Ray, t: f32) -> Vec3 {
	return ray.origin + ray.dir * t
}

ray_tr_CW_to_object :: proc(ray: Ray, cam: ^Camera, wst: Transform) -> Ray {
	return Ray{tr_CW_to_object(ray.origin, cam, wst), ray.dir}
}

ray_tr_object_to_CW :: proc(ray: Ray, cam: ^Camera, wst: Transform) -> Ray {
	return Ray{tr_object_to_CW(ray.origin, cam, wst), ray.dir}
}

// Discussion of entity storage
// ============================
// Current architecture is essentially subtype polymorphism.
// The alternative is ECS over 3 components
//
// - Transform
// - Union[shapes, ...]
// - Union[materials, ...]
//
// The problem is that, the ray tracing logic needs to indiscriminately look at all objects for intersection.
// There is no (obvious?) way to have systems, because everything has to go into the same accelaration structure.
// There is no way to process entities by type: all spheres at once, all triangle meshes at once, etc.

SceneObject :: struct {
	shape:    union {
		Sphere,
	},
	material: union {
		NormalDebugMaterial,
		PureColorMaterial,
	},
}

// Position in object space.
surface_normal_at :: proc(so: ^SceneObject, pos: Vec3) -> Vec3 {
	switch &shape in so.shape {
	case Sphere:
		return sphere_surface_normal_at(&shape, pos)
	}

	return Vec3{}
}

// Position in object space.
material_contribution_at :: proc(so: ^SceneObject, pos, normal: Vec3) -> Color {
	switch &material in so.material {
	case NormalDebugMaterial:
		return colorize_normal_vec(normal)
	case PureColorMaterial:
		return material.color
	}

	return Color{}
}

// Ray in object space.
ray_hits :: proc(ray: Ray, so: ^SceneObject) -> f32 {
	switch &shape in so.shape {
	case Sphere:
		return sphere_ray_hits(ray, &shape)
	}

	return math.nan_f32()
}

Sphere :: struct {
	radius: f32,
}

sphere_surface_normal_at :: proc(sphere: ^Sphere, pt: Vec3) -> Vec3 {
	return linalg.normalize(pt)
}

sphere_ray_hits :: proc(ray: Ray, sphere: ^Sphere) -> f32 {
	ro := ray.origin
	rd := ray.dir

	r := sphere.radius

	a := linalg.dot(rd, rd)
	b := 2 * linalg.dot(rd, ro)
	c := linalg.dot(ro, ro) - r * r
	r1, _ := solve_quadratic_real(a, b, c)
	// Doesn't hit
	if math.is_nan(r1) {
		return r1
	}
	// Take the smaller root, that's the closer hit
	return r1
}

SkyBox :: struct {
	sky_color: Color,
}

World :: struct {
	skybox:        SkyBox,
	scene_objects: [dynamic]SceneObject,
	transforms:    [dynamic]Transform,
}

make_world :: proc() -> ^World {
	w := new(World)
	w.scene_objects = make([dynamic]SceneObject)
	return w
}
