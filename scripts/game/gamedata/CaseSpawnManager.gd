extends Node
class_name CaseSpawnManager

@export var case_pool_compiler: CasePoolCompiler
@export var case_inventory: CaseInventory
@export var day_manager: DayManager
@export var toggle_objects: Array[CanvasItem] = []

const BASE_CHANCE: float = 0.3
const CHANCE_INCREMENT: float = 0.02

var current_chance: float = BASE_CHANCE

func _ready() -> void:
	day_manager.day_advanced.connect(_on_day_advanced)
	call_deferred("_attempt_spawn")

func _on_day_advanced(_new_day: int) -> void:
	_attempt_spawn()

func _attempt_spawn() -> void:
	if case_inventory.active_cases.is_empty():
		_spawn_case()
		return

	var roll: float = randf()
	if roll <= current_chance:
		_spawn_case()
		current_chance = BASE_CHANCE
	else:
		current_chance = min(current_chance + CHANCE_INCREMENT, 1.0)
		_set_objects_visible(false)

func _spawn_case() -> void:
	case_pool_compiler.show_next_case()

	if case_pool_compiler.current_case.is_empty():
		_set_objects_visible(false)
	else:
		_set_objects_visible(true)

func _set_objects_visible(value: bool) -> void:
	for obj in toggle_objects:
		if is_instance_valid(obj):
			obj.visible = value
