class_name DayNight extends Node

@export var sun: DirectionalLight3D
@export var sky: WorldEnvironment
@export var label: Label
@export var day_duration := 1440.0 ## Real seconds for a full 24h cycle (night included).
@export_range(0.0, 24.0) var start_hour := 6.0

@export_group("Sun")
@export var sun_energy := 1.1
@export var sun_tilt_degrees := 25.0 ## How far the sun's path leans away from straight overhead.
@export var day_sun_color := Color(1.0, 0.98, 0.92)
@export var horizon_sun_color := Color(1.0, 0.55, 0.25) ## Also the sunset glow colour in the sky.

@export_group("Moon")
@export var moon_energy := 0.15
@export var moon_color := Color(0.6, 0.7, 1.0)

@export_group("Clouds")
@export_range(0.0, 1.0) var cloud_cover := 0.5 ## 0 = clear, 1 = overcast. A weather system sets this.

@export_group("Overcast look") ## Blended in as cloud cover passes 0.6. "Clear" values come from the environment resource.
@export_range(0.0, 2.0) var overcast_saturation := 0.7
@export_range(0.0, 2.0) var overcast_brightness := 0.92
@export_range(0.0, 2.0) var overcast_contrast := 1.0 ## Flatter light, so lower than the clear value.
@export var overcast_fog_end := 55.0 ## Fog closes in. Keep it below the clear value.

@export_group("Ambient")
@export var day_ambient := 0.85
@export var night_ambient := 0.2

@export_group("Sky colors") ## Fog uses the horizon colour, so distant terrain fades into the sky.
@export var day_top := Color("3f7fd8")
@export var day_horizon := Color("b4d4ee")
@export var dusk_top := Color("4a5596")
@export var dusk_horizon := Color("e0957a")
@export var night_top := Color("060a1e")
@export var night_horizon := Color("141b3a")

var time := 0.0 ## 0.0 = midnight, 0.5 = noon. Wraps at 1.0.
var day := 0 ## Counts up each noon. Drives the moon phase.
var realtime := false ## When true, `time` follows the computer's clock instead of day_duration.

var _moon: DirectionalLight3D
var _cover_tween: Tween
var _clear_saturation: float
var _clear_brightness: float
var _clear_contrast: float
var _clear_fog_end: float
var _sky_mat: ShaderMaterial


func _ready() -> void:
	time = start_hour / 24.0

	_sky_mat = sky.environment.sky.sky_material as ShaderMaterial
	if _sky_mat == null:
		push_warning("DayNight: the environment's sky isn't a ShaderMaterial using sky.gdshader")

	var env := sky.environment
	_clear_saturation = env.adjustment_saturation
	_clear_brightness = env.adjustment_brightness
	_clear_contrast = env.adjustment_contrast
	_clear_fog_end = env.fog_depth_end

	_moon = DirectionalLight3D.new()
	_moon.light_color = moon_color
	_moon.shadow_enabled = false # one shadow caster (the sun) is plenty
	add_child(_moon)
	MusicManager.register_day_night(self)

	update_environment()
	LimboConsole.register_command(
		func(): LimboConsole.info(get_time()),
		"time get", "Get the current time in the world.")
	LimboConsole.register_command(
		func(): LimboConsole.info(str(get_day())),
		"time day get", "Get the current day.")
	@warning_ignore("narrowing_conversion")
	LimboConsole.register_command(
		func(p_day: float): set_day(p_day),
		"time day set", "Set the day number.")
	LimboConsole.register_command(
		func(p_time: float): self.time = p_time,
		"time set raw", "Set raw time to a value")
	LimboConsole.register_command(
		func(p_hour: float): self.time = p_hour / 24.0,
		"time set hour", "Set the time in hours (0-24).")
	LimboConsole.register_command(
		func(p_cover: float): set_cloud_cover(p_cover),
		"clouds set", "Set cloud cover instantly (0 = clear, 1 = overcast).")
	LimboConsole.register_command(
		func(p_cover: float, p_seconds: float): fade_cloud_cover(p_cover, p_seconds),
		"clouds fade", "Fade cloud cover to a value over some seconds.")
	LimboConsole.register_command(
		func(): LimboConsole.info("realtime: %s" % ("on" if toggle_realtime() else "off")),
		"time realtime", "Toggle syncing world time to your computer's clock. (for fun)")


func _process(delta: float) -> void:
	var prev := time
	if realtime:
		time = _clock_time()
	else:
		time = fposmod(time + delta / day_duration, 1.0)
	if prev < 0.5 and time >= 0.5: day += 1
	update_environment()
	label.text = get_time()


## Local time of day as 0..1 (0.0 = midnight, 0.5 = noon), same scale as `time`.
func _clock_time() -> float:
	var t := Time.get_time_dict_from_system() # local time, not UTC
	return (t["hour"] * 3600.0 + t["minute"] * 60.0 + t["second"]) / 86400.0


func toggle_realtime() -> bool:
	realtime = not realtime
	return realtime


## Weather hooks. Call these from a future weather system.
func set_cloud_cover(value: float) -> void:
	if _cover_tween != null: _cover_tween.kill()
	cloud_cover = clampf(value, 0.0, 1.0)


func fade_cloud_cover(value: float, seconds: float = 30.0) -> void:
	if _cover_tween != null: _cover_tween.kill()
	_cover_tween = create_tween()
	_cover_tween.tween_property(self, "cloud_cover", clampf(value, 0.0, 1.0), seconds)


func get_day() -> int:
	return day


func set_day(value: int):
	day = value


func _exit_tree() -> void:
	MusicManager.unregister_day_night(self)


## The sun's path is a circle in the XY plane, leaned over by sun_tilt_degrees.
## The star field uses the same basis, so stars rotate with the sun.
func _celestial() -> Basis:
	var angle := (time - 0.25) * TAU # 0 at sunrise (6:00), PI/2 at noon
	return Basis(Vector3.RIGHT, deg_to_rad(sun_tilt_degrees)) * Basis(Vector3.BACK, angle)


func sun_direction() -> Vector3: return _celestial() * Vector3.RIGHT ## Points toward the sun.

func sun_height() -> float: return sun_direction().y ## 1.0 at noon (before tilt), 0.0 at sunrise/sunset.


func update_environment() -> void:
	var celestial := _celestial()
	var sun_dir := celestial * Vector3.RIGHT
	var h := sun_dir.y

	# Sun: a light shines along its own -Z, so it travels from the sun toward the ground.
	var overcast := smoothstep(0.6, 1.0, cloud_cover) # same curve the sky shader uses for dark clouds
	_aim(sun, -sun_dir)
	sun.light_energy = sun_energy * smoothstep(0.0, 0.25, h) * lerpf(1.0, 0.35, overcast)
	sun.light_color = horizon_sun_color.lerp(day_sun_color, smoothstep(0.0, 0.5, h))
	sun.visible = h > 0.0 # no shadow pass at night

	# Moon: always opposite the sun.
	_aim(_moon, sun_dir)
	_moon.light_energy = moon_energy * smoothstep(0.0, 0.25, -h)
	_moon.visible = h < 0.0

	# Grey the sky here (not in the shader) so the fog colour follows it too.
	var top := _grey_out(_ramp(night_top, dusk_top, day_top, h), overcast)
	var horizon := _grey_out(_ramp(night_horizon, dusk_horizon, day_horizon, h), overcast)
	var dusk := (1.0 - smoothstep(0.0, 0.35, absf(h))) * lerpf(1.0, 0.4, overcast) # 1 at sunrise/sunset
	var daylight := smoothstep(-0.1, 0.25, h)

	if _sky_mat != null:
		var atlas: Vector2 = _sky_mat.get_shader_parameter("moon_atlas")
		_sky_mat.set_shader_parameter("sky_top", top)
		_sky_mat.set_shader_parameter("sky_horizon", horizon)
		_sky_mat.set_shader_parameter("glow_color", horizon_sun_color)
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("celestial_basis", celestial.inverse())
		_sky_mat.set_shader_parameter("cloud_cover", cloud_cover)
		_sky_mat.set_shader_parameter("dusk", dusk)
		_sky_mat.set_shader_parameter("daylight", daylight)
		_sky_mat.set_shader_parameter("star_amount", 1.0 - smoothstep(-0.15, 0.05, h))
		_sky_mat.set_shader_parameter("moon_frame", day % maxi(1, int(atlas.x * atlas.y)))

	var env := sky.environment
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(night_ambient, day_ambient, daylight) * lerpf(1.0, 0.7, overcast)

	# Colour grading and fog follow the weather too.
	env.adjustment_saturation = lerpf(_clear_saturation, overcast_saturation, overcast)
	env.adjustment_brightness = lerpf(_clear_brightness, overcast_brightness, overcast)
	env.adjustment_contrast = lerpf(_clear_contrast, overcast_contrast, overcast)
	env.fog_depth_end = lerpf(_clear_fog_end, overcast_fog_end, overcast)


## Night -> dusk -> day, picked by sun height. Dusk colours sit exactly at the horizon.
func _ramp(night_color: Color, dusk_color: Color, day_color: Color, h: float) -> Color:
	if h >= 0.0:
		return dusk_color.lerp(day_color, smoothstep(0.0, 0.45, h))
	return dusk_color.lerp(night_color, smoothstep(0.0, 0.3, -h))


func _grey_out(c: Color, amount: float) -> Color:
	var g := c.get_luminance() * 0.85
	var grey := c.lerp(Color(g, g, g), amount * 0.6)
	var k := lerpf(1.0, 0.75, amount) # grey AND darker
	return Color(grey.r * k, grey.g * k, grey.b * k)


func _aim(light: Node3D, travel_dir: Vector3) -> void:
	# looking_at breaks if the direction is parallel to `up`, so swap `up` when nearly vertical.
	var up := Vector3.RIGHT if absf(travel_dir.y) > 0.99 else Vector3.UP
	light.global_basis = Basis.looking_at(travel_dir, up)


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
