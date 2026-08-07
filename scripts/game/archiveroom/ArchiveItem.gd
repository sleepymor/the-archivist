extends Button
class_name ArchiveItem

@export var document_viewer: DocumentViewer

var document: Dictionary = {}

func setup(doc: Dictionary) -> void:
	document = doc
	text = doc["fields"].get("title", "")

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if document_viewer:
		document_viewer.show_document(document)
