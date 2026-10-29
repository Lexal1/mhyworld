class_name PaletteTintComponent extends EntityComponent
## Gives the head and body meshes a random colour from a palette image, once, on spawn.

@export var palette: Texture2D
@export var head_mesh_name := "head" ## Matches mesh nodes whose name contains this (case-insensitive).
@export var body_mesh_name := "body"

static var _image: Image # decoded once, shared by every Occupant


func on_attach() -> void:
	if entity.model == null or palette == null: return
	if _image == null:
		_image = palette.get_image()
		if _image.is_compressed(): _image.decompress()
	_tint(_meshes_named(head_mesh_name), _random_color())
	_tint(_meshes_named(body_mesh_name), _random_color())


func _random_color() -> Color:
	var color := Color.WHITE
	for i in 8: # skip see-through pixels
		color = _image.get_pixel(randi() % _image.get_width(), randi() % _image.get_height())
		if color.a > 0.5: break
	color.a = 1.0
	return color


func _meshes_named(part: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for n in entity.model.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).to_lower().contains(part.to_lower()):
			result.push_back(n)
	if result.is_empty():
		push_warning("PaletteTint on '%s': no mesh with '%s' in its name" % [entity.name, part])
	return result


## The glb's materials are shared by every instance, so each mesh gets its own copy.
func _tint(meshes: Array[MeshInstance3D], color: Color) -> void:
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null: continue
			var copy := mat.duplicate() as BaseMaterial3D
			copy.albedo_color = color # multiplies the texture
			mi.set_surface_override_material(s, copy)
