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
	// Rotation and scaling SO(3)
	SO3, SO3_inv: Mat3,
	// Translation \( (\mathbb{R}^3, +) \)
	R3_p:         Vec3,
}

apply_tr :: proc "contextless" (v: Vec3, tr: Transform) -> Vec3 {
	return tr.R3_p + tr.SO3 * v
}

inverse_tr :: proc "contextless" (v: Vec3, tr: Transform) -> Vec3 {
	return tr.SO3_inv * (v - tr.R3_p)
}

to_homogeneous :: proc "contextless" (tr: Transform) -> (Mat4, Mat4) {
	// "If the cast is to a larger matrix type, the matrix is extended with zeros everywhere and ones in the diagonal for the unfilled elements of the extended matrix."
	forward := Mat4(tr.SO3)
	forward[0, 3] = tr.R3_p[0]
	forward[1, 3] = tr.R3_p[1]
	forward[2, 3] = tr.R3_p[2]
	inverse := Mat4(tr.SO3_inv)
	inverse[0, 3] = -tr.R3_p[0]
	inverse[1, 3] = -tr.R3_p[1]
	inverse[2, 3] = -tr.R3_p[2]
	return forward, inverse
}

from_homogeneous :: proc "contextless" (forward, inverse: Mat4) -> Transform {
	translation := Vec3{forward[0, 3], forward[1, 3], forward[2, 3]}
	return Transform{Mat3(forward), Mat3(inverse), translation}
}

tr_world_to_object :: proc "contextless" (v: Vec3, wst: Transform) -> Vec3 {
	return inverse_tr(v, wst)
}

tr_object_to_world :: proc "contextless" (v: Vec3, wst: Transform) -> Vec3 {
	return apply_tr(v, wst)
}

tr_CW_to_object :: proc "contextless" (v: Vec3, cam: ^Camera, wst: Transform) -> Vec3 {
	// IMPORTANT to not compute this as `((v + cam.pos) - wst.R3_p)`.
	// The whole point of doing rendering in camera-world space is to give most of the IEEE-754 precision to objects closer to the camera.
	// If that had been done, when both the camera and the object are really far from origin of world space, the `(v + cam.pos)` step already destroys most the precision in `v`, because `cam.pos` is a big number.
	// But by precomputing the cumulative offset, because both `cam.pos` and `wst.R3_p` are big numbers, `cum_offset` will be a small number. Then `v + cum_offset` will be a small number plus another small number, keeping most of the precision.
	wst := wst
	wst.R3_p -= cam.pos
	return inverse_tr(v, wst)
}

tr_object_to_CW :: proc "contextless" (v: Vec3, cam: ^Camera, wst: Transform) -> Vec3 {
	// # object -> world
	// We want (0,0) in object to map to `wst.R3_p` in world, so `v + wst.R3_p`
	//
	// # world -> camera-world
	// We want `camera.pos` in world to map to (0,0) in world, so `... - camera.pos`
	wst := wst
	wst.R3_p -= cam.pos
	cum_offset := wst.R3_p - cam.pos
	return apply_tr(v, wst)
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

NormalDebugMaterial :: struct {}

PureColorMaterial :: struct {
	color: Color,
}

DiffuseMaterial :: struct {
	reflectance: Color,
}

MirrorMaterial :: struct {}

SceneObject :: struct {
	shape:    union {
		Sphere,
	},
	material: union {
		NormalDebugMaterial,
		PureColorMaterial,
		DiffuseMaterial,
		MirrorMaterial,
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

// Radiance emitted by light sources.
// For all other objects, this should be 0.
light_emitted_at :: proc(so: ^SceneObject, pos, normal: Vec3) -> Color {
	#partial switch &material in so.material {
	case NormalDebugMaterial:
		return colorize_normal_vec(normal)
	case PureColorMaterial:
		return material.color
	}
	return Color{}
}

// Position in object space.
bsdf_at :: proc(so: ^SceneObject, pos, normal: Vec3, ωo, ωi: Vec3) -> Color {
	switch &material in so.material {
	case NormalDebugMaterial:
	case PureColorMaterial:
		return 0
	case DiffuseMaterial:
		// TODO reject sample if ωo and ωi are not in the same hemisphere
		// return material.reflectance / math.PI
		return material.reflectance
	case MirrorMaterial:
		return 0
	}

	return Color{}
}

sample_bsdf_at :: proc(so: ^SceneObject, pos, normal: Vec3, ωo, ωi: Vec3) -> Vec3 {
	switch &material in so.material {
	case NormalDebugMaterial:
	case PureColorMaterial:
	case DiffuseMaterial:
		// TODO
		return 0
	case MirrorMaterial:
		return 0
	}

	return Vec3{}
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
	r1, r2 := solve_quadratic_real(a, b, c)
	// Doesn't hit
	if math.is_nan(r1) {
		return r1
	}

	// Take the smaller root, that's the closer hit
	// Both positive roots, take lefter/smaller one (sphere fully in front of ray)
	if r1 > 0 do return r1
	// One negative, one positive root (ray origin inside sphere)
	if r1 < 0 && r2 > 0 do return r2
	return math.nan_f32()
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
