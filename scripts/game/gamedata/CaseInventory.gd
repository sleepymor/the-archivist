extends Node
class_name CaseInventory

signal case_added(active_case: Dictionary)
signal case_removed(case_id: String)
signal case_expired(case_id: String)
signal active_case_changed(case_id: String)

var active_cases: Dictionary = {}
var current_active_case_id: String = ""

func add_case(id: String, deadline: float) -> Dictionary:
	if active_cases.has(id):
		push_warning("Case %s sudah ada di inventory" % id)
		return active_cases[id]

	var entry := {
		"id": id,
		"deadline": deadline,
		"investigation_points": 0
	}

	active_cases[id] = entry
	case_added.emit(entry)

	set_current_active_case(id)

	return entry

func remove_case(id: String) -> void:
	if not active_cases.has(id):
		return

	active_cases.erase(id)
	case_removed.emit(id)

	if current_active_case_id == id:
		if active_cases.is_empty():
			set_current_active_case("")
		else:
			set_current_active_case(active_cases.keys().back())

func advance_day(amount: float = 1.0) -> void:
	var expired_ids: Array = []
	for id in active_cases.keys():
		active_cases[id]["deadline"] -= amount
		if active_cases[id]["deadline"] <= 0.0:
			expired_ids.append(id)

	for id in expired_ids:
		case_expired.emit(id)
		remove_case(id)

func add_investigation_point(id: String, amount: int = 1) -> int:
	if not active_cases.has(id):
		push_warning("Case %s tidak ada di active_cases" % id)
		return 0

	active_cases[id]["investigation_points"] += amount
	return active_cases[id]["investigation_points"]

func get_investigation_points(id: String) -> int:
	if not active_cases.has(id):
		return 0
	return active_cases[id]["investigation_points"]

func get_case(id: String) -> Dictionary:
	return active_cases.get(id, {})

func get_all_cases() -> Array:
	return active_cases.values()

func has_case(id: String) -> bool:
	return active_cases.has(id)

func set_current_active_case(id: String) -> void:
	if id != "" and not active_cases.has(id):
		push_warning("Case %s tidak ada di active_cases, gak bisa dijadiin current active case" % id)
		return

	current_active_case_id = id
	active_case_changed.emit(id)

func get_current_active_case() -> Dictionary:
	if current_active_case_id == "":
		return {}
	return active_cases.get(current_active_case_id, {})
