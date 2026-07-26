extends Node2D
class_name FireBullet

@export var move_speed: float = 500.0
@export var damage: int = 0

var velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 5.0

func init(direction: Vector2, speed: float, dmg: int) -> void:
	velocity = direction.normalized() * speed
	move_speed = speed
	damage = dmg
	rotation = direction.angle() + PI

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	position += velocity * delta

func _on_area_2d_area_entered(area: Area2D) -> void:
	var obj = area.get_parent()
	if obj.is_in_group("Player") and obj.has_method("take_damage"):
		obj.take_damage(damage, global_position)
		queue_free()
