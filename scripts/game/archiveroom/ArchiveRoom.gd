extends Container
class_name ArchiveRoom

@export var archive_inventory: ArchiveInventory
@export var item_scene: PackedScene
@export var search_field: LineEdit

var _spawned_items: Array = []

func _ready() -> void:
	archive_inventory.document_archived.connect(_on_document_archived)

	if search_field:
		search_field.text_changed.connect(_on_search_changed)

	for doc in archive_inventory.get_stack():
		_spawn_item(doc)

func _on_document_archived(_case_id: String, document: Dictionary) -> void:
	_spawn_item(document, true)
	_apply_filter(search_field.text if search_field else "")

func _spawn_item(doc: Dictionary, to_front: bool = false) -> void:
	var item: ArchiveItem = item_scene.instantiate()
	add_child(item)
	item.setup(doc)

	if to_front:
		move_child(item, 0)
		_spawned_items.push_front(item)
	else:
		_spawned_items.append(item)

func _on_search_changed(new_text: String) -> void:
	_apply_filter(new_text)

func _apply_filter(query: String) -> void:
	var normalized_query := query.to_lower()

	for item in _spawned_items:
		if not is_instance_valid(item):
			continue

		if normalized_query == "":
			item.visible = true
			continue

		var title: String = item.document["fields"].get("title", "").to_lower()
		item.visible = title.contains(normalized_query)
