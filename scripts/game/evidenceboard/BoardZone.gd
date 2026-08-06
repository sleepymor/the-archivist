class_name BoardZone
extends Control

@export var zone_id: String = ""
@export var snap_to_center: bool = true

func _ready():
	add_to_group("drop_zone")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if zone_id == "":
		zone_id = name

func on_item_dropped(item: StickyNote):
	if snap_to_center:
		item.global_position = global_position + (size - item.size) / 2
