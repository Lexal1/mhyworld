class_name Entity extends CharacterBody3D
## Base for everything that lives in the world. Behaviour comes from EntityComponent children.

const DEATH_Y := -25.0
const GROUND_FRICTION := 17.0
const AIR_FRICTION := 5.0

@export var id: StringName = &""
@export var move_speed := 2.0
@export var gravity_scale := 1.0

var world: Node3D ## Set by World.spawn_entity.
var wish_dir := Vector3.ZERO ## Where states want to go. Length 0..1, scaled by move_speed.


func _ready() -> void:
	# Two passes, so every component knows its entity before any on_attach() runs.
	for c in get_children():
		if c is EntityComponent: c.entity = self
	for c in get_children():
		if c is EntityComponent: c.on_attach()


func get_component(type: Script) -> EntityComponent:
	for c in get_children():
		if is_instance_of(c, type): return c
	return null


func has_component(type: Script) -> bool:
	return get_component(type) != null


func _physics_process(delta: float) -> void:
	if position.y < DEATH_Y:
		queue_free()
		return
	if world != null and not world.is_position_loaded(global_position): return # no collision yet

	var grounded := is_on_floor()
	if not grounded: velocity += get_gravity() * gravity_scale * delta

	var target := wish_dir * move_speed
	var friction := GROUND_FRICTION if grounded else AIR_FRICTION
	velocity.x = lerpf(velocity.x, target.x, delta * friction)
	velocity.z = lerpf(velocity.z, target.z, delta * friction)
	move_and_slide()
