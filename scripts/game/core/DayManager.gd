extends Node
class_name DayManager

signal day_advanced(new_day: int)

@export var day_label: Label

var current_day: int = 1

func _ready() -> void:
	_update_label()

func advance_day() -> void:
	current_day += 1
	_update_label()
	day_advanced.emit(current_day)

func _update_label() -> void:
	if day_label:
		day_label.text = "Day %d" % current_day
