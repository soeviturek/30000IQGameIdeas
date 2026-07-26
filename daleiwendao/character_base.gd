extends CharacterBody2D
class_name CharacterBase

@onready var stats: CharacterStats = $CharacterStats
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar

var active_effects: Array[Effect] = []

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_process_effects(delta)

func _init_health() -> void:
	health_bar.set_max_health(stats.get_max_health())
	health_bar.set_health(stats.get_max_health())

func take_damage(damage: int, _attacker_position: Vector2) -> void:
	health_bar.take_damage(damage)
	if health_bar.check_death():
		die()

func die() -> void:
	queue_free()

# --- Effect Management ---

func apply_effect(effect: Effect) -> void:
	effect.on_apply(stats)
	active_effects.append(effect)
	_on_stats_changed()

func remove_effect(effect: Effect) -> void:
	effect.on_remove(stats)
	active_effects.erase(effect)
	_on_stats_changed()

func _process_effects(delta: float) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		if effect.tick(delta):
			remove_effect(effect)

func _on_stats_changed() -> void:
	var new_max = stats.get_max_health()
	health_bar.set_max_health(new_max)
