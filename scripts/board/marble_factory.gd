class_name MarbleFactory
extends RefCounted
## Builds marble RigidBody3D instances from a MarbleDef. One 3D model,
## identity via def data (palette colors now, texture/shader patterns from
## M6). Contact reporting is on so gameplay can emit wall and embedded-hit
## events.

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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.palette[variant % def.palette.size()]
	mat.metallic = 0.1
	mat.roughness = 0.25
	mesh_i.material_override = mat
	marble.add_child(mesh_i)
	return marble
