class_name BlockAtlasPosition extends Resource

@export var TOP: Vector2
@export var BOTTOM: Vector2
@export var NORTH: Vector2
@export var SOUTH: Vector2
@export var WEST: Vector2
@export var EAST: Vector2

func _init(p_top: Vector2 = Vector2(0, 0), p_bottom: Vector2 = Vector2(0, 0), p_north: Vector2 = Vector2(0, 0), p_south: Vector2 = Vector2(0, 0), p_west: Vector2 = Vector2(0, 0), p_east: Vector2 = Vector2(0, 0)):
	TOP = p_top
	BOTTOM = p_bottom
	NORTH = p_north
	SOUTH = p_south
	WEST = p_west
	EAST = p_east
	
