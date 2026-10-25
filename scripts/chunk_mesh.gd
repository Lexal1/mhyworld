class_name ChunkMesh
extends MeshInstance3D

@export var shaderMaterial: ShaderMaterial

const ATLAS_SIZE := 64
const TILE_PX := 16
const TILES_PER_ROW := ATLAS_SIZE / TILE_PX
const CHUNK_SIZE := Global.CHUNK_SIZE
const NEIGHBOR_DELTAS: PackedInt32Array = [-CHUNK_SIZE, CHUNK_SIZE, 1, -1, -CHUNK_SIZE * CHUNK_SIZE, CHUNK_SIZE * CHUNK_SIZE]

var collision_body := StaticBody3D.new()
var collision_shape := CollisionShape3D.new()

# Face directions: [normal, u axis, v axis, neighbor offset]
const FACES := [
	[Vector3.DOWN,    Vector3.RIGHT,   Vector3.FORWARD, Vector3i.DOWN],
	[Vector3.UP,      Vector3.RIGHT,   Vector3.BACK,    Vector3i.UP],
	[Vector3.RIGHT,   Vector3.BACK,    Vector3.UP,      Vector3i.RIGHT],
	[Vector3.LEFT,    Vector3.FORWARD, Vector3.UP,      Vector3i.LEFT],
	[Vector3.FORWARD, Vector3.RIGHT,   Vector3.UP,      Vector3i.FORWARD],
	[Vector3.BACK,    Vector3.LEFT,    Vector3.UP,      Vector3i.BACK],
]

const AREA := CHUNK_SIZE * CHUNK_SIZE
const LAST := CHUNK_SIZE - 1

# how far to jump to land on the opposite edge of the neighbor chunk
const ROW_LAST := CHUNK_SIZE * LAST
const LAYER_LAST := AREA * LAST

static func build_arrays(generated: Dictionary, neighbors: Array) -> Array:
	var air: int = generated["air"]
	# nothing to mesh if the whole chunk is air
	if air == Global.CHUNK_VOLUME:
		return []

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var ids: PackedInt32Array = generated["block_ids"]
	var air_id: int = BlockRegistry.get_idx_of(&"air")

	# baked once at startup, read-only while meshing (safe for threads)
	var table: PackedByteArray = BlockRegistry.face_table
	var n: int = BlockRegistry.block_count

	# pull the neighbors out once so the loop never has to touch the Array
	# order matches FACES
	var n_down: PackedInt32Array = neighbors[0]
	var n_up: PackedInt32Array = neighbors[1]
	var n_right: PackedInt32Array = neighbors[2]
	var n_left: PackedInt32Array = neighbors[3]
	var n_forward: PackedInt32Array = neighbors[4]
	var n_back: PackedInt32Array = neighbors[5]

	var has_down := not n_down.is_empty()
	var has_up := not n_up.is_empty()
	var has_right := not n_right.is_empty()
	var has_left := not n_left.is_empty()
	var has_forward := not n_forward.is_empty()
	var has_back := not n_back.is_empty()

	var index := 0
	for z in CHUNK_SIZE:
		for y in CHUNK_SIZE:
			for x in CHUNK_SIZE:
				var i := index
				index += 1
				var matter_id := ids[i]
				if matter_id == air_id:
					continue

				# this matter's row in the table, so each face is one byte read
				var row := matter_id * n

				# one bit per face, set when that face should be drawn.
				# an unloaded neighbor never sets its bit, so no face gets
				# drawn against a chunk that isn't there yet.
				var mask := 0

				if y > 0:
					if table[row + ids[i - CHUNK_SIZE]] == 1: mask |= 1
				elif has_down and table[row + n_down[i + ROW_LAST]] == 1:
					mask |= 1

				if y < LAST:
					if table[row + ids[i + CHUNK_SIZE]] == 1: mask |= 2
				elif has_up and table[row + n_up[i - ROW_LAST]] == 1:
					mask |= 2

				if x < LAST:
					if table[row + ids[i + 1]] == 1: mask |= 4
				elif has_right and table[row + n_right[i - LAST]] == 1:
					mask |= 4

				if x > 0:
					if table[row + ids[i - 1]] == 1: mask |= 8
				elif has_left and table[row + n_left[i + LAST]] == 1:
					mask |= 8

				if z > 0:
					if table[row + ids[i - AREA]] == 1: mask |= 16
				elif has_forward and table[row + n_forward[i + LAYER_LAST]] == 1:
					mask |= 16

				if z < LAST:
					if table[row + ids[i + AREA]] == 1: mask |= 32
				elif has_back and table[row + n_back[i - LAYER_LAST]] == 1:
					mask |= 32

				# most voxels are buried, so this skips the bulk of them.
				if mask == 0:
					continue

				var pos := Vector3i(x, y, z)
				var rect := BlockRegistry.atlas_rects[matter_id]
				for fi in 6:
					if mask & (1 << fi):
						var face: Array = FACES[fi]
						_add_face(verts, normals, uvs, indices, face[0], face[1], face[2], pos, rect)

	if verts.is_empty():
		return []

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func _add_face(verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		normal: Vector3, u: Vector3, v: Vector3, pos: Vector3i, rect: Rect2) -> void:
	var base := verts.size()

	var center := (Vector3(pos) + Vector3(0.5, 0.5, 0.5) + normal * 0.5) * Global.BLOCK_SIZE
	var half := Global.BLOCK_SIZE * 0.5

	verts.append(center - u * half - v * half)
	verts.append(center - u * half + v * half)
	verts.append(center + u * half - v * half)
	verts.append(center + u * half + v * half)

	for i in 4:
		normals.append(normal)

	var u0 := rect.position.x
	var v0 := rect.position.y
	var u1 := rect.end.x
	var v1 := rect.end.y

	if normal.y == 0.0:
		uvs.append(Vector2(u1, v1))
		uvs.append(Vector2(u1, v0))
		uvs.append(Vector2(u0, v1))
		uvs.append(Vector2(u0, v0))
	else:
		uvs.append(Vector2(u0, v0))
		uvs.append(Vector2(u0, v1))
		uvs.append(Vector2(u1, v0))
		uvs.append(Vector2(u1, v1))

	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base + 3)
	indices.append(base + 1)

static func build_collision_faces(arrays: Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if arrays.is_empty():
		return faces
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	faces.resize(indices.size())
	for i in indices.size():
		faces[i] = verts[indices[i]]
	return faces

func apply_arrays(arrays: Array, faces: PackedVector3Array) -> void:
	if arrays.is_empty():
		mesh = null
		collision_shape.shape = null
		return

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = arr_mesh

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision_shape.shape = shape

func _ready() -> void:
	add_child(collision_body)
	collision_body.add_child(collision_shape)
	#material_override = Matters.atlas_material
	material_override = shaderMaterial
