extends WeaponBase
class_name SwingMelee

@onready var pivot = $Pivot
@onready var animation_player = $AnimationPlayer

var swinging: bool = false
var enemies_hit_this_swing := {}

func _ready() -> void:
	super._ready()
	if not stats.configured:
		stats.configured = true
		stats.attack_dmg = 30
		stats.default_cooldown = 1.5
		stats.attack_range = 100

func _can_perform_attack() -> bool:
	return not swinging

func _update_aiming(_delta: float) -> void:
	if swinging:
		return
	var target_in_range = get_closest_enemy()
	var target_any = get_closest_enemy_any_range()
	if target_in_range:
		pivot.look_at(target_in_range.global_position)
	elif target_any:
		pivot.look_at(target_any.global_position)
	else:
		pivot.global_rotation = 0

func _start_attack(_attack_data: Dictionary, _target: Node2D) -> void:
	swinging = true
	enemies_hit_this_swing.clear()
	animation_player.play("attack")

func _on_area_2d_area_entered(area: Area2D) -> void:
	var obj = area.get_parent()
	if not obj or not obj.is_in_group("Enemy"):
		return
	if not swinging:
		return
	if obj in enemies_hit_this_swing:
		return
	enemies_hit_this_swing[obj] = true
	var roll := _roll_damage(stats.get_final_damage(_char_stats))
	obj.take_damage(roll.damage, global_position, roll.crit)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	swinging = false
	enemies_hit_this_swing.clear()
