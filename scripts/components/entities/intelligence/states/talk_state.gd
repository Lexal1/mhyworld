class_name TalkState extends EntityState
## Not part of the Idle/Wander cycle. DialogueComponent switches the brain here and back.
## Stands still and turns to face the player. Set `animation` to "talk" in the scene.


func enter() -> void:
	entity.wish_dir = Vector3.ZERO
	var facing := entity.get_component(FacingComponent) as FacingComponent
	if facing != null and entity.world != null: facing.look_target = entity.world.player


func exit() -> void:
	var facing := entity.get_component(FacingComponent) as FacingComponent
	if facing != null: facing.look_target = null
