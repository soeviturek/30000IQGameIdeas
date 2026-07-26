extends Resource
class_name ItemBase

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var effects: Array[Effect] = []
@export var price: int = 0

func on_pickup(character: CharacterBase) -> void:
	for effect in effects:
		var e = effect.duplicate(true)
		character.apply_effect(e)
