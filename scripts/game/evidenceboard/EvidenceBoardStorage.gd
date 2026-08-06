class_name EvidenceBoardStorage
extends Node

var data: Dictionary = {}

func save_case_board(case_id: String, notes: Array) -> void:
	data[case_id] = notes

func get_case_board(case_id: String) -> Array:
	return data.get(case_id, [])

func has_case_board(case_id: String) -> bool:
	return data.has(case_id)

func clear_case_board(case_id: String) -> void:
	data.erase(case_id)
