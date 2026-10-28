@tool
extends Node

signal on_pause
signal on_resume

enum GameState { TITLE, GAMEPLAY, UI, DIALOG, CUTSCENE }
enum WorldSize { SMALL = 2048, MEDIUM = 4096, LARGE = 8192 }
enum WorldHeights { SMALL = 64, MEDIUM = 128, LARGE = 256 }

const CHUNK_SIZE := Vector3i(16, 16, 16)
const TEXTURE_ATLAS_SIZE := Vector2(16, 16)
const NIGHT_START_HOUR := 21 # night music plays after this hour...
const NIGHT_END_HOUR := 6    # ...and before this one

var state := GameState.GAMEPLAY
var paused := false
var gameIsQuitting := false
var world_seed := int(Time.get_unix_time_from_system())
var world_size: int = WorldSize.SMALL ## Blocks across on each axis. Set before the world loads.
var world_height: int = WorldHeights.SMALL ## Blocks tall. Set before the world loads.

var Tasks := TaskManager.new()

@onready var music_timer: Timer = $Music/Timer
@onready var music: AudioStreamPlayer = $Music
@onready var music_two: AudioStreamPlayer = $Music/MusicTwo
@onready var canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	if not Engine.is_editor_hint():
		canvas_layer.visible = true

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event.is_action_pressed("debug2b"):
		var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

## Maps any chunk coordinate into 0..(world_size / CHUNK_SIZE) on each axis.
func wrap_chunk(c: Vector3i) -> Vector3i:
	var n := world_size / CHUNK_SIZE.x # chunks across (same on X and Z)
	return Vector3i(posmod(c.x, n), c.y, posmod(c.z, n))

#region Music

func _is_night() -> bool:
	var hour: int = Time.get_time_dict_from_system()["hour"]
	return hour > NIGHT_START_HOUR or hour < NIGHT_END_HOUR


func _on_timer_timeout() -> void:
	if Engine.is_editor_hint(): return

	var track := music_two if _is_night() else music
	track.play()
	await track.finished

	music_timer.wait_time = randi_range(9, 99)
	music_timer.start()

#endregion

#region GameState

func set_game_state(g_state: GameState) -> void:
	if g_state == GameState.UI:
		paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		on_pause.emit()
	elif g_state == GameState.GAMEPLAY:
		paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		on_resume.emit()
	state = g_state


func pause_game() -> void: set_game_state(GameState.UI)

func resume_game() -> void: set_game_state(GameState.GAMEPLAY)

func is_paused() -> bool: return paused

func toggle_pause_state() -> void:
	set_game_state(GameState.GAMEPLAY if state == GameState.UI else GameState.UI)

#endregion
