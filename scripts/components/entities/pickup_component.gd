class_name PickupComponent extends EntityComponent
## Removes the entity when the player gets close. Whatever owns an inventory connects to `picked_up`.

signal picked_up(collector: Node3D, item_id: StringName, count: int)

@export var radius := 1.5
@export var delay := 0.5 ## Seconds after spawning before it can be picked up.

var _age := 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < delay or entity.world == null: return
	var player: Node3D = entity.world.player
	if player == null or entity.global_position.distance_to(player.global_position) > radius: return

	var item := entity.get_component(ItemComponent) as ItemComponent
	if item != null:
		var left: int = player.inventory.add(item.item_id, item.count)
		if left == item.count: return # nothing fit, leave it on the ground
		picked_up.emit(player, item.item_id, item.count - left)
		if left > 0:
			item.count = left # partial pickup
			return
	entity.queue_free()
