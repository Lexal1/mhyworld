class_name PlayerCameraComponent extends PlayerComponent
## Mouse and controller look, head bob, and the third-person debug view.

const BOB_FREQUENCY := 3.0
const BOB_AMP := 0.03
const THIRD_PERSON_OFFSET := Vector3(0, 3, 5)
const LOOK_LIMIT := deg_to_rad(89)

@export var sensitivity := 0.005
@export_group("Controller")
@export var controller_sensitivity := 80.0
@export var controller_smoothing := 2.0
@export var controller_resistance := 15.0

var third_person := false

var _bob_time := 0.0
var _stick_velocity := Vector2.ZERO
var _base_position: Vector3


func setup() -> void:
	_base_position = player.camera.position


func _unhandled_input(event: InputEvent) -> void:
	if Global.is_paused(): return
	if event is InputEventMouseMotion:
		_look(event.relative * -sensitivity)
	elif event.is_action_pressed("debug1b"):
		third_person = not third_person


func tick(delta: float) -> void:
	_controller_look(delta)
	_update_camera(delta)


func _look(amount: Vector2) -> void:
	player.head.rotate_y(amount.x)
	player.camera.rotate_x(amount.y)
	player.camera.rotation.x = clampf(player.camera.rotation.x, -LOOK_LIMIT, LOOK_LIMIT)


func _controller_look(delta: float) -> void:
	var stick := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
	_stick_velocity = _stick_velocity.lerp(stick * -controller_sensitivity * 10, delta * (controller_smoothing / 100))
	_stick_velocity = _stick_velocity.lerp(Vector2.ZERO, controller_resistance / 100)
	_look(Vector2(deg_to_rad(_stick_velocity.x), deg_to_rad(_stick_velocity.y)))


func _update_camera(delta: float) -> void:
	_bob_time += delta * player.velocity.length() * float(player.is_on_floor())
	var offset := THIRD_PERSON_OFFSET if third_person else Vector3.ZERO
	player.camera.position = _base_position + offset + _headbob(_bob_time)


func _headbob(time: float) -> Vector3:
	return Vector3(
		cos(time * BOB_FREQUENCY / 2.5) * BOB_AMP,
		sin(time * BOB_FREQUENCY) * BOB_AMP,
		0.0)
