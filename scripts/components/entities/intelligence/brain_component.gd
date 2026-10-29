class_name BrainComponent extends EntityComponent
## A state machine. Every EntityState child is a state, named by its node name.

signal state_changed(old_state: StringName, new_state: StringName)

@export var initial_state: EntityState ## Empty = the first state child.

var current: EntityState
var _states := {} # node name -> EntityState


func on_attach() -> void:
	var first: EntityState = null
	for c in get_children():
		if c is EntityState:
			c.brain = self
			c.entity = entity
			_states[c.name] = c
			if first == null: first = c
	var start := initial_state if initial_state != null else first
	if start != null: change_state(start.name)


func change_state(state_name: StringName) -> void:
	var next: EntityState = _states.get(state_name)
	if next == null:
		push_error("Brain on '%s': no state named '%s'" % [entity.name, state_name])
		return
	var old := current.name if current != null else &""
	if current != null: current.exit()
	current = next
	current.enter()
	_play_state_animation()
	state_changed.emit(old, state_name)


## Shuts the brain down for good (e.g. on death).
func stop() -> void:
	if current != null: current.exit()
	current = null
	set_physics_process(false)


func _play_state_animation() -> void:
	var animator := entity.get_component(AnimatorComponent) as AnimatorComponent
	if animator != null:
		animator.play(current.animation, current.animation_loop, current.animation_speed)


func _physics_process(delta: float) -> void:
	if current != null: current.update(delta)
