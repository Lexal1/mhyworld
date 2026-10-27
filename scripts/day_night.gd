extends Node

@export var sun: DirectionalLight3D
@export var sky: WorldEnvironment
@export var day_duration := 1440.0 ## A full day in seconds. REMEMBER THAT THIS ACCOUNTS FOR NIGHT'S LENGTH TOO!
@export var label: Label

const DAY_START_DEG := 90.0
const DAY_END_DEG := 275.0

var time := 0.30 # 0.0 - 1.0 through the day


func _ready() -> void:
	sun.rotation_degrees.x = time * 360.0


func _process(delta: float) -> void:
	time = fposmod(time + delta / day_duration, 1.0)
	sun.rotation_degrees.x = time * 360.0
	update_environment()
	label.text = get_time()


func update_environment() -> void:
	var deg := sun.rotation_degrees.x
	sun.light_energy = sun_intensity(deg) if is_day(deg) else 0.0 # HACK FIX! PLEASE FIX LATER


func is_day(degree: float) -> bool:
	return degree > DAY_START_DEG and degree < DAY_END_DEG


func is_night(degree: float) -> bool:
	return not is_day(degree)


func sun_intensity(degree: float) -> float:
	var normalized := (degree - DAY_START_DEG) / 1500.0
	return sin(normalized * PI)


func get_time(use_12h := false) -> String:
	var total_minutes := int(time * 24 * 60)
	@warning_ignore("integer_division")
	var hour := total_minutes / 60
	var minute := total_minutes % 60

	if not use_12h:
		return "%d:%02d" % [hour, minute]

	var hour_12 := hour % 12
	if hour_12 == 0: hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute, "AM" if hour < 12 else "PM"]
