extends Line2D
# what the fuck. google ai code that works. im going to hell for this
@export var max_points: int = 50
@export var width_pixels: float = 15.0
@export var scroll_speed: float = 1.5
@export var pulse_rate: float = 2.5    # bpm(Hz)
@export var amplitude: float = 9.0     # Height of the main spike

var time_passed: float = 0.0

func _ready() -> void:
	for i in range(max_points):
		var x_pos = (float(i) / max_points) * width_pixels
		add_point(Vector2(x_pos, 0))

func _process(delta: float) -> void:
	time_passed += delta * scroll_speed
	
	for i in range(max_points):
		var point_pos = get_point_position(i)
		var local_time = time_passed - (point_pos.x * 0.02)
		point_pos.y = calculate_heartbeat_y(local_time)
		set_point_position(i, point_pos)

func calculate_heartbeat_y(t: float) -> float:
	var phase = fmod(t * pulse_rate, 2.0 * PI)
	var y = 0.0
	
	y += 0.15 * exp(-pow((phase - 1.0) / 0.15, 2)) # small initial bump
	y -= 0.20 * exp(-pow((phase - 1.4) / 0.05, 2)) # small dip before spike
	y += 1.00 * exp(-pow((phase - 1.5) / 0.04, 2)) # massive spike
	y -= 0.35 * exp(-pow((phase - 1.6) / 0.05, 2)) # sharp dip after spike
	y += 0.30 * exp(-pow((phase - 2.2) / 0.25, 2)) # medium recovery bump
	
	return -y * amplitude
