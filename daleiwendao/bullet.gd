extends Node2D
class_name Projectile

@export var move_speed: int = 300
@export var damage: int = 0
@export var target: Node2D = null

var velocity: Vector2 = Vector2.ZERO
var tag: String = ""
var is_crit: bool = false
var _lifetime: float = 5.0

# Called by weapon: shoot towards a target node
func init_with_target(target_node: Node2D, move_speed_val: float, damage_val: int) -> void:
	target = target_node
	move_speed = move_speed_val
	damage = damage_val

func set_tag(tag: String) -> void:
	self.tag = tag
	
# Called by weapon: shoot in a specific direction
func init_with_direction(direction: Vector2, move_speed_val: float, damage_val: int) -> void:
	velocity = direction.normalized() * move_speed_val
	move_speed = move_speed_val
	damage = damage_val

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		# move towards the target
		velocity = (target.global_position - global_position).normalized() * move_speed
		#print("has target, moving")
		#print(velocity)
	# 让箭头朝向飞行方向（箭贴图默认朝上，故 +PI/2）
	if velocity.length() > 0.1:
		rotation = velocity.angle() + PI / 2.0
	position += velocity * delta



func _on_area_2d_area_entered(area: Area2D) -> void:
	var obj = area.get_parent()
	if tag == "Enemy" and obj.is_in_group("Player"):
		obj.take_damage(damage, position)
		queue_free()
	elif tag == "Player" and obj.is_in_group("Enemy"):
		obj.take_damage(damage, global_position - velocity, is_crit)
		queue_free()
	#print(obj.get_groups())
	#print("obj not in player or enemy group")
	
