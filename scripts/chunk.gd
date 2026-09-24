@tool
extends StaticBody3D

const vertices = [
	Vector3(0,0,0),
	Vector3(1,0,0),
	Vector3(0,1,0),
	Vector3(1,1,0),
	Vector3(0,0,1),
	Vector3(1,0,1),
	Vector3(0,1,1),
	Vector3(1,1,1)
]

const TOP =    [2,3,7,6]
const BOTTOM = [0,4,5,1]
const NORTH =  [7,5,4,6]
const SOUTH =  [2,0,1,3]
const EAST =   [3,1,5,7]
const WEST =   [6,4,0,2]

@export var shaderMaterial: ShaderMaterial

var noise = FastNoiseLite.new()

var blocksMutex: Mutex = Mutex.new()
var blocks = []

var st = SurfaceTool.new()
var mesh : Mesh = null
var mesh_instance : MeshInstance3D = null

var material = preload("res://assets/resources/new_standard_material_3d.tres")

var chunk_position = Vector2.ZERO:
	get:
		return chunk_position
	set(value):
		chunk_position = value
		position = Vector3(value.x, 0, value.y) * Global.CHUNK_SIZE
		self.visible = false

func _ready():
	noise.seed = Global.world_seed #TODO: add a check to make sure that the world seed actually exists
	#generate()
	#update()
	generate_and_update()

func generate_and_update():
	return WorkerThreadPool.add_task(_generate_and_update)
	
func _generate_and_update():
	_generate()
	update()

func _generate():
	blocksMutex.lock()
	blocks = []
	blocks.resize(Global.CHUNK_SIZE.x)
	for i in range(0, Global.CHUNK_SIZE.x):
		blocks[i] = []
		blocks[i].resize(Global.CHUNK_SIZE.y)
		for j in range(0, Global.CHUNK_SIZE.y):
			blocks[i][j] = []
			blocks[i][j].resize(Global.CHUNK_SIZE.z)
			for k in range(0, Global.CHUNK_SIZE.z):
				var global_pos = chunk_position * Vector2(Global.CHUNK_SIZE.x,Global.CHUNK_SIZE.z) + Vector2(i,k)
				
				var height = int((noise.get_noise_2dv(global_pos) + 1)/ 2 * Global.CHUNK_SIZE.y)
				
				#var block = Blocks.AIR
				var block = BlockRegistry.get_idx_of(&"air")
				
				if j < height / 2:
					block = BlockRegistry.get_idx_of(&"stone")
				elif j < height:
					block = BlockRegistry.get_idx_of(&"dirt")
				elif j == height:
					block = BlockRegistry.get_idx_of(&"grass")
				if typeof(block) != TYPE_INT:
					print("unint block: ", block)
				blocks[i][j][k] = block
	blocksMutex.unlock()
func update():
	## unloads chunk if it exists
	if mesh != null:
		mesh_instance.call_deferred("queue_free")
		mesh_instance = null
	mesh = ArrayMesh.new()
	mesh_instance = MeshInstance3D.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	blocksMutex.lock()
	for x in Global.CHUNK_SIZE.x:
		for y in Global.CHUNK_SIZE.y:
			for z in Global.CHUNK_SIZE.z:
				create_block(x,y,z)
	blocksMutex.unlock()
	st.generate_normals(false)
	st.set_material(shaderMaterial)
	mesh = st.commit()
	mesh_instance.set_mesh(mesh)
	self.call_deferred("add_child",mesh_instance)
	#mesh_instance.create_trimesh_collision()
	mesh_instance.create_trimesh_collision.call_deferred()
	#self.visible = true
	self.call_deferred("set_visible", true)

func check_transparency(x,y,z):
	if x >= 0 and x < Global.CHUNK_SIZE.x and \
		y >= 0 and y < Global.CHUNK_SIZE.y and \
		z >= 0 and z < Global.CHUNK_SIZE.z:
			#return not Blocks.block_types[blocks[x][y][z]][Blocks.SOLID]
			if typeof(blocks[x][y][z]) != TYPE_INT:
				print(blocks[x][y][z])
			return not BlockRegistry.get_by_idx(blocks[x][y][z]).solid
	return true

func create_block(x,y,z):
	#print("creating block %s %s %s" % [x,y,z])
	var block = blocks[x][y][z]
	#if block == Blocks.AIR:
	#	return
	if block == BlockRegistry.get_idx_of(&"air"):
		return
	
	#var block_data = Blocks.block_types[block]
	var block_data = BlockRegistry.get_by_idx(block)
	var atlas_data = block_data.atlas_position
	
	if check_transparency(x, y+1, z): create_face(TOP, x,y,z, atlas_data.TOP)
	if check_transparency(x, y-1, z): create_face(BOTTOM, x,y,z, atlas_data.BOTTOM)
	if check_transparency(x, y, z+1): create_face(NORTH, x,y,z, atlas_data.NORTH)
	if check_transparency(x, y, z-1): create_face(SOUTH, x,y,z, atlas_data.SOUTH)
	if check_transparency(x+1, y, z): create_face(EAST, x,y,z, atlas_data.EAST)
	if check_transparency(x-1, y, z): create_face(WEST, x,y,z, atlas_data.WEST)

func create_face(i, x,y,z, atlas_offset): #what is this, miitopia?
	var offset = Vector3(x,y,z)
	var a = vertices[i[0]] + offset
	var b = vertices[i[1]] + offset
	var c = vertices[i[2]] + offset
	var d = vertices[i[3]] + offset
	
	var uv_offset = atlas_offset / Global.TEXTURE_ATLAS_SIZE
	var height = 1.0 / Global.TEXTURE_ATLAS_SIZE.y
	var width = 1.0 / Global.TEXTURE_ATLAS_SIZE.x
	
	var uv_a = uv_offset + Vector2.ZERO
	var uv_b = uv_offset + Vector2(0,height)
	var uv_c = uv_offset + Vector2(width,height)
	var uv_d = uv_offset + Vector2(width,0)
	
	st.add_triangle_fan(([a,b,c]), ([uv_a,uv_b,uv_c]))
	st.add_triangle_fan(([a,c,d]), ([uv_a,uv_c,uv_d]))
	
