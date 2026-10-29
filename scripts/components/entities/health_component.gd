class_name HealthComponent extends EntityComponent

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died(source: Node)

@export var max_health := 10.0
@export var free_entity_on_death := true
@export_group("Heartbeat") ## What the crosshair shows while you look at this entity.
@export var resting_pulse := 1.25
@export var panic_pulse := 3.5 ## Pulse at 0 health. Lower health = faster beat.
@export var pulse_amplitude := 18.0

var health := 0.0
var dead := false


func _ready() -> void:
	health = max_health


func damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0.0: return
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, source)
	if health > 0.0: return
	dead = true
	died.emit(source)
	if free_entity_on_death and entity != null: entity.queue_free()


func heal(amount: float) -> void:
	if dead or amount <= 0.0: return
	health = minf(health + amount, max_health)
	healed.emit(amount)


func fraction() -> float:
	return health / maxf(max_health, 0.001)


func pulse_rate() -> float:
	return lerpf(panic_pulse, resting_pulse, fraction())
