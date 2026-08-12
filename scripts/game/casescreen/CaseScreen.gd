extends Control
class_name CaseScreen

@export var case_inventory: CaseInventory

@export var title_label: Label
@export var case_type_label: Label
@export var deadline_label: Label
@export var requester_name_label: Label
@export var requester_reason_label: RichTextLabel
@export var description_label: RichTextLabel

var _document_panel: Control
var _document_content: Control

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	case_inventory.active_case_changed.connect(_on_active_case_changed)
	_document_panel = get_node("Dynamic/Document")
	_document_content = get_node("Dynamic/Document/VBoxContainer")
	if _document_panel == null:
		push_error("CaseScreen: node Dynamic/Document tidak ditemukan")
	if _document_content == null:
		push_error("CaseScreen: node Dynamic/Document/VBoxContainer tidak ditemukan")

func _on_visibility_changed() -> void:
	if visible:
		refresh()

func _on_active_case_changed(_id: String) -> void:
	if visible:
		refresh()

func refresh() -> void:
	var active: Dictionary = case_inventory.get_current_active_case()

	if active.is_empty():
		_clear()
		return

	var case_data: Dictionary = active.get("data", {})
	if case_data.is_empty():
		_clear()
		return

	if _document_panel:
		_document_panel.visible = true
	if _document_content:
		_document_content.visible = true

	title_label.text = case_data["title"]
	case_type_label.text = case_data["case_type"]
	deadline_label.text = "Deadline: %s" % str(active["deadline"])

	var requester: Dictionary = case_data["requester"]
	requester_name_label.text = requester["character_name"]
	requester_reason_label.text = requester["reason"]

	description_label.text = case_data["description"]

func _clear() -> void:
	if _document_panel:
		_document_panel.visible = false
	if _document_content:
		_document_content.visible = false
	title_label.text = ""
	case_type_label.text = ""
	deadline_label.text = ""
	requester_name_label.text = ""
	requester_reason_label.text = ""
	description_label.text = ""

#func _clear() -> void:
	#title_label.text = ""
	#case_type_label.text = ""
	#deadline_label.text = ""
	#requester_name_label.text = ""
	#requester_reason_label.text = ""
	#description_label.text = ""
