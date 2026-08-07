extends Node
class_name DocumentSpawnManager

@export var case_inventory: CaseInventory
@export var archive_inventory: ArchiveInventory
@export var document_pool_loader: DocumentPoolLoader
@export var day_manager: DayManager

func _ready() -> void:
	if day_manager:
		day_manager.day_advanced.connect(_on_day_advanced)

func _on_day_advanced(_new_day: int) -> void:
	for case_data in case_inventory.get_all_cases():
		_attempt_reveal(case_data["id"])

func _attempt_reveal(case_id: String) -> void:
	var documents: Array = document_pool_loader.get_documents_for_case(case_id)

	var unrevealed: Array = documents.filter(func(d): return not archive_inventory.has_document(case_id, d["_file_name"]))
	if unrevealed.is_empty():
		return

	var doc: Dictionary = unrevealed[randi() % unrevealed.size()]

	var points: int = case_inventory.get_investigation_points(case_id)
	var required: int = doc["fields"].get("investigation_score", 0)

	if points >= required:
		archive_inventory.add_document(case_id, doc)
