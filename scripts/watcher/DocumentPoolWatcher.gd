extends Node

const CASE_POOL_FILE_PATH = "res://data/storage/case_pool.json"
const DOCUMENT_POOL_BASE_PATH = "res://data/storage/document_pool/"

@export var document_generator_node_path: NodePath
@export var case_generator_node_path: NodePath

@onready var document_generator = get_node_or_null(document_generator_node_path)
@onready var case_generator = get_node_or_null(case_generator_node_path)

var _is_busy: bool = false

func _ready() -> void:
	if document_generator and not document_generator.is_connected("documents_ready", _on_documents_generated):
		document_generator.connect("documents_ready", _on_documents_generated)
			
	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	if not case_pool.is_empty():
		call_deferred("check_document_pools")

func check_document_pools() -> void:
	if _is_busy:
		return

	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	if case_pool.is_empty():
		return

	for case_item in case_pool:
		if typeof(case_item) != TYPE_DICTIONARY:
			continue
		
		var case_id = case_item.get("id", "")
		var doc_types = case_item.get("documents", [])
		var char_name = case_item.get("requester", {}).get("character_name", "Local Resident")
		var safe_char_name = char_name.strip_edges().replace(" ", "_")
		
		if case_id.is_empty() or doc_types.is_empty():
			continue

		var case_folder = DOCUMENT_POOL_BASE_PATH + case_id.to_lower() + "/"
		var missing_or_invalid = false

		for dtype in doc_types:
			var file_path = case_folder + "%s_%s.json" % [dtype, safe_char_name]
			if not FileAccess.file_exists(file_path):
				missing_or_invalid = true
				break
			else:
				var f = FileAccess.open(file_path, FileAccess.READ)
				if f != null:
					var content = JSON.parse_string(f.get_as_text())
					f.close()
					if typeof(content) != TYPE_DICTIONARY or content.is_empty():
						missing_or_invalid = true
						break
				else:
					missing_or_invalid = true
					break

		if missing_or_invalid:
			_is_busy = true
			print("DocumentPoolWatcher: Missing documents found for existing case [%s]. Generating..." % case_id)
			if document_generator and document_generator.has_method("generate_documents_for_case"):
				document_generator.generate_documents_for_case(case_item)
			else:
				_is_busy = false
				print("DocumentPoolWatcher Error: DocumentGenerator node is missing or invalid.")
			return

func _on_documents_generated(documents_data: Array) -> void:
	_is_busy = false
	print("DocumentPoolWatcher: Document verification/generation sweep finished successfully.")
	call_deferred("check_document_pools")

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var read_file = FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		return []
	var content = read_file.get_as_text().strip_edges()
	read_file.close()
	if content.is_empty():
		return []
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	elif parsed != null:
		return [parsed]
	return []