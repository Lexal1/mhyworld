class_name Crosshair extends Line2D
## Sweep-style ECG. One heartbeat fills the whole strip, with the R spike in the middle.
## BPM only changes how fast the pen sweeps.

const REST_BPM := 70.0
const SUBSTEPS := 6 ## Samples per column. The biggest one wins, so thin spikes aren't missed.
const R_PEAK := 0.2 ## Where the R spike sits inside a beat (see _ecg).
const DAMAGE_COLOR := Color(0.9, 0.05, 0.05)

@export var width_pixels := 30.0
@export var amplitude := 18.0   ## Pixels tall the R spike is. A HealthComponent's value overrides it.
@export var gap_columns := 2    ## Blank columns ahead of the pen.
@export var max_drift := 8.0 ## Columns the spike can wander at 0 health.


var heartbeat_source: HealthComponent ## Whatever health the trace follows.

var _shape := PackedFloat32Array()   # the beat, one value per column. Never changes.
var _samples := PackedFloat32Array() # what's on screen. The pen overwrites it column by column.
var _col := 0     # column the pen just wrote
var _acc := 0.0   # leftover fraction of a column
var _amp := 0.0
var _shift := 0 ## This sweep's offset, picked each time the pen wraps.
var _base_color: Color
var _color: Color


func _ready() -> void:
	clear_points()
	var n := maxi(int(width_pixels), 2)
	_shape.resize(n)
	_samples.resize(n)
	for i in n:
		_shape[i] = _column_value(i, n)
	_samples = _shape.duplicate()
	_amp = amplitude
	_base_color = default_color
	_color = _base_color


func _process(delta: float) -> void:
	var bpm := REST_BPM
	var health_fraction := 1.0
	_amp = amplitude
	if is_instance_valid(heartbeat_source):
		bpm = heartbeat_source.pulse_bpm()
		_amp = heartbeat_source.pulse_amplitude
		health_fraction = heartbeat_source.fraction()

	var redraw := false
	var tint := _base_color.lerp(DAMAGE_COLOR, 1.0 - health_fraction)
	if tint != _color:
		_color = tint
		redraw = true

	# One beat per sweep. A flatline keeps sweeping at the resting speed, but writes zeros.
	var n := _samples.size()
	var flat := bpm <= 0.0
	_acc += n * (REST_BPM if flat else bpm) / 60.0 * delta
	while _acc >= 1.0:
		_acc -= 1.0
		_col = (_col + 1) % n
		if _col == 0: # new sweep, new offset
			_shift = roundi(randf_range(-1.0, 1.0) * max_drift * (1.0 - health_fraction))
		_samples[_col] = 0.0 if flat else _shape[posmod(_col - _shift, n)]
		redraw = true
	if redraw: queue_redraw()


## Biggest value inside one column. The beat is shifted so the R spike lands mid-strip.
func _column_value(i: int, n: int) -> float:
	var best := 0.0
	for k in SUBSTEPS:
		var p := fposmod((i + float(k) / SUBSTEPS) / n + R_PEAK - 0.5, 1.0)
		var v := _ecg(p)
		if absf(v) > absf(best): best = v
	return best


## One heartbeat, p = 0..1. P wave, QRS spike, T wave.
func _ecg(p: float) -> float:
	return _bump(p, 0.10, 0.025, 0.12) \
		+ _bump(p, 0.185, 0.008, -0.12) \
		+ _bump(p, R_PEAK, 0.010, 1.0) \
		+ _bump(p, 0.215, 0.010, -0.25) \
		+ _bump(p, 0.42, 0.05, 0.30)


func _bump(x: float, center: float, sigma: float, height: float) -> float:
	return height * exp(-pow((x - center) / sigma, 2.0))


func _draw() -> void:
	var n := _samples.size()
	var x_offset := -n * 0.5 # column n/2 (the spike) sits at x = 0
	var run := PackedVector2Array()
	for i in n:
		var d := posmod(i - _col, n)
		if d >= 1 and d <= gap_columns:
			_flush(run)
			run = PackedVector2Array()
			continue
		run.push_back(Vector2(i + x_offset, -_samples[i] * _amp))
	_flush(run)


func _flush(run: PackedVector2Array) -> void:
	if run.size() >= 2:
		draw_polyline(run, _color, width)
	elif run.size() == 1:
		draw_rect(Rect2(run[0] - Vector2(0, width * 0.5), Vector2(1, width)), _color)
