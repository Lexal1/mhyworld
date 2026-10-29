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
	state_changed.emit(old, state_name)


func _physics_process(delta: float) -> void:
	if current != null: current.update(delta)
