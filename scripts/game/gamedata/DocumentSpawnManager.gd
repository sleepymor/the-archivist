extends Node
class_name DocumentSpawnManager

signal initial_document_revealed(case_id: String, docs: Array)

@export var case_inventory: CaseInventory
@export var archive_inventory: ArchiveInventory
@export var document_pool_loader: DocumentPoolLoader

var _accumulators: Dictionary = {}
var _document_snapshots: Dictionary = {}

func _ready() -> void:
	case_inventory.case_added.connect(_on_case_added)

func _on_case_added(active_case: Dictionary) -> void:
	var case_id: String = active_case["id"]
	_accumulators[case_id] = 0.0
	_document_snapshots[case_id] = document_pool_loader.get_documents_for_case(case_id).duplicate(true)

	var attempts: int = _consume_attempts(case_id, active_case)
	if attempts <= 0:
		return

	var revealed: Array = _attempt_reveal(case_id, attempts)
	if not revealed.is_empty():
		initial_document_revealed.emit(case_id, revealed)

func process_day(bonus_case_id: String = "") -> Dictionary:
	var results: Dictionary = {}

	for case_data in case_inventory.get_all_cases():
		var case_id: String = case_data["id"]
		var attempts: int = _consume_attempts(case_id, case_data)

		if case_id == bonus_case_id:
			attempts += 1

		if attempts <= 0:
			continue

		var revealed: Array = _attempt_reveal(case_id, attempts)
		if not revealed.is_empty():
			results[case_id] = revealed

	return results

func _consume_attempts(case_id: String, case_data: Dictionary) -> int:
	var documents: Array = _document_snapshots.get(case_id, [])
	var doc_count: int = documents.size()
	var initial_deadline: float = case_data.get("initial_deadline", 1.0)

	if doc_count <= 0 or initial_deadline <= 0.0:
		return 0

	var rate: float = float(doc_count) / initial_deadline

	if not _accumulators.has(case_id):
		_accumulators[case_id] = 0.0

	_accumulators[case_id] += rate

	var attempts: int = int(floor(_accumulators[case_id]))
	_accumulators[case_id] -= attempts

	return attempts

func _attempt_reveal(case_id: String, attempts: int) -> Array:
	var revealed: Array = []
	var documents: Array = _document_snapshots.get(case_id, [])

	for i in attempts:
		var unrevealed: Array = documents.filter(func(d): return not archive_inventory.has_document(case_id, d["_file_name"]))

		if unrevealed.is_empty():
			break

		var doc: Dictionary = unrevealed[randi() % unrevealed.size()]
		var points: int = case_inventory.get_investigation_points(case_id)
		var required: int = doc["fields"].get("investigation_score", 0)

		if points >= required:
			archive_inventory.add_document(case_id, doc)
			revealed.append(doc)

	return revealed
