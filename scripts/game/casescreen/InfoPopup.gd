extends Control
class_name InfoPopup

@export var message_label: Label
@export var ok_button: Button

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)

func show_message(text: String) -> void:
	message_label.text = text
	visible = true

func _on_ok_pressed() -> void:
	visible = false
