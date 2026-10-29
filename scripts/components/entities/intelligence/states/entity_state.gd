class_name EntityState extends Node
## Base for brain states. States pick the next state themselves via brain.change_state().

@export_group("Animation") ## Played by the brain on entering. Set per model in the scene.
@export var animation: StringName = &"" ## Empty = leave the current animation alone.
@export var animation_loop := true
@export var animation_speed := 1.0

var brain: BrainComponent
var entity: Entity

func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass ## Physics tick.
