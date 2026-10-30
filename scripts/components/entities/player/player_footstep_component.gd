class_name PlayerFootstepComponent extends PlayerComponent
## Plays the step sound of the block under the player's feet, once per stride walked.

const STRIDE := 2.2        ## Blocks walked between steps. Higher = slower footsteps.
const FEET_OFFSET := 0.975 ## Half the collision capsule's height (1.95 in player.tscn).
const PROBE_DEPTH := 0.1   ## How far below the feet to look for the block.

var _distance := 0.0
var _audio: AudioStreamPlayer


func setup() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -12
	_audio.max_polyphony = 2 # a new step doesn't cut off the previous one
	add_child(_audio)


func tick(delta: float) -> void:
	if not player.is_on_floor() or Global.is_paused(): return
	_distance += Vector2(player.velocity.x, player.velocity.z).length() * delta
	if _distance < STRIDE: return

	var feet := player.position - Vector3(0, FEET_OFFSET + PROBE_DEPTH, 0)
	var block: Block = player.world.get_block_at(feet)
	if block == null: return # chunk is busy this frame, try again next one
	_distance = 0.0
	if block.step_sound == null: return

	_audio.stream = block.step_sound
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
