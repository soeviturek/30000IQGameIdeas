extends Camera2D
# 跟随玩家的镜头：平滑跟随 + 限制在竞技场边界内（防止拍到地图外的空气）。
# 挂在 Main/Camera2D 上；墙体已从 Camera2D 移到 Main 下，不再随镜头移动。

@export var target_path: NodePath = ^"../Player"
var _target: Node2D

func _ready() -> void:
	_target = get_node_or_null(target_path)
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	limit_left = int(-ArenaBounds.HALF_WIDTH)
	limit_right = int(ArenaBounds.HALF_WIDTH)
	limit_top = int(-ArenaBounds.HALF_HEIGHT)
	limit_bottom = int(ArenaBounds.HALF_HEIGHT)
	if _target:
		global_position = _target.global_position
		reset_smoothing()

func _process(_delta: float) -> void:
	if _target and is_instance_valid(_target):
		global_position = _target.global_position
