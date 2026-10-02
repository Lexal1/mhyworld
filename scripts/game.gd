extends Node3D

var chunk_scene = preload("res://scenes/chunk.tscn")

@export var render_distance = 5 ## Determines how many chunks to load around the player, in a radius.

@onready var player: CharacterBody3D = $Player
@onready var die: AudioStreamPlayer = $die
@onready var environment: Node = $World/Environment/Sky
@onready var world: Node3D = $World
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	Global.on_pause.connect(show_pause_menu)
	Global.on_resume.connect(hide_pause_menu)

func _on_player_die() -> void:
	Global.gameIsQuitting = true
	Global.music.stream_paused = true
	environment.environment.background_mode = Environment.BG_KEEP
	die.play()
	await die.finished
	get_tree().quit()
	
func show_pause_menu():
	pause_menu.show()

func hide_pause_menu():
	pause_menu.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Mhyworld is closing, we gotta clean up!")
		Global.gameIsQuitting = true
		Global.Tasks.force_wait_for_tasks()
		get_tree().quit()
