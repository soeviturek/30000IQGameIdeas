extends MonsterBase

var can_attack: bool = true

# 打完人后的收招硬直（小停顿当冷却）：停步 + 后撤，给玩家喘息窗口
const MELEE_RECOVERY := 0.55
var _recovery: float = 0.0

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

func _physics_process(delta: float) -> void:
	if _recovery > 0.0:
		_recovery -= delta
	super._physics_process(delta)

func _move(delta: float) -> void:
	if _recovery > 0.0:
		# 收招硬直：减速停步 + 播放 idle
		velocity = velocity.move_toward(Vector2.ZERO, stats.get_move_speed() * delta * 6.0)
		animated_sprite.play("idle")
		return
	super._move(delta)

func _attack() -> void:
	if _player == null or not can_attack:
		return
	var distance = global_position.distance_to(_player.global_position)
	if distance <= stats.get_attack_range():
		if _player.has_method("take_damage"):
			_player.take_damage(stats.get_attack_damage(), global_position)
			can_attack = false
			# 收招硬直 + 后撤一步（打完人的小停顿）
			_recovery = MELEE_RECOVERY
			var back := (global_position - _player.global_position).normalized()
			velocity = back * 130.0
			get_tree().create_timer(stats.get_attack_speed()).timeout.connect(func(): can_attack = true)
