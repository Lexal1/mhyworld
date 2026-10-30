class_name Entity extends CharacterBody3D
## Base for everything that lives in the world. Behaviour comes from EntityComponent children.

const DEATH_DEPTH := 0.4 ## Fraction of world height below y=0 where entities die. 0.4 of 64 is about the old -25.
const GROUND_FRICTION := 17.0
const AIR_FRICTION := 5.0

@export var id: StringName = &""
@export var move_speed := 2.0 
@export var gravity_scale := 1.0
@export var model: Node3D ## Visual root. Components (animation, facing, tint, fade) act on it.
@export var step_height := 1.1 ## Just over one block.
@export var step_jump_velocity := 7.0 ## Gravity is 20, so this clears ~1.2 blocks.

var world: Node3D ## Set by World.spawn_entity.
var wish_dir := Vector3.ZERO ## Where states want to go. Length 0..1, scaled by move_speed.


func _ready() -> void:
	# Two passes, so every component knows its entity before any on_attach() runs.
	for c in get_children():
		if c is EntityComponent: c.entity = self
	for c in get_children():
		if c is EntityComponent: c.on_attach()


static func death_y() -> float:
	return -Global.world_height * DEATH_DEPTH


func get_component(type: Script) -> EntityComponent:
	for c in get_children():
		if is_instance_of(c, type): return c
	return null


func has_component(type: Script) -> bool:
	return get_component(type) != null


func _physics_process(delta: float) -> void:
	if position.y < death_y():
		queue_free()
		return
	if world != null and not world.is_position_loaded(global_position): return # no collision yet

	var grounded := is_on_floor()
	if grounded and is_on_wall() and can_step_up():
		velocity.y = step_jump_velocity
	if not grounded: velocity += get_gravity() * gravity_scale * delta

	var target := wish_dir * move_speed
	var friction := GROUND_FRICTION if grounded else AIR_FRICTION
	velocity.x = lerpf(velocity.x, target.x, delta * friction)
	velocity.z = lerpf(velocity.z, target.z, delta * friction)
	move_and_slide()

## True if the entity is pushing into something it could hop onto.
func can_step_up() -> bool:
	var dir := wish_dir
	dir.y = 0.0
	if dir.is_zero_approx(): return false
	dir = dir.normalized() * 0.3
	if test_move(global_transform, Vector3.UP * step_height): return false # no headroom
	return not test_move(global_transform.translated(Vector3.UP * step_height), dir) # clear up there?
