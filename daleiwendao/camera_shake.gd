extends Node

@export var camera_path: NodePath
var camera: Camera2D

var time := 0.0
var duration := 0.0
var strength := 0.0

func _ready():
	add_to_group("shaker")
	camera = get_node(camera_path)


func shake(dur: float, str: float):
	duration = dur
	strength = str
	time = dur


func _process(delta):
	if time <= 0:
		if camera:
			camera.offset = Vector2.ZERO
		return

	time -= delta
	var offset := Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)
	camera.offset = offset
