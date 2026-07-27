extends WeaponBase
class_name RangedWeapon

@export var projectile_scene: PackedScene

@onready var marker = $Marker2D
@onready var shooting_point = $Marker2D/Sprite2D/ShootingPoint

var disable: bool = false

func _ready() -> void:
	super._ready()
	if stats.projectile_speed == 0:
		stats.projectile_speed = 1500

func _is_active() -> bool:
	return not disable

func _update_aiming(_delta: float) -> void:
	var target = get_closest_enemy()
	if target != null:
		marker.look_at(target.global_position)

func _start_attack(attack_data: Dictionary, target: Node2D) -> void:
	if projectile_scene == null:
		return
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = shooting_point.global_position
	projectile.set_tag(owner_tag)
	var roll := _roll_damage(attack_data.damage)
	projectile.init_with_target(target, stats.projectile_speed, roll.damage)
	projectile.is_crit = roll.crit
