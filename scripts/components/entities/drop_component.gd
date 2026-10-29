class_name DropComponent extends EntityComponent

const DEFAULT_ITEM_SCENE := "res://scenes/entities/dropped_item.tscn"

@export var drops: Array[DropEntry] = []
@export var drop_on_death := true
@export var item_scene: PackedScene ## Empty = the default dropped item.
@export var toss_speed := 3.0


func on_attach() -> void:
	var health := entity.get_component(HealthComponent) as HealthComponent
	if drop_on_death and health != null:
		health.died.connect(func(_source: Node): drop_all())


## Public, so anything else (a breakable thing, a script) can trigger the drops.
func drop_all() -> void:
	if entity.world == null: return
	var scene := item_scene if item_scene != null else load(DEFAULT_ITEM_SCENE) as PackedScene
	for d in drops:
		if randf() > d.chance: continue
		var n := randi_range(d.min_count, d.max_count)
		if n <= 0: continue
		entity.world.spawn_entity(scene, entity.global_position, func(e: Entity):
			var item := e.get_component(ItemComponent) as ItemComponent
			item.item_id = d.item_id
			item.count = n
			e.velocity = Vector3(
				randf_range(-1.0, 1.0) * toss_speed, toss_speed, randf_range(-1.0, 1.0) * toss_speed))
