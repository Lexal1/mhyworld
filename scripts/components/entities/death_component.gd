class_name DeathComponent extends EntityComponent
## On death: stop thinking, play the death animation, linger, fade out, delete.

@export var death_animation: StringName = &"death"
@export var linger_time := 1.5 ## Seconds before the fade starts.
@export var fade_time := 1.0

var _meshes: Array[Node] = []


func on_attach() -> void:
	var health := entity.get_component(HealthComponent) as HealthComponent
	if health == null:
		push_error("DeathComponent on '%s' needs a HealthComponent" % entity.name)
		return
	health.free_entity_on_death = false # we free it ourselves, after the fade
	health.died.connect(_on_died)


func _on_died(_source: Node) -> void:
	var brain := entity.get_component(BrainComponent) as BrainComponent
	if brain != null: brain.stop()
	entity.wish_dir = Vector3.ZERO
	entity.collision_layer = 0 # can't be targeted or bumped; still collides with the ground

	var animator := entity.get_component(AnimatorComponent) as AnimatorComponent
	if animator != null: animator.play(death_animation, false)

	if entity.model != null:
		_meshes = entity.model.find_children("*", "MeshInstance3D", true, false)

	# One tween on this node: if the entity is freed early (fell out of the world), it dies with it.
	var tween := create_tween()
	tween.tween_interval(linger_time)
	tween.tween_method(_set_fade, 0.0, 1.0, fade_time)
	tween.tween_callback(entity.queue_free) # fully invisible by now


func _set_fade(amount: float) -> void:
	for m: MeshInstance3D in _meshes:
		m.transparency = amount
