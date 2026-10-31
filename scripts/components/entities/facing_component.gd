class_name FacingComponent extends EntityComponent
## Turns the model toward where the entity is trying to go.

@export var turn_speed := 10.0
@export_range(-180.0, 180.0) var forward_offset_degrees := 0.0 ## Set to 180 if the model walks backwards.
var look_target: Node3D ## While set, the model faces this instead of where it's walking.

func _physics_process(delta: float) -> void:
	if entity == null or entity.model == null: return
	var dir := entity.wish_dir
	if is_instance_valid(look_target):
		dir = look_target.global_position - entity.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001: return # standing still: keep the current facing
	var target := atan2(-dir.x, -dir.z) + deg_to_rad(forward_offset_degrees) # -Z is "forward"
	entity.model.rotation.y = lerp_angle(
		entity.model.rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))
