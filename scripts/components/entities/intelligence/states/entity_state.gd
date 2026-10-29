class_name EntityState extends Node
## Base for brain states. States pick the next state themselves via brain.change_state().

var brain: BrainComponent
var entity: Entity

func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass ## Physics tick.
