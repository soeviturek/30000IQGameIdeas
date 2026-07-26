extends Node

# this is a helper script to handle positions and other stuffs maybe we don't need it

# Return global position of a node
static func get_global_pos(node: Node2D) -> Vector2:
	return node.global_position

# Move node to another node's position
static func move_to(node: Node2D, target: Node2D) -> void:
	node.global_position = target.global_position

# Get distance between two nodes
static func distance(a: Node2D, b: Node2D) -> float:
	return a.global_position.distance_to(b.global_position)
