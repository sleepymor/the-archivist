extends Node
class_name ArchiveInventory

signal document_archived(case_id: String, document: Dictionary)

var archived: Dictionary = {}
var stack: Array = []

func add_document(case_id: String, document: Dictionary) -> void:
	if not archived.has(case_id):
		archived[case_id] = []
	archived[case_id].append(document)

	stack.push_front(document)

	document_archived.emit(case_id, document)

func get_documents(case_id: String) -> Array:
	return archived.get(case_id, [])

func has_document(case_id: String, file_name: String) -> bool:
	for doc in get_documents(case_id):
		if doc.get("_file_name", "") == file_name:
			return true
	return false

func get_stack() -> Array:
	return stack
