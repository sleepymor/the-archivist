extends Container
class_name CaseListContainer

@export var case_inventory: CaseInventory
@export var switcher: ObjectSwitcher
@export var item_scene: PackedScene

var _spawned_items: Dictionary = {}

func _ready() -> void:
	case_inventory.case_added.connect(_on_case_added)
	case_inventory.case_removed.connect(_on_case_removed)

	for case_data in case_inventory.get_all_cases():
		_spawn_item(case_data)

func _on_case_added(case_data: Dictionary) -> void:
	_spawn_item(case_data)

func _on_case_removed(case_id: String) -> void:
	if _spawned_items.has(case_id):
		_spawned_items[case_id].queue_free()
		_spawned_items.erase(case_id)

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
