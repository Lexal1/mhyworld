class_name EntityComponent extends Node
## Base class for entity behaviours. Add one as a direct child of an Entity.

var entity: Entity ## Set before on_attach(). Don't use it in _ready().

## Called once the entity and all its components exist.
func on_attach() -> void: pass
