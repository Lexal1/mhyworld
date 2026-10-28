extends Node

@export var sun: DirectionalLight3D
@export var sky: WorldEnvironment
@export var label: Label
@export var day_duration := 1440.0 ## Real seconds for a full 24h cycle (night included).
@export_range(0.0, 24.0) var start_hour := 7.0
@export var day_sun_color := Color(1.0, 0.98, 0.92)
@export var horizon_sun_color := Color(1.0, 0.55, 0.25)
@export var day_ambient := 1.0
@export var night_ambient := 0.15
@export var midday_sky_boost := 1.5 ## Sky brightness multiplier at noon. 1.0 = no change.

var time := 0.0 ## 0.0 = midnight, 0.5 = noon. Wraps at 1.0.


func _ready() -> void:
	sun.rotation_degrees.y = 90
	time = start_hour / 24.0
	update_environment()
	LimboConsole.register_command(
		func(): LimboConsole.info(get_time()),
		"time get", "Get the current time in the world.")
	LimboConsole.register_command(
		func(p_time: float): self.time = p_time,
		"time set raw", "Set raw time to a value"
	)
	

func _process(delta: float) -> void:
	time = fposmod(time + delta / day_duration, 1.0)
	update_environment()
	label.text = get_time()


func sun_height() -> float: return -cos(time * TAU) ## 1.0 at noon, 0.0 at sunrise/sunset, -1.0 at midnight.


func update_environment() -> void:
	var height := sun_height()
	var env := sky.environment

	sun.rotation.x = time * TAU

	# Light fades in over the first stretch after sunrise, and out before sunset.
	sun.light_energy = smoothstep(0.0, 0.3, height)
	# Warm near the horizon, neutral when high.
	sun.light_color = horizon_sun_color.lerp(day_sun_color, smoothstep(0.0, 0.5, height))

	# Starts a little before sunrise and ends a little after sunset, for twilight.
	var daylight := smoothstep(-0.1, 0.1, height)
	env.fog_light_energy = daylight
	env.ambient_light_energy = lerpf(night_ambient, day_ambient, daylight)
	# 0 at/below the horizon, 1 at noon. Peaks only when the sun is high.
	var midday := clampf(height, 0.0, 1.0)
	env.background_energy_multiplier = lerpf(1.0, midday_sky_boost, midday)


func is_day() -> bool: return sun_height() > 0.0

func is_night() -> bool: return not is_day()


func get_time(use_12h := false) -> String:
	var total_minutes := int(time * 24.0 * 60.0)
	@warning_ignore("integer_division")
	var hour := total_minutes / 60
	var minute := total_minutes % 60

	if not use_12h:
		return "%d:%02d" % [hour, minute]

	var hour_12 := hour % 12
	if hour_12 == 0: hour_12 = 12
	return "%d:%02d %s" % [hour_12, minute, "AM" if hour < 12 else "PM"]
