class_name MarbleFactory
extends RefCounted
## Builds marble RigidBody3D instances from a MarbleDef. One 3D model,
## identity via def data: the material style comes from MarbleDef.style
## (swirl = solid palette color, fire = glowing core, glass = translucent),
## so a new look is a def, not a code change. Texture/shader patterns and
## prize models arrive in M6. Contact reporting is on so gameplay can emit
## wall and embedded-hit events.

## Fire style: dark core with an emissive flame color, so the marble reads
## as burning from the inside.
const FIRE_CORE_COLOR := Color(0.2, 0.05, 0.02)
const FIRE_EMISSION_COLOR := Color(1.0, 0.45, 0.1)
const FIRE_EMISSION_ENERGY := 2.0
## Glass style: translucent tint, glossy and slightly metallic.
const GLASS_ALPHA := 0.55


static func make(def: MarbleDef, variant: int = 0) -> RigidBody3D:
	var marble := RigidBody3D.new()
	marble.mass = def.mass
	var phys := PhysicsMaterial.new()
	phys.bounce = def.bounce
	phys.friction = def.friction
	marble.physics_material_override = phys
	marble.contact_monitor = true
	marble.max_contacts_reported = 4

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = def.radius
	collider.shape = shape
	marble.add_child(collider)

	var mesh_i := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = def.radius
	mesh.height = def.radius * 2.0
	mesh_i.mesh = mesh
	mesh_i.material_override = _make_material(def, variant)
	marble.add_child(mesh_i)
	return marble


## Style -> material. Purely visual: collider, mass and physics never
## depend on it, and an unknown style falls back to the POC "swirl" look.
static func _make_material(def: MarbleDef, variant: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tint: Color = def.palette[variant % def.palette.size()]
	match def.style:
		&"fire":
			mat.albedo_color = FIRE_CORE_COLOR
			mat.emission_enabled = true
			mat.emission = FIRE_EMISSION_COLOR
			mat.emission_energy_multiplier = FIRE_EMISSION_ENERGY
		&"glass":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(tint.r, tint.g, tint.b, GLASS_ALPHA)
			mat.metallic = 0.2
			mat.roughness = 0.05
		_:
			# Default "swirl": the POC look, one solid palette color.
			mat.albedo_color = tint
			mat.metallic = 0.1
			mat.roughness = 0.25
	return mat
