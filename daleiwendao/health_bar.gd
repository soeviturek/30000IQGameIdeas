extends ProgressBar


@export var max_health: int = 100
var current_health: int = max_health

#@onready var bar: ProgressBar = $HealthBar
@onready var damageBar: ProgressBar = $DamageBar
@onready var timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_value = max_health
	value = current_health
	
	damageBar.max_value = max_health
	damageBar.value = current_health

func set_health(val: int):
	current_health = clamp(val, 0, max_health)
	value = current_health
	timer.start()
	
func take_damage(damage: int):
	var new_health = current_health-damage
	set_health(new_health)

func set_max_health(new_max: int):
	max_health = new_max
	max_value = new_max
	current_health = min(current_health, max_health)
	value = current_health

	damageBar.max_value = new_max
	damageBar.value = current_health

func check_death() -> bool:
	if current_health <= 0:
		return true
	return false
	
func _on_timer_timeout() -> void:
	damageBar.value = current_health
