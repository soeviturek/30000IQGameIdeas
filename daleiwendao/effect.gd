extends Resource
class_name Effect

@export var effect_name: String = ""
@export var modifiers: Array[Modifier] = []
@export var duration: float = -1.0 # negative = permanent

var remaining_time: float = 0.0
var _applied: bool = false

func is_permanent() -> bool:
	return duration < 0.0

func on_apply(char_stats) -> void:
	if _applied:
		return
	_applied = true
	remaining_time = duration
	for mod in modifiers:
		char_stats.add_modifier(mod)

func on_remove(char_stats) -> void:
	if not _applied:
		return
	_applied = false
	for mod in modifiers:
		char_stats.remove_modifier(mod)

func tick(delta: float) -> bool:
	if is_permanent():
		return false
	remaining_time -= delta
	return remaining_time <= 0.0
