extends Node

@export var sun : DirectionalLight3D
@export var sky : WorldEnvironment
@export var day_duration = 1440.0/2 ## A day's duration, in seconds. REMEMBER THAT THIS ACCOUNTS FOR NIGHT'S LENGTH TOO!
@export var label : Label

var time : float = 0.0

func _ready() -> void:
	time = 0.30
	sun.rotation_degrees.x = time

func _process(delta: float) -> void:
	time += delta / day_duration
	if time >= 1.0: time = 0
	sun.rotation_degrees.x = time * 360.0
	update_environment()
	label.text = get_time()

func update_environment() -> void:
	var deg_x = sun.rotation_degrees.x
	if is_day(deg_x):
		var intensity = sun_intensity(deg_x)
		sun.light_energy = intensity

func is_day(degree : float) -> bool: return degree > 90 and degree < 270

func is_night(degree : float) -> bool: return not is_day(degree)

func sun_intensity(degree : float) -> float:
	var normalized = (degree - 90.0) / 1500.0
	return sin(normalized * PI)

func get_time(format : bool = false) -> String:
	var minutes : int = int(time * 24 * 60)
	var hour = minutes / 60
	var minute = minutes % 60
	
	var meridian: String = "AM" if hour < 12 else "PM"
	var hour_12 : int = hour % 12
	if hour_12 == 0: hour_12 = 12
	if format == false: return "%d:%02d" % [hour, minute]
	else: return "%d:%02d %s" % [hour_12, minute, meridian]
