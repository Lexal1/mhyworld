class_name Crosshair extends Line2D
# what the fuck. google ai code that works. im going to hell for this
@export var max_points: int = 50
@export var width_pixels: float = 15.0
@export var scroll_speed: float = 1.5
@export var pulse_rate: float = 2.5    # bpm(Hz)
@export var amplitude: float = 9.0     # Height of the main spike

var heartbeat_source: HealthComponent ## Set while looking at something with health.
var _phase := 0.0

func _ready() -> void:
	for i in range(max_points):
		var x_pos = (float(i) / max_points) * width_pixels
		add_point(Vector2(x_pos, 0))

func _process(delta: float) -> void:
	var rate := pulse_rate
	var amp := amplitude
	if is_instance_valid(heartbeat_source):
		rate = heartbeat_source.pulse_rate()
		amp = heartbeat_source.pulse_amplitude
	
	_phase += delta * scroll_speed * rate # accumulate, so a changing rate never makes the wave jump
	
	for i in range(max_points):
		var point_pos = get_point_position(i)
		var phase := fposmod(_phase - point_pos.x * 0.02 * rate, 2.0 * PI)
		point_pos.y = -calculate_heartbeat(phase) * amp
		set_point_position(i, point_pos)

func calculate_heartbeat(phase: float) -> float:
	var y = 0.0
	
	y += 0.15 * exp(-pow((phase - 1.0) / 0.15, 2)) # small initial bump
	y -= 0.20 * exp(-pow((phase - 1.4) / 0.05, 2)) # small dip before spike
	y += 1.00 * exp(-pow((phase - 1.5) / 0.04, 2)) # massive spike
	y -= 0.35 * exp(-pow((phase - 1.6) / 0.05, 2)) # sharp dip after spike
	y += 0.30 * exp(-pow((phase - 2.2) / 0.25, 2)) # medium recovery bump
	
	return y
