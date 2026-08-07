extends Control
class_name DocumentViewer

@export var content_label: RichTextLabel
@export var close_button: Button

const EXCLUDED_KEYS := ["investigation_score", "is_true"]

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func show_document(doc: Dictionary) -> void:
	var fields: Dictionary = doc.get("fields", {})
	var bbcode := ""

	for key in fields.keys():
		if key in EXCLUDED_KEYS:
			continue
		bbcode += _render_field(key, fields[key])

	content_label.text = bbcode
	visible = true

func _render_field(key: String, value, depth: int = 0) -> String:
	var label := _humanize_key(key)
	var indent := "  ".repeat(depth)
	var result := ""

	if value is Array:
		result += "%s[b]%s:[/b]\n" % [indent, label]
		for item in value:
			if item is Dictionary:
				for sub_key in item.keys():
					result += _render_field(sub_key, item[sub_key], depth + 1)
				result += "\n"
			else:
				result += "%s- %s\n" % [indent, str(item)]
		result += "\n"
	elif value is Dictionary:
		result += "%s[b]%s:[/b]\n" % [indent, label]
		for sub_key in value.keys():
			result += _render_field(sub_key, value[sub_key], depth + 1)
		result += "\n"
	else:
		result += "%s[b]%s:[/b] %s\n\n" % [indent, label, str(value)]

	return result

func _humanize_key(key: String) -> String:
	var words: PackedStringArray = key.split("_")
	var capitalized: Array = []
	for w in words:
		if w.length() > 0:
			capitalized.append(w[0].to_upper() + w.substr(1))
	return " ".join(capitalized)

func _on_close_pressed() -> void:
	visible = false
