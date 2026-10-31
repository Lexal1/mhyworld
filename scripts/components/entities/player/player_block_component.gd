class_name PlayerBlockComponent extends PlayerComponent
## Targeting, breaking, placing and picking blocks, plus the hotbar and block sounds.
## Edits go out through the Player's break_block / place_block signals.

const OUTLINE_IDLE := Color(1, 0.459, 0.055, 0.17) # the colour set in player.tscn
const BREAK_SFX := preload("res://assets/audio/sfx/break.wav")
const PLACE_SFX := preload("res://assets/audio/sfx/place.wav")
const PICKUP_SFX := preload("res://assets/audio/sfx/poip.wav")
const MAX_RAY_STEPS := 64
const MINE_SFX_INTERVAL := 0.25 ## Seconds between hit sounds while mining.

# Numpad action -> block id
const HOTBAR := {
	&"numpad1": &"plate",
	&"numpad2": &"turf",
	&"numpad3": &"light",
}

@export var outline: MeshInstance3D
@export var sfx: AudioStreamPlayer3D



var block_selected := &"plate"
var mine_speed := 1.0 # later: pickaxe raises this, no tool lowers it
var fast_break := false

var _break_pos := Vector3i.ZERO
var _break_progress := 0.0
var _breaking := false
var _outline_material: StandardMaterial3D
var _pickup_audio: AudioStreamPlayer
var _mine_sfx: AudioStreamPlayer3D
var _mine_sfx_timer := 0.0

func setup() -> void:
	_outline_material = outline.mesh.material
	_pickup_audio = AudioStreamPlayer.new()
	_pickup_audio.stream = PICKUP_SFX
	_pickup_audio.max_polyphony = 4 # several items collected at once overlap
	add_child(_pickup_audio)
	_mine_sfx = sfx.duplicate() as AudioStreamPlayer3D # same position and settings as sfx
	sfx.get_parent().add_child(_mine_sfx)


func tick(delta: float) -> void:
	_update_target(delta)
	_handle_hotbar()


#region Targeting

func _update_target(delta: float) -> void:
	if Global.is_paused():
		_clear_target()
		return

	var ray := player.raycast
	var hit := _voxel_raycast(
		ray.global_position,
		-ray.global_transform.basis.z,
		ray.target_position.length())
	if hit.is_empty():
		_clear_target()
		return

	var normal: Vector3 = hit.normal
	var hit_pos := Vector3(hit.cell) + Vector3(0.5, 0.5, 0.5) # centre of the targeted block

	outline.position = hit_pos - player.position
	outline.visible = true

	_update_breaking(delta, hit_pos)
	if Input.is_action_just_pressed("mouse2") and DialogueComponent.talkable(player.target_entity) == null:
		player.place_block.emit(hit_pos + normal, BlockRegistry.get_idx_of(block_selected))
	if Input.is_action_just_pressed("mouse3"):
		var picked: Block = player.world.get_block_at(hit_pos)
		if picked != null: block_selected = picked.id # null if the chunk is busy this frame


func _clear_target() -> void:
	outline.visible = false
	_reset_breaking()


## Walks the block grid from `from` along `dir`. Returns {} on a miss,
## otherwise {"cell": Vector3i, "normal": Vector3} for the first non-air block.
func _voxel_raycast(from: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var cell := Vector3i(from.floor())
	var step := Vector3i.ZERO
	var t_max := Vector3.INF   # distance along the ray to the next cell edge, per axis
	var t_delta := Vector3.INF # distance along the ray to cross one whole cell, per axis
	for a in 3:
		if dir[a] > 0.0:
			step[a] = 1
			t_delta[a] = 1.0 / dir[a]
			t_max[a] = (cell[a] + 1 - from[a]) / dir[a]
		elif dir[a] < 0.0:
			step[a] = -1
			t_delta[a] = -1.0 / dir[a]
			t_max[a] = (from[a] - cell[a]) / -dir[a]

	for _i in MAX_RAY_STEPS: # max_dist normally ends it in ~15 steps
		var axis := 0 # step along whichever axis hits a cell edge first
		if t_max.y < t_max.x: axis = 1
		if t_max.z < t_max[axis]: axis = 2
		if t_max[axis] > max_dist: return {}

		cell[axis] += step[axis]
		t_max[axis] += t_delta[axis]

		var block: Block = player.world.get_block_at(Vector3(cell))
		if block != null and block.id != &"air":
			var normal := Vector3.ZERO
			normal[axis] = -step[axis] # the face we came in through
			return {"cell": cell, "normal": normal}
	return {}

#endregion


#region Breaking

func _update_breaking(delta: float, hit_pos: Vector3) -> void:
	if fast_break:
		if Input.is_action_just_pressed("mouse1"):
			player.break_block.emit(hit_pos)
		return

	if not Input.is_action_pressed("mouse1"):
		_reset_breaking()
		return

	var pos := Vector3i(hit_pos.floor())
	if not _breaking or pos != _break_pos: # new target: start over
		_break_pos = pos
		_break_progress = 0.0
		_mine_sfx_timer = 0.0 # so the first hit plays right away
		_breaking = true

	var block: Block = player.world.get_block_at(hit_pos)
	if block == null: return

	_break_progress += delta * mine_speed
	if _break_progress >= block.hardness:
		player.break_block.emit(hit_pos)
		_reset_breaking()
		return

	_mine_sfx_timer -= delta
	if _mine_sfx_timer <= 0.0:
		_mine_sfx_timer = MINE_SFX_INTERVAL
		if block.step_sound != null: _play_sfx(_mine_sfx, block.step_sound)

	var t := clampf(_break_progress / block.hardness, 0.0, 1.0)
	_outline_material.albedo_color = Color.from_hsv(t * 0.8, 0.8, 0.8 - t * 0.8, 0.5)


func _reset_breaking() -> void:
	_breaking = false
	_break_progress = 0.0
	_outline_material.albedo_color = OUTLINE_IDLE

#endregion


func _handle_hotbar() -> void:
	for action in HOTBAR:
		if Input.is_action_just_pressed(action):
			block_selected = HOTBAR[action]


#region Audio

func play_break_sfx() -> void: _play_sfx(sfx, BREAK_SFX)

func play_place_sfx() -> void: _play_sfx(sfx, PLACE_SFX)

func play_pickup_sfx() -> void:
	_pickup_audio.pitch_scale = randf_range(0.90, 1.10)
	_pickup_audio.volume_db = -12
	_pickup_audio.play()

func _play_sfx(source: AudioStreamPlayer3D, stream: AudioStream) -> void:
	source.stream = stream
	source.pitch_scale = randf_range(0.90, 1.10)
	source.play()

#endregion
