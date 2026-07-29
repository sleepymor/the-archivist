class_name BoardZone
extends Control

@export var snap_to_center: bool = true

func _ready():
	add_to_group("drop_zone")
	mouse_filter = Control.MOUSE_FILTER_IGNORE 

func on_item_dropped(item: StickyNote):
	if snap_to_center:
		item.global_position = global_position + (size - item.size) / 2
	print(item.name, " dropped di ", name)
