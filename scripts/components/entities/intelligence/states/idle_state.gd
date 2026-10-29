class_name IdleState extends EntityState

@export var min_time := 1.0
@export var max_time := 4.0
@export var next_state: StringName = &"Wander" ## Node name of the state to go to.

var _time_left := 0.0


func enter() -> void:
	entity.wish_dir = Vector3.ZERO
	_time_left = randf_range(min_time, max_time)


func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0: brain.change_state(next_state)
