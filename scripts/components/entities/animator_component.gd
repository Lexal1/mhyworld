class_name AnimatorComponent extends EntityComponent
## Plays animations from the model's AnimationPlayer. The brain calls this when states change.

@export var crossfade := 0.15

var _player: AnimationPlayer


func play(anim: StringName, loop := true, speed := 1.0) -> void:
	if anim == &"": return
	# Looked up here, not in on_attach(), because the brain can call us first.
	if _player == null and entity.model != null:
		_player = entity.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_warning("Animator on '%s': no AnimationPlayer in the model" % entity.name)
		return
	if not _player.has_animation(anim):
		push_warning("Animator on '%s': no animation '%s'. Available: %s" % [
			entity.name, anim, _player.get_animation_list()])
		return
	_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(anim, crossfade, speed)
