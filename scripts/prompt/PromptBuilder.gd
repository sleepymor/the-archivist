extends Node

const RULE_DIR = "res://data/rules/"
const WORLD_MANIFEST_PATH = "res://data/static/world.json"
const WORLD_CONTEXT_DIR = "res://data/static/world/"

const DEFAULT_MAX_CONTEXT = 2048

func build_generation_prompt(task_type: String, payload: Dictionary = {}) -> Dictionary:
	var selected_modules = _select_rule_modules(task_type)
	var rules_payload = _load_rule_modules(selected_modules)
	var language_id = _normalize_language(payload.get("language", "id"))
	var language_name = _language_label(language_id)
	var context_snapshot = _select_world_context(task_type, payload)
	var task_request = _format_task_request(task_type, payload)

	var system_lines = []
	var context_lines = []
	var prompt_lines = []

	var core = rules_payload.get("core", {})
	if typeof(core) == TYPE_DICTIONARY:
		if core.has("role"):
			system_lines.append("Role: %s" % str(core["role"]))
		if core.has("goal"):
			system_lines.append("Goal: %s" % str(core["goal"]))
		var rule_map = core.get("rules", {})
		if typeof(rule_map) == TYPE_DICTIONARY:
			for key in rule_map.keys():
				if typeof(rule_map[key]) == TYPE_STRING:
					system_lines.append("Rule %s: %s" % [str(key), str(rule_map[key])])

	for module_name in selected_modules:
		if module_name == "core" or module_name == "language":
			continue
		var module = rules_payload.get(module_name, {})
		if typeof(module) == TYPE_DICTIONARY:
			var module_rules = module.get("rules", {})
			if typeof(module_rules) == TYPE_DICTIONARY:
				for key in module_rules.keys():
					if typeof(module_rules[key]) == TYPE_STRING:
						system_lines.append("Rule %s: %s" % [str(key), str(module_rules[key])])

	var lang_module = rules_payload.get("language", {})
	if typeof(lang_module) == TYPE_DICTIONARY:
		var lang_rules = lang_module.get("rules", {})
		if typeof(lang_rules) == TYPE_DICTIONARY:
			for key in lang_rules.keys():
				if typeof(lang_rules[key]) == TYPE_STRING:
					system_lines.append("Rule %s: %s" % [str(key), str(lang_rules[key])])
		if language_name != "":
			system_lines.append("Output language: %s" % language_name)

	if typeof(context_snapshot) == TYPE_DICTIONARY and not context_snapshot.is_empty():
		context_lines.append("Context:")
		context_lines.append(JSON.stringify(context_snapshot, "\t"))

	prompt_lines.append("User request:")
	prompt_lines.append(task_request)

	var full_prompt = _join_lines(system_lines) + "\n\n" + _join_lines(context_lines) + "\n\n" + _join_lines(prompt_lines)
	return {
		"task_type": task_type,
		"selected_modules": selected_modules,
		"language": language_id,
		"language_name": language_name,
		"system_prompt": _join_lines(system_lines),
		"context_payload": context_snapshot,
		"user_prompt": task_request,
		"full_prompt": full_prompt,
		"max_context": DEFAULT_MAX_CONTEXT
	}

func _select_rule_modules(task_type: String) -> Array:
	var modules = []
	if task_type == "character":
		modules = ["core", "character", "world", "language"]
	elif task_type == "document":
		modules = ["core", "document", "world", "language"]
	elif task_type == "investigation" or task_type == "case":
		modules = ["core", "investigation", "world", "language"]
	else:
		modules = ["core", "world", "language"]
	return modules

func _load_rule_modules(modules: Array) -> Dictionary:
	var loaded = {}
	for module_name in modules:
		var path = "%s%s.json" % [RULE_DIR, module_name]
		var data = _load_json_file(path)
		if typeof(data) == TYPE_DICTIONARY:
			loaded[module_name] = data
	return loaded

func _select_world_context(task_type: String, payload: Dictionary) -> Dictionary:
	var context = {}
	var manifest = _load_json_file(WORLD_MANIFEST_PATH)
	if typeof(manifest) == TYPE_DICTIONARY:
		if manifest.has("context_files"):
			var files = manifest["context_files"]
			if typeof(files) == TYPE_DICTIONARY:
				for key in files.keys():
					var file_path = files[key]
					if typeof(file_path) == TYPE_STRING:
						var data = _load_json_file(file_path)
						if typeof(data) == TYPE_DICTIONARY or typeof(data) == TYPE_ARRAY:
							if key == "overview":
								context["overview"] = data
							elif key == "ethnicities":
								context["ethnicities"] = data
							elif key == "languages":
								context["languages"] = data
							elif key == "institutions":
								context["institutions"] = data
							elif key == "generation_constraints":
								context["generation_constraints"] = data
							elif key == "required_elements":
								context["required_elements"] = data
		else:
			if manifest.has("time_period"):
				context["overview"] = {
					"id": manifest.get("id", ""),
					"name": manifest.get("name", ""),
					"description": manifest.get("description", ""),
					"time_period": manifest.get("time_period", {}),
					"historical_context": manifest.get("historical_context", [])
				}
			if manifest.has("Ethnicities"):
				context["ethnicities"] = manifest.get("Ethnicities", [])
			if manifest.has("Languages"):
				context["languages"] = manifest.get("Languages", [])
			if manifest.has("institutions"):
				context["institutions"] = manifest.get("institutions", [])
			if manifest.has("generation_constraints"):
				context["generation_constraints"] = manifest.get("generation_constraints", {})
			if manifest.has("required_elements"):
				context["required_elements"] = manifest.get("required_elements", {})

	if task_type == "document" and payload.has("year"):
		context["current_year"] = payload.get("year")
	if task_type == "document" and payload.has("institution"):
		context["institution"] = payload.get("institution")
	return context

func _format_task_request(task_type: String, payload: Dictionary) -> String:
	if task_type == "character":
		var name = payload.get("name", "Local Resident")
		var gender = payload.get("gender", "unknown")
		var ethnicity = payload.get("ethnicity", "indonesia")
		return "Generate a one-sentence character biography for %s (%s, %s)." % [str(name), str(gender), str(ethnicity)]
	elif task_type == "document":
		var subject = payload.get("subject", "Local Resident")
		var desc = payload.get("description", "Official administrative record.")
		return "Generate a document summary for %s. Details: %s" % [str(subject), str(desc)]
	elif task_type == "investigation" or task_type == "case":
		var char_name = payload.get("character_name", "Local Resident")
		var case_type = payload.get("case_type", "identity_verification")
		return "Generate a brief archive case scenario for %s under case type %s." % [str(char_name), str(case_type)]
	return str(payload)

func _resolve_world_year(context: Dictionary) -> int:
	var overview = context.get("overview", {})
	if typeof(overview) == TYPE_DICTIONARY:
		var time_period = overview.get("time_period", {})
		if typeof(time_period) == TYPE_DICTIONARY:
			var start_year = time_period.get("start_year", 1942)
			if typeof(start_year) == TYPE_INT:
				return int(start_year)
			if typeof(start_year) == TYPE_STRING:
				return start_year.to_int()
	return 1942

func _language_label(language_id: String) -> String:
	if language_id == "en":
		return "English"
	if language_id == "ja":
		return "Japanese"
	if language_id == "nl":
		return "Dutch"
	return "Bahasa Indonesia"

func _normalize_language(language: Variant) -> String:
	if typeof(language) == TYPE_STRING:
		var key = language.strip_edges().to_lower()
		if key == "english" or key == "en":
			return "en"
		if key == "japanese" or key == "ja":
			return "ja"
		if key == "dutch" or key == "nl":
			return "nl"
		if key == "id" or key == "indonesia" or key == "bahasa" or key == "bahasa indonesia":
			return "id"
		return "id"
	return "id"

func _join_lines(lines: Array) -> String:
	var text = ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])
	return text

func _load_json_file(path: String):
	if FileAccess.file_exists(path):
		var read_file = FileAccess.open(path, FileAccess.READ)
		if read_file != null:
			var text = read_file.get_as_text()
			read_file.close()
			return JSON.parse_string(text)
	return null
