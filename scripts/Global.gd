@tool
extends Node

signal on_pause
signal on_resume

enum GameState {
	GAMEPLAY,
	UI,
	DIALOG,
	CUTSCENE
}
var state: GameState = GameState.GAMEPLAY
var paused: bool = false

@onready var music_timer: Timer = $Music/Timer
@onready var music: AudioStreamPlayer = $Music
@onready var music_two: AudioStreamPlayer = $Music/MusicTwo

const CHUNK_SIZE = Vector3(16,32,16)

const TEXTURE_ATLAS_SIZE = Vector2(4,4)

var time = Time.get_time_dict_from_system()

var world_seed = Time.get_unix_time_from_system()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("debug2b"):
		var mode := DisplayServer.window_get_mode()
		var is_window: bool = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_window else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_timer_timeout() -> void:
	if Engine.is_editor_hint():
		return
	print(time.get("hour"))
	@warning_ignore("standalone_ternary") music_two.play() if time.get("hour") > 21 or time.get("hour") < 7 else music.play()
	@warning_ignore("standalone_ternary") await music.finished if music.playing else await music_two.finished
	#SHUT UPPPPPPPPP
	music_timer.wait_time = randi_range(9,99)
	music_timer.start()

func set_game_state(g_state: GameState):
	if g_state == GameState.UI:
		paused = true
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) if Global.is_paused() else Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif g_state == GameState.GAMEPLAY:
		paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	state = g_state

func pause_game():
	set_game_state(GameState.UI)
	on_pause.emit()

func resume_game():
	set_game_state(GameState.GAMEPLAY)
	on_resume.emit()

func is_paused():
	return paused

func toggle_pause_state():
	if state == GameState.UI:
		resume_game()
	else:
		pause_game()
