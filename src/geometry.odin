#+feature using-stmt

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

forward_tr :: proc{forward_tr_vec, forward_tr_normal, forward_tr_point}
forward_tr_vec :: proc "contextless" (v: Vec3, tr: Transform) -> Vec3 {return tr.SO3 * v}
forward_tr_normal :: proc "contextless" (v: Normal3, tr: Transform) -> Normal3 {return tr.SO3_inv * v}
forward_tr_point :: proc "contextless" (v: Point3, tr: Transform) -> Point3 {return Point3(tr.R3_p + tr.SO3 * Vec3(v))}

inverse_tr :: proc{inverse_tr_vec, inverse_tr_normal, inverse_tr_point}
inverse_tr_vec :: proc "contextless" (v: Vec3, tr: Transform) -> Vec3 {	return tr.SO3_inv * v}
inverse_tr_normal :: proc "contextless" (v: Normal3, tr: Transform) -> Normal3 {return tr.SO3 * v}
inverse_tr_point :: proc "contextless" (v: Point3, tr: Transform) -> Point3 {return Point3(tr.SO3_inv * (Vec3(v) - tr.R3_p))}

transform_to_homogeneous :: proc "contextless" (tr: Transform) -> (Mat4, Mat4) {
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

transform_from_homogeneous :: proc "contextless" (forward, inverse: Mat4) -> Transform {
	translation := Vec3{forward[0, 3], forward[1, 3], forward[2, 3]}
	return Transform{Mat3(forward), Mat3(inverse), translation}
}

tr_world_to_object :: proc "contextless" (v: $T, wst: Transform) -> T {
	return inverse_tr(v, wst)
}

tr_object_to_world :: proc "contextless" (v: $T, wst: Transform) -> T {
	return forward_tr(v, wst)
}

tr_CW_to_object :: proc "contextless" (v: $T, cam: ^Camera, wst: Transform) -> T {
	// IMPORTANT to not compute this as `((v + cam.pos) - wst.R3_p)`.
	// The whole point of doing rendering in camera-world space is to give most of the IEEE-754 precision to objects closer to the camera.
	// If that had been done, when both the camera and the object are really far from origin of world space, the `(v + cam.pos)` step already destroys most the precision in `v`, because `cam.pos` is a big number.
	// But by precomputing the cumulative offset, because both `cam.pos` and `wst.R3_p` are big numbers, `cum_offset` will be a small number. Then `v + cum_offset` will be a small number plus another small number, keeping most of the precision.
	wst := wst
	wst.R3_p -= cam.pos
	return inverse_tr(v, wst)
}

tr_object_to_CW :: proc "contextless" (v: $T, cam: ^Camera, wst: Transform) -> T {
	// # object -> world
	// We want (0,0) in object to map to `wst.R3_p` in world, so `v + wst.R3_p`
	//
	// # world -> camera-world
	// We want `camera.pos` in world to map to (0,0) in world, so `... - camera.pos`
	wst := wst
	wst.R3_p -= cam.pos
	cum_offset := wst.R3_p - cam.pos
	return forward_tr(v, wst)
}

// A ray modeled by equation \( P(t) = x_0 + dt \)
// where \(x_0\) is `origin`, \(d\) is `dir`.
Ray :: struct {
	origin: Point3,
	dir:    Vec3,
}

ray_at :: proc(ray: Ray, t: f32) -> Point3 {
	return ray.origin + Point3(ray.dir) * t
}

ray_tr_CW_to_object :: proc(ray: Ray, cam: ^Camera, wst: Transform) -> Ray {
	return Ray{tr_CW_to_object(ray.origin, cam, wst), tr_CW_to_object(ray.dir, cam, wst)}
	// return Ray{tr_CW_to_object(ray.origin, cam, wst), ray.dir}
}

ray_tr_object_to_CW :: proc(ray: Ray, cam: ^Camera, wst: Transform) -> Ray {
	return Ray{tr_object_to_CW(ray.origin, cam, wst), tr_object_to_CW(ray.dir, cam, wst)}
	// return Ray{tr_object_to_CW(ray.origin, cam, wst), ray.dir}
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
	// Technically reflectance is a dimensionless quantity.
	// Even though reflectance is stored as a radiance, `Color`, physically reflectance is a ratio between incident and relected radiance.
	reflectance: Color,
}

MirrorMaterial :: struct {
	reflectance: Color,
}

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
surface_normal_at :: proc(so: ^SceneObject, pos: Point3) -> Normal3 {
	switch &shape in so.shape {
	case Sphere:
		return sphere_surface_normal_at(&shape, pos)
	}

	return Normal3{}
}

// Radiance emitted by light sources.
// For all other objects, this should be 0.
light_emitted_at :: proc(so: ^SceneObject, pos: Point3, normal: Normal3) -> Color {
	#partial switch &material in so.material {
	case NormalDebugMaterial:
		return colorize_normal_vec(normal)
	case PureColorMaterial:
		return material.color
	}
	return Color{}
}

// Position, normal, and in/out directions in object space.
bsdf_at :: proc(so: ^SceneObject, pos: Point3, normal: Normal3, ωo, ωi: Vec3) -> Color {
	o2t := matrix3_rotate_object_to_tangent(Vec3(normal))
	t2o := linalg.inverse(o2t)

	t_pos := o2t * pos
	t_ωo := o2t * ωo
	t_ωi := o2t * ωi

	switch &material in so.material {
	case NormalDebugMaterial:
	case PureColorMaterial:
		return 0
	case DiffuseMaterial:
		if !tan_sp_same_hemisphere(t_ωo, t_ωi) {
			return 0
		}
		return material.reflectance / math.PI
	case MirrorMaterial:
		return 0
	}

	return Color{}
}

// Determine (light, ωi) for the given ωo.
//
// Note this corresponds to the BxDF::Sample_f() function from PBRT.
//
// Note that this function could also be defined in reverse: determine ωo for a given ωi,
// but since the path tracing algorithm simulates reverse time ("light" comes out of the camera and ends at light sources),
// it is more convenient to have it defined this way.
sample_bsdf_at :: proc(so: ^SceneObject, pos: Point3, normal: Normal3, ωo: Vec3) -> BSDF_Sample {
	o2t := matrix3_rotate_object_to_tangent(Vec3(normal))
	t2o := linalg.inverse(o2t)

	i := BSDF_Inputs{pos, normal, ωo, o2t, t2o}

	switch &material in so.material {
	case NormalDebugMaterial:
	case PureColorMaterial:
	case DiffuseMaterial: return diffuse_sample_bsdf_at(&material, i)
	case MirrorMaterial: return mirror_sample_bsdf_at(&material, i)
	}

	return BSDF_Sample{}
}

BSDF_Inputs :: struct {
	pos: Point3,
	normal: Normal3,
	ωo: Vec3,

	o2t, t2o: Mat3,
}

BSDF_Sample :: struct {
	L: Color,
	pdf: f32,
	ωi: Vec3,
}

diffuse_sample_bsdf_at :: proc(m: ^DiffuseMaterial, p: BSDF_Inputs) -> (out: BSDF_Sample) {
	using p

	// Let \(R\) be the reflectance of this surface, unit in radiance.
	//
	// Consider the rendering equation (note simplified notation here): \( L_o(ω_o) = \int_{Ω} f(...) L_i(ω_i) \cosθ \,dω_i \)
	// where
	// - \(Ω\) just denotes the hemisphere
	// - \( f(...) \) is the BRDF
	// - \(L_o(ω_o)\) is reflected radiance in a particular direction \(ω_o\). Note that in standard notation there are more parameters, I'm omitting them to be concise.
	// - \(L_i(ω_i)\) is similarly incident radiance.
	// - \(L_i\) is the *total* incident radiance, i.e. \( \int_{Ω} L_i(ω_i) \,dω_i \)
	// - \(L_o\) similarly.
	//
	// Conservation of energy says that total reflected radiance cannot be more than the total incident radiance:
	// \(L_o ≤ L_i\) must hold in all cases.
	//
	// If we simply follow the lambertian reflection definition and define the BRDF as \( f(...) = R \), where \(R\) is the reflectance of the surface,
	// then expanding the rendering equation by integrating over spherical coordinates, we get:
	//
	// \( L_o(ω_o) = \int_0^{2\pi} \int_0^{\pi/2} \underline{ L_i(θ, ϕ) R \cosθ } \sinθ \,dθ \,dϕ = π L_i R \)
	//
	// (integrand underlined; \(\sinθ\) is introduced by the spherical coordinate conversion)
	//
	// https://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
	// Both \(L_i\) and \(R\) are constants with respect to the integral, so we can pull them out.
	// Looing only at the trig functions then, you can just put this integral in any CAS, and the result is indeed π.
	//
	// Reflectance R is a ratio, so R < 1, but π = 3.14... > 1, which makes the product of all 3 things bigger than L_i.
	// Energy is not conserved!
	//
	// Thus, we need to divide the π out by adding a constant into the BRDF, so \( f(...) = \frac{R}{π} \)
	out.L = m.reflectance / math.PI

	t_ωi := rand_cosθ_Pz_hemisphere()
	out.ωi = p.t2o * t_ωi

	// Literally the lambertian cosine law. Probability that a ray is reflected in a direction is proportional to cosθ the ray makes with the len(normal)
	// Inserting a 1/π factor so the total probability comes out to 1, for the same reasoning as above.
	out.pdf = abs(tan_sp_cosθ(t_ωi)) / math.PI
	return
}

mirror_sample_bsdf_at :: proc(m: ^MirrorMaterial, p: BSDF_Inputs) -> (out: BSDF_Sample) {
	using p

	out.L = m.reflectance

	// Reflect across the normal
	n := Vec3(normal)
	r := -ωo // ray direction
	out.ωi = r - 2*dot(r, n)*n

	out.pdf = 1
	return
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

sphere_surface_normal_at :: proc(sphere: ^Sphere, pt: Point3) -> Normal3 {
	return Normal3(normalize(pt))
}

sphere_ray_hits :: proc(ray: Ray, sphere: ^Sphere) -> f32 {
	ro := Vec3(ray.origin)
	rd := ray.dir

	r := sphere.radius

	a := dot(rd, rd)
	b := 2 * dot(rd, ro)
	c := dot(ro, ro) - r * r
	r1, r2 := solve_quadratic_real(a, b, c)
	// Doesn't hit
	// NaN is produced by the sqrt. If one of the roots is NaN, the other must also be.
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
