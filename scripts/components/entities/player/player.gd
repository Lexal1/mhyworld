class_name Player extends Entity
## The human-controlled entity. Behaviour lives in the PlayerComponent children.
## This script holds the shared state, the signals the rest of the game listens to,
## and the single move_and_slide() call.

signal place_block(pos, t)
signal break_block(pos)
signal die()

var frozen := true ## World releases the player once the spawn chunks are meshed.
var inventory := Inventory.new()

@onready var hud: HUD = %HUD
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var raycast: RayCast3D = $Head/Camera/RayCast
@onready var health := get_component(HealthComponent) as HealthComponent

@onready var _movement := get_component(PlayerMovementComponent) as PlayerMovementComponent
@onready var _blocks := get_component(PlayerBlockComponent) as PlayerBlockComponent
@onready var _targeting := get_component(PlayerTargetComponent) as PlayerTargetComponent

var target_entity: Entity: ## What the crosshair is on, if anything.
	get: return _targeting.target_entity


func _ready() -> void:
	world = %World
	process_physics_priority = 100
	super()
	health.died.connect(func(_source: Node): die.emit())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Overrides Entity's physics on purpose: the player snaps to its walk speed on the
## ground, can noclip and jumps, none of which fit Entity's wish_dir movement.
func _physics_process(_delta: float) -> void:
	if frozen: return
	#if Input.is_action_just_pressed("pause"):
	#	Global.toggle_pause_state()
	_check_death()
	move_and_slide()


func _check_death() -> void:
	if position.y <= death_y() and not health.dead:
		health.damage(health.max_health) # falling out of the world is just lethal damage


#region Console / World hooks
# Thin wrappers so game.gd and world.gd don't need to know which component owns what.

func toggle_noclip() -> void: _movement.toggle_noclip()

func toggle_fastbreak() -> void: _blocks.fast_break = not _blocks.fast_break

func play_break_sfx() -> void: _blocks.play_break_sfx()

func play_place_sfx() -> void: _blocks.play_place_sfx()

#endregion
