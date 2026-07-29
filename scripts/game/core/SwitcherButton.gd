extends Button

@export var switcher: Node
@export var target: ObjectSwitcher.ObjectType

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	switcher.switch_to(target)
