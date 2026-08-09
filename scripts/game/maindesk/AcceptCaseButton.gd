extends Button

@export var case_pool_compiler: CasePoolCompiler
@export var case_inventory: CaseInventory
@export var case_spawn_manager: CaseSpawnManager

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var current: Dictionary = case_pool_compiler.current_case

	if current.is_empty():
		return

	case_inventory.add_case(current)
	case_pool_compiler.clear_display()
	case_spawn_manager._set_objects_visible(false)
