extends MonsterBase

var can_attack: bool = true

func _ready() -> void:
	super._ready()
	stats.init_character(
		"Kobolt",
		200.0,
		1,
		120,
		25,
		1,
		20,
		10
	)
	_init_health()

func _attack() -> void:
	if _player == null or not can_attack:
		return
	var distance = global_position.distance_to(_player.global_position)
	if distance <= stats.get_attack_range():
		if _player.has_method("take_damage"):
			_player.take_damage(stats.get_attack_damage(), global_position)
			can_attack = false
			get_tree().create_timer(stats.get_attack_speed()).timeout.connect(func(): can_attack = true)
