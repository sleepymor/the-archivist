extends Button
class_name CaseItem

@export var id_label: Label
@export var deadline_label: Label
@export var case_inventory: CaseInventory
@export var switcher: ObjectSwitcher

var case_id: String = ""

func setup(data: Dictionary) -> void:
	case_id = data["id"]
	if id_label:
		id_label.text = data["id"]
	if deadline_label:
		deadline_label.text = "Deadline: %s" % str(data["deadline"])

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	case_inventory.set_current_active_case(case_id)
	switcher.switch_to(ObjectSwitcher.ObjectType.CASE)
