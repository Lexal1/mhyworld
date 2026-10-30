class_name PlayerComponent extends EntityComponent
## Base for components that only make sense on the Player. Gives typed access to it,
## and skips tick() while the player is frozen (waiting for the spawn chunks).

var player: Player


func on_attach() -> void:
	player = entity as Player
	if player == null:
		push_error("%s must be a direct child of the Player" % name)
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	setup()


func _physics_process(delta: float) -> void:
	if not player.frozen: tick(delta)


## Override instead of on_attach(). `player` is set by now.
func setup() -> void: pass

## Override instead of _physics_process(). Runs every physics frame while not frozen.
func tick(_delta: float) -> void: pass
