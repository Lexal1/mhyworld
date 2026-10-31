extends Node
## Plays ambient music on a timer, picks the playlist from the mood (menu / day / late / night),
## and can fade in and out from code:
##   await MusicManager.fade_out(2.0).finished
##   MusicManager.fade_in(3.0)

enum Mood { MENU, DAY, LATE, NIGHT }

const LATE_START_HOUR := 21 # real clock: "late" music plays after this hour...
const LATE_END_HOUR := 6    # ...and before this one

@export_group("Playlists") ## Each is an AudioStreamRandomizer (or any stream).
@export var menu_music: AudioStream
@export var day_music: AudioStream
@export var late_music: AudioStream
@export var night_music: AudioStream

@export_group("Timing")
@export var first_delay := 3.5 ## Seconds of silence before the first track.
@export var min_gap := 256.0 ## Silence between tracks, picked randomly in this range.
@export var max_gap := 512.0
@export var switch_on_mood_change := true ## Fade out the current track when the mood changes.
@export var change_fade := 4.0 ## Fade-out length for that switch.
@export var change_delay := 5.0 ## Silence before the next track after a switch.

## Master fade, 0 = silent, 1 = full. Fade functions tween this.
var fade_level := 1.0:
	set(value):
		fade_level = clampf(value, 0.0, 1.0)
		if _player != null:
			_player.volume_db = linear_to_db(maxf(fade_level, 0.0001))

var muted := false ## While true, no new tracks start. Set by fade_out(), cleared by fade_in().

@onready var _player: AudioStreamPlayer = $Player

var _day_night: DayNight
var _mood := Mood.MENU
var _gap_left := 0.0
var _tween: Tween
var _was_playing := false

func _ready() -> void:
	_mood = _current_mood()
	_gap_left = first_delay


func _process(delta: float) -> void:
	var playing := _player.playing
	if _was_playing and not playing:
		_gap_left = randf_range(min_gap, max_gap) # track ended on its own
	_was_playing = playing

	var mood := _current_mood()
	if mood != _mood:
		_mood = mood
		_on_mood_changed()

	if muted or playing: return
	_gap_left -= delta
	if _gap_left <= 0.0: _play_next()


#region Public API

## Fades to silence, stops the track, and keeps new ones from starting until fade_in().
func fade_out(seconds := 2.0) -> Tween:
	muted = true
	return _fade_to(0.0, seconds, true)


## Fades back up. If nothing is playing, the next track starts right away.
func fade_in(seconds := 2.0) -> Tween:
	muted = false
	if not _player.playing: _gap_left = 0.0
	return _fade_to(1.0, seconds, false)


## Fades to any level without stopping, e.g. fade_to(0.3, 1.0) to duck the music.
func fade_to(level: float, seconds := 1.0) -> Tween:
	return _fade_to(level, seconds, false)


## DayNight calls these, so the manager knows the game's time of day.
func register_day_night(dn: DayNight) -> void: _day_night = dn

func unregister_day_night(dn: DayNight) -> void:
	if _day_night == dn: _day_night = null

#endregion


#region Internals

func _fade_to(level: float, seconds: float, stop_at_end: bool) -> Tween:
	if _tween != null: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "fade_level", level, maxf(seconds, 0.0))
	if stop_at_end: _tween.tween_callback(_stop_track)
	return _tween


func _stop_track() -> void:
	_player.stop()
	_was_playing = false # we stopped it, not the track ending
	_gap_left = change_delay


func _on_mood_changed() -> void:
	if _player.playing:
		if switch_on_mood_change and not muted:
			_fade_to(0.0, change_fade, true).finished.connect(
				func(): if not muted: fade_level = 1.0) # ready for the next track
	else:
		_gap_left = minf(_gap_left, change_delay) # don't wait out a long gap in the wrong place


func _play_next() -> void:
	var stream := _stream_for(_mood)
	if stream == null:
		_gap_left = max_gap
		return
	_player.stream = stream
	_player.play()


func _stream_for(mood: Mood) -> AudioStream:
	match mood:
		Mood.DAY: return day_music
		Mood.LATE: return late_music
		Mood.NIGHT: return night_music
	return menu_music


func _current_mood() -> Mood:
	if not is_instance_valid(_day_night): return Mood.MENU
	if _day_night.is_night(): return Mood.NIGHT
	if _is_late_hour() and _day_night.is_night(): return Mood.LATE
	return Mood.DAY


func _is_late_hour() -> bool:
	var hour: int = Time.get_time_dict_from_system()["hour"]
	return hour > LATE_START_HOUR or hour < LATE_END_HOUR

#endregion
