extends Control

@onready var animation: AnimationPlayer = $Animation
@onready var black: ColorRect = $Black
@onready var play_pop_up: Control = $"Play Pop up"
@onready var settings_pop_up: Control = $"Settings Pop up"
@onready var mouse_stopper: ColorRect = $"Mouse Stopper"
@onready var music: AudioStreamPlayer3D = $Music

func _ready() -> void:
	await get_tree().create_timer(1).timeout
	black.visible = true
	animation.play("transition")
	await get_tree().create_timer(1).timeout
	black.visible = false
	for i in range(10):
		music.volume_db += 9

func _on_play_pressed() -> void:
	black.visible = true
	animation.play_backwards("transition")
	await get_tree().create_timer(2).timeout
	animation.play("pop up")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_continue_pressed() -> void:
	animation.play_backwards("pop up")
	await get_tree().create_timer(0.1).timeout
	play_pop_up.visible = false
	await get_tree().create_timer(2).timeout
	black.visible = true
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	for i in range(10):
		music.volume_db -= 9

func _on_settings_pressed() -> void:
	mouse_stopper.visible = false
	animation.play_backwards("setting pop up")
	await get_tree().create_timer(0.1).timeout
	settings_pop_up.visible = false
	mouse_stopper.visible = false
