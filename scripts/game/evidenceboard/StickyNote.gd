class_name StickyNote
extends Control

@export var is_dispenser: bool = false
@export var text_edit_path: NodePath
@export var label_path: NodePath

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var is_placed: bool = false

var _text_edit: TextEdit
var _label: Label

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	if text_edit_path != NodePath():
		_text_edit = get_node(text_edit_path)
		_text_edit.visible = false   # sembunyikan dari awal
		_set_editable(false)

	if label_path != NodePath():
		_label = get_node(label_path)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		else:
			if _dragging:
				_stop_drag()

func _start_drag():
	var target: StickyNote = self

	if is_dispenser:
		target = duplicate()
		target.is_dispenser = false
		get_parent().add_child(target)
		target.global_position = global_position
		target.z_index = 0

		if text_edit_path != NodePath():
			target._text_edit = target.get_node(text_edit_path)
			target._text_edit.visible = false
			target._set_editable(false)

		if label_path != NodePath():
			target._label = target.get_node(label_path)
			target._label.visible = false
	else:
		if _label:
			_label.visible = false

	target._dragging = true
	target._drag_offset = target.global_position - target.get_global_mouse_position()
	target.z_index = 10
	target.move_to_front()

func _process(_delta):
	if _dragging:
		global_position = get_global_mouse_position() + _drag_offset

func _stop_drag():
	_dragging = false
	z_index = 0
	_try_snap_to_zone()

func _try_snap_to_zone():
	var my_rect = Rect2(global_position, size)
	for zone in get_tree().get_nodes_in_group("drop_zone"):
		var zone_rect = Rect2(zone.global_position, zone.size)
		if zone_rect.intersects(my_rect):
			zone.on_item_dropped(self)
			_place()
			return
	_set_editable(false)
	is_placed = false

func _place():
	is_placed = true
	if _label:
		_label.visible = false
	if _text_edit:
		_text_edit.visible = true
	_set_editable(true)

func _set_editable(value: bool):
	if not _text_edit:
		return
	_text_edit.editable = value
	_text_edit.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
