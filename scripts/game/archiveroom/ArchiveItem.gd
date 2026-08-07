extends Control
class_name ArchiveItem

@export var title_label: Label

var document: Dictionary = {}

func setup(doc: Dictionary) -> void:
	document = doc
	if title_label:
		title_label.text = doc["fields"].get("title", "")
