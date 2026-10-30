class_name PlayerTargetComponent extends PlayerComponent
## Tracks the entity under the crosshair and gives its health to the HUD for the heartbeat.

var target_entity: Entity = null

func setup() -> void:
	player.raycast.set_collision_mask_value(3, true) # also see corpses (layer 3)


func tick(_delta: float) -> void:
	target_entity = null
	if not Global.is_paused():
		target_entity = player.raycast.get_collider() as Entity

	var health: HealthComponent = null
	if target_entity != null:
		health = target_entity.get_component(HealthComponent) as HealthComponent
	player.hud.crosshair.heartbeat_source = health if health != null else player.health # null = back to your own heartbeat
