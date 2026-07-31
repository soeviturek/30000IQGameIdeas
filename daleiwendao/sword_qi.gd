extends Node2D
# 剑气：每次挥砍时朝目标方向生成，快速前冲 + 放大 + 淡出。
# 纯表现效果，不额外造成伤害（近战本体已对范围内的怪造成 AoE 伤害）。

const TRAVEL := 90.0            # 向前飞出的距离
const LIFE := 0.30             # 存活/淡出时长
const ART_OFFSET := -1.5707963 # 剑气贴图默认朝向的修正：让弧的凸面朝飞行方向

func launch(dir_angle: float) -> void:
	rotation = dir_angle + ART_OFFSET
	scale = Vector2(0.7, 1.0)
	modulate = Color(0.65, 1.0, 0.92, 0.95)   # 青碧剑气
	var fwd := Vector2.RIGHT.rotated(dir_angle)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + fwd * TRAVEL, LIFE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(2.0, 1.6), LIFE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
