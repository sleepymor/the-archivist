extends Control
class_name EvidenceBoard

@export var case_inventory: CaseInventory
@export var case_switch_option_button: OptionButton
@export var storage: EvidenceBoardStorage
@export var dispenser: StickyNote
@export var notes_container: Node

var _last_case_id: String = ""

func _ready() -> void:
	if case_inventory == null or storage == null or dispenser == null or notes_container == null:
		push_error("EvidenceBoard: ada @export yang belum di-assign")
		return

	visibility_changed.connect(_on_visibility_changed)
	case_inventory.active_case_changed.connect(_on_active_case_changed)
	case_inventory.case_added.connect(_on_case_list_changed)
	case_inventory.case_removed.connect(_on_case_list_changed)

	if case_switch_option_button:
		case_switch_option_button.item_selected.connect(_on_option_selected)

func _on_visibility_changed() -> void:
	if visible:
		_rebuild_option_list()
		refresh()

func _on_active_case_changed(_id: String) -> void:
	if visible:
		_switch_board()
		_sync_option_selection()

func _on_case_list_changed(_arg = null) -> void:
	if visible:
		_rebuild_option_list()

func _on_option_selected(index: int) -> void:
	if case_inventory == null:
		return
	var id = case_switch_option_button.get_item_metadata(index)
	if id == null:
		return
	case_inventory.set_current_active_case(id)

func _rebuild_option_list() -> void:
	if case_inventory == null or case_switch_option_button == null:
		return

	case_switch_option_button.clear()
	var cases: Array = case_inventory.get_all_cases()

	for i in cases.size():
		var entry: Dictionary = cases[i]
		if entry == null or not entry.has("id"):
			continue
		case_switch_option_button.add_item(entry["id"])
		case_switch_option_button.set_item_metadata(i, entry["id"])

	_sync_option_selection()

func _sync_option_selection() -> void:
	if case_inventory == null or case_switch_option_button == null:
		return

	var current_id: String = case_inventory.current_active_case_id
	if current_id == "":
		return

	for i in case_switch_option_button.item_count:
		if case_switch_option_button.get_item_metadata(i) == current_id:
			case_switch_option_button.select(i)
			return

func refresh() -> void:
	_switch_board()

func _switch_board() -> void:
	if case_inventory == null:
		return

	_save_current_board()
	_clear_board()

	var active: Dictionary = case_inventory.get_current_active_case()
	if active.is_empty():
		_last_case_id = ""
		return

	_last_case_id = active["id"]
	_load_board(_last_case_id)

func _get_placed_notes() -> Array:
	var result: Array = []
	for child in notes_container.get_children():
		if child is StickyNote and not child.is_dispenser and child.is_placed:
			result.append(child)
	return result

func _save_current_board() -> void:
	if _last_case_id == "":
		return

	var notes: Array = []
	for note in _get_placed_notes():
		notes.append({
			"zone_id": note.current_zone_id,
			"text": note.get_text(),
			"position_x": note.global_position.x,
			"position_y": note.global_position.y
		})

	storage.save_case_board(_last_case_id, notes)

func _clear_board() -> void:
	for child in notes_container.get_children():
		if child is StickyNote and not child.is_dispenser:
			child.queue_free()
			

func _load_board(case_id: String) -> void:
	var notes: Array = storage.get_case_board(case_id)

	for entry in notes:
		var zone: BoardZone = _find_zone(entry["zone_id"])
		if zone == null:
			continue

		var note: StickyNote = dispenser.duplicate()
		note.is_dispenser = false
		notes_container.add_child(note)

		if dispenser.text_edit_path != NodePath():
			note._text_edit = note.get_node(dispenser.text_edit_path)
			note._text_edit.text_changed.connect(note._on_text_edit_changed)
		if dispenser.label_path != NodePath():
			note._label = note.get_node(dispenser.label_path)

		note.set_text(entry["text"])
		note.current_zone_id = zone.zone_id
		note.is_placed = true
		note._label.visible = false
		note._text_edit.visible = true
		note._set_editable(true)
		note.global_position = Vector2(entry["position_x"], entry["position_y"])

func _find_zone(zone_id: String) -> BoardZone:
	for zone in get_tree().get_nodes_in_group("drop_zone"):
		if zone.zone_id == zone_id:
			return zone
	return null
