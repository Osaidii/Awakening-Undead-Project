class_name ammo_box extends interactable

@export var interact_text := "Press E to Open"
@onready var collision: CollisionShape3D = $"../Collision"

var is_opened := false

func _process(_delta: float) -> void:
	if get_parent().visible == true:
		collision.disabled = false

func in_range():
	interaction_tut.text = interact_text
	interaction_tut.visible = true

func not_in_range():
	interaction_tut.visible = false

func interact():
	if !is_opened:
		is_opened = true
		Variables.give_ammo = true
		get_parent().visible = false
		collision.disabled = true
		Variables.reload = true
