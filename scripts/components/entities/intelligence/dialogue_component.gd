class_name DialogueComponent extends EntityComponent
## Makes an entity talkable. Switches the brain to its Talk state, shows a Markov line
## in the HUD's DialogueBox, and returns to Idle when the conversation ends.

@export_file("*.txt") var text_file := "" ## Plain text the chain learns from.
@export_range(1, 4) var chain_order := 2 ## Words of context. Higher = closer to the source, lower = more nonsense.
@export var min_words := 6
@export var max_words := 24
@export var talk_state: StringName = &"Talk"
@export var idle_state: StringName = &"Idle"
@export var talk_range := 6.0 ## Walk further away than this and the conversation ends.
@export var linger_time := 4.0 ## Seconds the box stays after a line finishes.

var talking := false

var _chain: MarkovChain
var _box: DialogueBox
var _player: Node3D
var _health: HealthComponent
var _linger := 0.0


## The DialogueComponent of `e`, if it can be talked to right now. Otherwise null.
static func talkable(e: Entity) -> DialogueComponent:
	if e == null: return null
	var d := e.get_component(DialogueComponent) as DialogueComponent
	return d if d != null and d.can_talk() else null


func on_attach() -> void:
	_health = entity.get_component(HealthComponent) as HealthComponent
	if text_file.is_empty():
		push_warning("DialogueComponent on '%s' has no text_file" % entity.name)
		return
	_chain = MarkovChain.load_file(text_file, chain_order)


func can_talk() -> bool:
	return _chain != null and not _chain.is_empty() and (_health == null or not _health.dead)


## Right click while typing finishes the line. Right click after that gives a new line.
func interact(player: Player) -> void:
	if not can_talk(): return
	if talking and _box.is_typing():
		_box.skip()
		return
	_player = player
	_box = player.hud.dialogue
	var other := _box.speaker as DialogueComponent
	if other != null and other != self: other.stop_talking()
	if not talking: _start_talking()
	_box.show_line(self, _chain.generate(min_words, max_words))


func stop_talking() -> void:
	if not talking: return
	talking = false
	if is_instance_valid(_box) and _box.speaker == self: _box.close()
	var brain := entity.get_component(BrainComponent) as BrainComponent
	# current is null if the brain was stopped (death), so we leave it alone then.
	if brain != null and brain.current != null and brain.current.name == talk_state:
		brain.change_state(idle_state)


func _start_talking() -> void:
	talking = true
	var brain := entity.get_component(BrainComponent) as BrainComponent
	if brain != null: brain.change_state(talk_state)


func _process(delta: float) -> void:
	if not talking: return
	var too_far := not is_instance_valid(_player) \
		or entity.global_position.distance_to(_player.global_position) > talk_range
	if too_far or not can_talk() or _box.speaker != self:
		stop_talking()
		return
	if _box.is_typing():
		_linger = linger_time
	else:
		_linger -= delta
		if _linger <= 0.0: stop_talking()


func _exit_tree() -> void:
	if talking and is_instance_valid(_box) and _box.speaker == self: _box.close()
