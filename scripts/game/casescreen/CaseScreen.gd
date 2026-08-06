extends Control
class_name CaseScreen

@export var case_inventory: CaseInventory
@export var case_pool_compiler: CasePoolCompiler

@export var title_label: Label
@export var case_type_label: Label
@export var deadline_label: Label
@export var requester_name_label: Label
@export var requester_reason_label: RichTextLabel
@export var description_label: RichTextLabel

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	case_inventory.active_case_changed.connect(_on_active_case_changed)

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

	var case_data: Dictionary = _find_case_data(active["id"])

	if case_data.is_empty():
		_clear()
		return

	title_label.text = case_data["title"]
	case_type_label.text = case_data["case_type"]
	deadline_label.text = "Deadline: %s" % str(active["deadline"])

	var requester: Dictionary = case_data["requester"]
	requester_name_label.text = requester["character_name"]
	requester_reason_label.text = requester["reason"]

	description_label.text = case_data["description"]

func _find_case_data(id: String) -> Dictionary:
	for c in case_pool_compiler.pool:
		if c["id"] == id:
			return c
	return {}

func _clear() -> void:
	title_label.text = ""
	case_type_label.text = ""
	deadline_label.text = ""
	requester_name_label.text = ""
	requester_reason_label.text = ""
	description_label.text = ""
