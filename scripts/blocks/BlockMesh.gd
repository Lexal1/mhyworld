class_name BlockMesh extends RefCounted
## Cube geometry shared by Chunk and BlockPreview.

const VERTICES := [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1),
]

# Each face is 4 corner indices into VERTICES.
const TOP    := [2, 3, 7, 6]
const BOTTOM := [0, 4, 5, 1]
const NORTH  := [7, 5, 4, 6] # +Z
const SOUTH  := [2, 0, 1, 3] # -Z
const EAST   := [3, 1, 5, 7] # +X
const WEST   := [6, 4, 0, 2] # -X


## Adds one textured quad (two triangles) to `st`.
static func add_face(st: SurfaceTool, face: Array, offset: Vector3, atlas_offset: Vector2) -> void:
	var a: Vector3 = VERTICES[face[0]] + offset
	var b: Vector3 = VERTICES[face[1]] + offset
	var c: Vector3 = VERTICES[face[2]] + offset
	var d: Vector3 = VERTICES[face[3]] + offset

	var tile := Vector2.ONE / Global.TEXTURE_ATLAS_SIZE
	var uv := atlas_offset * tile
	var uv_a := uv
	var uv_b := uv + Vector2(0, tile.y)
	var uv_c := uv + tile
	var uv_d := uv + Vector2(tile.x, 0)

	st.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
	st.add_triangle_fan([a, c, d], [uv_a, uv_c, uv_d])
