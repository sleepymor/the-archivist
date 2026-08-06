extends Button

@export var case_pool_compiler: CasePoolCompiler
@export var case_inventory: CaseInventory

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var current: Dictionary = case_pool_compiler.current_case

	if current.is_empty():
		return

	case_inventory.add_case(current["id"], current["deadline"])

	case_pool_compiler.show_random_case()
