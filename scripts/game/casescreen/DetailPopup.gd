extends Control

@export var ok_button: Button

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)

func _on_ok_pressed() -> void:
	visible = false
