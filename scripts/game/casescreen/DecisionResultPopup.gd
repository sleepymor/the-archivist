extends Control
class_name DecisionResultPopup

@export var result_label: Label
@export var reason_label: RichTextLabel
@export var ok_button: Button

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)

func show_result(is_correct: bool, explanation: String) -> void:
	result_label.text = "CORRECT" if is_correct else "WRONG"
	reason_label.text = explanation
	visible = true

func _on_ok_pressed() -> void:
	visible = false
