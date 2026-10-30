class_name PlayerMovementComponent extends PlayerComponent
## Walking, jumping and noclip. Speed comes from Entity.move_speed.

const JUMP_VELOCITY := 7.0
const NOCLIP_SPEED := 14.0 ## Double the jump velocity so flying up feels consistent.
const COYOTE_TIME := 0.1 ## Seconds after leaving a ledge where you can still jump.

var noclip := false
var _coyote := 0.0


func toggle_noclip() -> void:
	noclip = not noclip
	player.collision_mask = 0 if noclip else 1


func tick(delta: float) -> void:
	var direction := _input_direction()
	if noclip:
		_fly(direction)
	else:
		_walk(direction, delta)


func _input_direction() -> Vector3:
	var input := Input.get_vector("left", "right", "forward", "backward")
	return (player.head.transform.basis * Vector3(input.x, 0, input.y)).normalized()


func _fly(direction: Vector3) -> void:
	player.velocity = direction * NOCLIP_SPEED
	player.velocity.y = Input.get_axis("crouch", "jump") * NOCLIP_SPEED


func _walk(direction: Vector3, delta: float) -> void:
	var on_floor := player.is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
		player.velocity += player.get_gravity() * player.gravity_scale * delta

	if Input.is_action_pressed("jump") and _coyote > 0.0:
		player.velocity.y = JUMP_VELOCITY
		_coyote = 0.0 # no second jump while rising

	var target := direction * player.move_speed
	if on_floor and direction != Vector3.ZERO:
		player.velocity.x = target.x # snappy on the ground
		player.velocity.z = target.z
	else:
		var friction := Entity.GROUND_FRICTION if on_floor else Entity.AIR_FRICTION
		player.velocity.x = lerpf(player.velocity.x, target.x, delta * friction)
		player.velocity.z = lerpf(player.velocity.z, target.z, delta * friction)
