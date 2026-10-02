extends CharacterBody3D

const SPEED = 6.0
const JUMP_VELOCITY = 7.0
const BREAKSFX = preload("res://assets/audio/break.wav")
const PLACESFX = preload("res://assets/audio/place.wav")

var selected = 6
var sensitivity = 0.005

var t_bob = 0.0

var perspective = false
var dead = false
var block_selected = &"plate"


@onready var head: Node3D = $Head
@onready var camera = $Head/Camera
@onready var raycast = $Head/Camera/RayCast
@onready var blok: AudioStreamPlayer3D = $Head/Camera/RayCast/blok
@onready var block_outline: MeshInstance3D = $BlockOutline
var rotation_velocity: Vector2 = Vector2(0, 0)
@export_group("Controller", "CONTROLLER_")
@export var CONTROLLER_SENSITIVITY: float = 80.0
@export var CONTROLLER_SMOOTHING: float = 2.0
@export var CONTROLLER_RESISTANCE: float = 15.0

signal place_block(pos,t)
signal break_block(pos)
signal die()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _controllerCam(delta: float):
	var x = Input.get_axis("cam_left", "cam_right")
	var y = Input.get_axis("cam_up", "cam_down")
	rotation_velocity = rotation_velocity.lerp(Vector2(x, y) * -CONTROLLER_SENSITIVITY * 10, delta * (CONTROLLER_SMOOTHING/100))
	rotation_velocity = rotation_velocity.lerp(Vector2.ZERO, CONTROLLER_RESISTANCE/100)
	head.rotate_y(deg_to_rad(rotation_velocity.x))
	camera.rotate_x(deg_to_rad(rotation_velocity.y))
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(90))

func _unhandled_input(event: InputEvent):
	if Global.is_paused(): return
	
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	#if event is InputEventJoypadMotion:
	
	if Input.is_action_just_pressed("debug1b"):
		perspective = not perspective
		if perspective:
			camera.position.y = 3
			camera.position.z = 5
		else:
			camera.position.y = 0.5
			camera.position.z = 0

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		Global.toggle_pause_state()

	if position.y <= -25 and !dead:
		dead = true
		die.emit()

	# add gravity
	if not is_on_floor():
		pass
		velocity += get_gravity() * delta

	# handle jump
	if Input.is_action_just_pressed("jump"): $InputBuffer.start()
	
	if !$InputBuffer.is_stopped() and !$CoyoteTime.is_stopped():
		velocity.y = JUMP_VELOCITY
		$CoyoteTime.stop()
		$InputBuffer.stop()

	# handle input direction and handle the movement/deceleration
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		$CoyoteTime.start()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 17.0)
			velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 17.0)
	else: #TODO: condense these somehow?
		velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 5.0) #lerp lerp lerp sahur
		velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 5.0)

	if raycast.is_colliding():
		var norm = raycast.get_collision_normal()
		var pos = raycast.get_collision_point() - norm * 0.5
		
		var bx = floor(pos.x) +0.5
		var by = floor(pos.y) +0.5
		var bz = floor(pos.z) +0.5
		var bpos = Vector3(bx,by,bz) - self.position
		
		block_outline.position = bpos
		block_outline.visible = true
		
		if Input.is_action_just_pressed("mouse1"):
			emit_signal("break_block", pos)
		if Input.is_action_just_pressed("mouse2"):
			emit_signal("place_block", pos +norm, BlockRegistry.get_idx_of(block_selected))
		if Input.is_action_just_pressed("numpad1"):
			block_selected = &"plate"
		if Input.is_action_just_pressed("numpad2"):
			block_selected = &"turf"
		if Input.is_action_just_pressed("numpad3"):
			block_selected = &"light"
	else:
		block_outline.visible = false
	_controllerCam(delta)
	#head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = headbob(t_bob)
	
	move_and_slide()

func headbob(time) -> Vector3:
	var pos = Vector3.ZERO 
	pos.y = sin(time * 3.0) * 0.025     #3.0 = BOB FREQUENCY 0.025 = BOB AMPLITUDE
	pos.x = cos(time * 3.0 / 2) * 0.025 #TODO: UNHARDCODE THIS
	return pos


func play_break_sfx():
	blok.stream = BREAKSFX
	blok.play()

func play_place_sfx():
	blok.stream = PLACESFX
	blok.play()
