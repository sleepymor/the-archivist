extends Node
class_name CasePoolCompiler

@export_file("*.json") var cases_file_path: String = "res://data/cases.json"

@export var title_label: Label
@export var character_name_label: Label
@export var reason_text_label: RichTextLabel

var pool: Array = []
var current_case: Dictionary = {}
var _next_index: int = 0

func _ready() -> void:
	_load_pool()

func _load_pool() -> void:
	if not FileAccess.file_exists(cases_file_path):
		push_error("File tidak ditemukan: " + cases_file_path)
		return

	var file := FileAccess.open(cases_file_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Gagal parse JSON: %s pada baris %d" % [json.get_error_message(), json.get_error_line()])
		return

	pool = json.get_data()

func show_next_case() -> void:
	current_case = _get_next_case()

	if current_case.is_empty():
		title_label.text = "Tidak ada case tersisa"
		character_name_label.text = ""
		reason_text_label.text = ""
		return

	var requester: Dictionary = current_case["requester"]

	title_label.text = current_case["title"]
	character_name_label.text = requester["character_name"]
	reason_text_label.text = requester["reason"]

func clear_display() -> void:
	current_case = {}
	title_label.text = ""
	character_name_label.text = ""
	reason_text_label.text = ""

func _get_next_case() -> Dictionary:
	if _next_index >= pool.size():
		push_warning("Semua case di pool sudah habis")
		return {}

	var c: Dictionary = pool[_next_index]
	_next_index += 1
	return c
