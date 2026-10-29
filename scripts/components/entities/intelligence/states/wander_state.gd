class_name WanderState extends EntityState

@export var min_time := 1.0
@export var max_time := 3.0
@export_range(0.0, 1.0) var speed_scale := 0.6
@export var next_state: StringName = &"Idle"

var _dir := Vector3.ZERO
var _time_left := 0.0


func enter() -> void:
	_time_left = randf_range(min_time, max_time)
	_pick_direction()


func exit() -> void:
	entity.wish_dir = Vector3.ZERO


func update(delta: float) -> void:
	if entity.is_on_wall(): _pick_direction() # walked into something, turn
	entity.wish_dir = _dir
	_time_left -= delta
	if _time_left <= 0.0: brain.change_state(next_state)


func _pick_direction() -> void:
	var a := randf() * TAU
	_dir = Vector3(cos(a), 0.0, sin(a)) * speed_scale
