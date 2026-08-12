extends Container
class_name CaseListContainer

@export var case_inventory: CaseInventory
@export var switcher: ObjectSwitcher
@export var item_scene: PackedScene
@export var day_manager: DayManager

var _spawned_items: Dictionary = {}

func _ready() -> void:
	if case_inventory == null:
		push_error("CaseListContainer: case_inventory tidak di-assign")
		return
	if item_scene == null:
		push_error("CaseListContainer: item_scene tidak di-assign")
		return
	if switcher == null:
		push_error("CaseListContainer: switcher tidak di-assign")
		return

	case_inventory.case_added.connect(_on_case_added)
	case_inventory.case_removed.connect(_on_case_removed)

	if day_manager:
		day_manager.day_advanced.connect(_on_day_advanced)

	for case_data in case_inventory.get_all_cases():
		_spawn_item(case_data)

	_sort_items()

func _on_case_added(case_data: Dictionary) -> void:
	_spawn_item(case_data)
	_sort_items()

func _on_case_removed(case_id: String) -> void:
	if _spawned_items.has(case_id):
		_spawned_items[case_id].queue_free()
		_spawned_items.erase(case_id)

func _on_day_advanced(_new_day: int) -> void:
	for id in _spawned_items:
		var item: CaseItem = _spawned_items[id]
		var case_data: Dictionary = case_inventory.get_case(id)
		if not case_data.is_empty():
			item.refresh_deadline(case_data["deadline"])

	_sort_items()

func _spawn_item(case_data: Dictionary) -> void:
	var id: String = case_data["id"]

	if _spawned_items.has(id):
		return

	var item: CaseItem = item_scene.instantiate()
	add_child(item)
	item.case_inventory = case_inventory
	item.switcher = switcher
	item.setup(case_data)

	_spawned_items[id] = item

func _sort_items() -> void:
	var ids: Array = _spawned_items.keys()

	ids.sort_custom(func(a, b):
		var deadline_a: float = case_inventory.get_case(a).get("deadline", 0.0)
		var deadline_b: float = case_inventory.get_case(b).get("deadline", 0.0)
		return deadline_a < deadline_b
	)

	for i in ids.size():
		move_child(_spawned_items[ids[i]], i)
