extends Node
class_name DocumentPoolLoader

const BASE_PATH := "res://data/storage/document_pool/"

func get_documents_for_case(case_id: String) -> Array:
	var folder_name := case_id.to_lower()
	var dir_path := BASE_PATH + folder_name + "/"

	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Folder dokumen tidak ditemukan: " + dir_path)
		return []

	var result: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var doc := _load_document(dir_path + file_name)
			if not doc.is_empty():
				doc["_file_name"] = file_name
				result.append(doc)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result

func _load_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Gagal parse JSON dokumen: %s" % path)
		return {}

	return json.get_data()
