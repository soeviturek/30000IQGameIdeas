extends WeaponBase
class_name SlashWeapon

@export var sword_qi_scene: PackedScene

@onready var pivot = $Pivot
@onready var animation_player = $AnimationPlayer

const QI_SPAWN_FORWARD := 40.0

var slashing: bool = false

func _ready() -> void:
	super._ready()
	if not stats.configured:
		stats.configured = true
		stats.attack_dmg = 25
		stats.default_cooldown = 1.2
		stats.attack_range = 200

func _can_perform_attack() -> bool:
	return not slashing

func _update_aiming(_delta: float) -> void:
	if slashing:
		return
	var target = get_closest_enemy()
	if target:
		pivot.look_at(target.global_position)
	# No target in range — don't aim anywhere

func _start_attack(attack_data: Dictionary, target: Node2D) -> void:
	slashing = true
	animation_player.play("slash")
	Sfx.play("attack", -5.0)
	_spawn_sword_qi(target)
	# Damage all enemies in range
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var final_range = stats.get_final_range(_char_stats)
	for enemy in enemies:
		var dist = (enemy.global_position - global_position).length()
		if dist <= final_range and enemy.has_method("take_damage"):
			var roll := _roll_damage(attack_data.damage)
			enemy.take_damage(roll.damage, global_position, roll.crit)

func _spawn_sword_qi(target: Node2D) -> void:
	if sword_qi_scene == null or target == null:
		return
	var dir := (target.global_position - global_position).angle()
	var qi := sword_qi_scene.instantiate()
	get_tree().current_scene.add_child(qi)
	qi.global_position = global_position + Vector2.RIGHT.rotated(dir) * QI_SPAWN_FORWARD
	qi.launch(dir)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	slashing = false
