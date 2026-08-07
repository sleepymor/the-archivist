extends Control
class_name DocumentFoundPopup

@export var content_label: RichTextLabel
@export var ok_button: Button

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_pressed)

func show_documents(results: Dictionary) -> void:
	if results.is_empty():
		return

	var lines: Array = []
	for case_id in results.keys():
		var docs: Array = results[case_id]
		var titles: Array = []
		for doc in docs:
			titles.append(doc["fields"].get("title", "Untitled"))
		lines.append("%s: %s" % [case_id, ", ".join(titles)])

	content_label.text = "\n".join(lines)
	visible = true

func _on_ok_pressed() -> void:
	visible = false
