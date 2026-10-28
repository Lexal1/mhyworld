extends CharacterBody3D

signal place_block(pos, t)
signal break_block(pos)
signal die()

const SPEED := 6.0
const JUMP_VELOCITY := 7.0
const GROUND_FRICTION := 17.0
const AIR_FRICTION := 5.0
const DEATH_Y := -25.0
const BOB_FREQUENCY := 3.0
const BOB_AMP := 0.03
const THIRD_PERSON_OFFSET := Vector3(0, 3, 5)
const LOOK_LIMIT := deg_to_rad(89)
const BREAK_SFX := preload("res://assets/audio/break.wav")
const PLACE_SFX := preload("res://assets/audio/place.wav")
const OUTLINE_IDLE := Color(1, 0.459, 0.055, 0.17) # the color set in player.tscn

# Numpad action -> block id
const HOTBAR := {
	&"numpad1": &"plate",
	&"numpad2": &"turf",
	&"numpad3": &"light",
}

@export_group("Controller", "CONTROLLER_")
@export var CONTROLLER_SENSITIVITY: float = 80.0
@export var CONTROLLER_SMOOTHING: float = 2.0
@export var CONTROLLER_RESISTANCE: float = 15.0

var sensitivity := 0.005
var block_selected := &"plate"
var third_person := false
var dead := false
var t_bob := 0.0
var rotation_velocity := Vector2.ZERO
var frozen := true
var mine_speed := 1.0 # later: pickaxe raises this, no tool lowers it
var break_pos := Vector3i.ZERO
var break_progress := 0.0
var breaking := false
var noclip := false

@onready var world: Node3D = %World
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast
@onready var blok: AudioStreamPlayer3D = $Head/Camera/RayCast/blok
@onready var block_outline: MeshInstance3D = $BlockOutline
@onready var outline_material: StandardMaterial3D = block_outline.mesh.material
@onready var coyote_time: Timer = $CoyoteTime
@onready var input_buffer: Timer = $InputBuffer
@onready var camera_base_pos: Vector3 = camera.position


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if Global.is_paused(): return

	if event is InputEventMouseMotion:
		_look(Vector2(event.relative.x, event.relative.y) * -sensitivity)
	elif event.is_action_pressed("debug1b"):
		third_person = not third_person


func _physics_process(delta: float) -> void:
	if frozen: return
	if Input.is_action_just_pressed("pause"):
		Global.toggle_pause_state()

	_check_death()
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_update_block_target(delta)
	_controller_look(delta)
	_update_camera(delta)
	move_and_slide()
	_handle_hotbar_and_debug()


#region Camera

func _look(amount: Vector2) -> void:
	head.rotate_y(amount.x)
	camera.rotate_x(amount.y)
	camera.rotation.x = clamp(camera.rotation.x, -LOOK_LIMIT, LOOK_LIMIT)


func _controller_look(delta: float) -> void:
	var stick := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
	rotation_velocity = rotation_velocity.lerp(stick * -CONTROLLER_SENSITIVITY * 10, delta * (CONTROLLER_SMOOTHING / 100))
	rotation_velocity = rotation_velocity.lerp(Vector2.ZERO, CONTROLLER_RESISTANCE / 100)
	_look(Vector2(deg_to_rad(rotation_velocity.x), deg_to_rad(rotation_velocity.y)))


func _update_camera(delta: float) -> void:
	t_bob += delta * velocity.length() * float(is_on_floor())
	var offset := THIRD_PERSON_OFFSET if third_person else Vector3.ZERO
	camera.position = camera_base_pos + offset + _headbob(t_bob)


func _headbob(time: float) -> Vector3:
	return Vector3(
		cos(time * BOB_FREQUENCY / 2.5) * BOB_AMP,
		sin(time * BOB_FREQUENCY) * BOB_AMP,
		0.0)

#endregion

#region Movement

func _check_death() -> void:
	if position.y <= DEATH_Y and not dead:
		dead = true
		die.emit()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		if velocity.y < 0 and noclip: # TODO: make this thing approximate things to zero instead
			velocity.y = 0
			return


func _handle_jump() -> void:
	# Input buffer: a press shortly before landing still counts.
	# Coyote time: a jump shortly after leaving a ledge still counts.
	if noclip and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		return
	if noclip and Input.is_action_pressed("crouch"):
		velocity.y -= JUMP_VELOCITY
		return
	if Input.is_action_pressed("jump"): input_buffer.start()
	elif Input.is_action_just_released("jump"): input_buffer.stop()

	if not input_buffer.is_stopped() and not coyote_time.is_stopped():
		velocity.y = JUMP_VELOCITY
		coyote_time.stop()
		input_buffer.stop()


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := direction * SPEED
	var on_floor := is_on_floor()

	if on_floor:
		coyote_time.start()
		if direction != Vector3.ZERO:
			velocity.x = target.x
			velocity.z = target.z
			return

	var friction := GROUND_FRICTION if on_floor else AIR_FRICTION
	velocity.x = lerp(velocity.x, target.x, delta * friction)
	velocity.z = lerp(velocity.z, target.z, delta * friction)

func enable_noclip():
	noclip = true
	collision_mask = 0

func disable_noclip():
	noclip = false
	collision_mask = 1
#endregion

#region BlockInteraction

func _update_block_target(delta: float) -> void:
	if not raycast.is_colliding() or Global.is_paused():
		block_outline.visible = false
		_reset_breaking()
		return

	var normal := raycast.get_collision_normal()
	var hit_pos := raycast.get_collision_point() - normal * 0.5 # a point inside the targeted block
	var block_center := hit_pos.floor() + Vector3(0.5, 0.5, 0.5)

	block_outline.position = block_center - position
	block_outline.visible = true

	_update_breaking(delta, hit_pos)
	if Input.is_action_just_pressed("mouse2"):
		place_block.emit(hit_pos + normal, BlockRegistry.get_idx_of(block_selected))


func _update_breaking(delta: float, hit_pos: Vector3) -> void:
	if not Input.is_action_pressed("mouse1"):
		_reset_breaking()
		return
	var pos := Vector3i(hit_pos.floor())
	if not breaking or pos != break_pos: # new target: start over
		break_pos = pos
		break_progress = 0.0
		breaking = true
	var block: Block = world.get_block_at(hit_pos)
	if block == null: return
	break_progress += delta * mine_speed
	if break_progress >= block.hardness:
		break_block.emit(hit_pos)
		_reset_breaking()
		return
	var t := clampf(break_progress / block.hardness, 0.0, 1.0)
	outline_material.albedo_color = Color.from_hsv(t * 0.8, 0.8, 0.8 - t * 0.8, 0.5)


func _reset_breaking() -> void:
	breaking = false
	break_progress = 0.0
	outline_material.albedo_color = OUTLINE_IDLE


func _handle_hotbar_and_debug() -> void:
	for action in HOTBAR:
		if Input.is_action_just_pressed(action):
			block_selected = HOTBAR[action]

	if Input.is_action_just_pressed("debug2"):
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		var path := "user://screenshots/SCREENSHOT-%s.png" % Time.get_unix_time_from_system()
		get_viewport().get_texture().get_image().save_png(path)

#endregion

#region Audio

func play_break_sfx() -> void: _play_sfx(BREAK_SFX)

func play_place_sfx() -> void: _play_sfx(PLACE_SFX)

func _play_sfx(stream: AudioStream) -> void:
	blok.stream = stream
	blok.pitch_scale = randf_range(0.95,1.05)
	blok.play()

#endregion
