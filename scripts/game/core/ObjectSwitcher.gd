class_name ObjectSwitcher
extends Node

enum ObjectType { MAIN, ARCHIVE, CASE, EVIDENCE } 

@export var main: Node
@export var archive: Node
@export var case: Node
@export var evidence: Node

@export var start_active: ObjectType = ObjectType.MAIN

var current_active: ObjectType

func _ready():
	current_active = start_active
	_update_visibility()

func switch_to(target: ObjectType):
	current_active = target
	_update_visibility()

func switch_next():
	var next_index = (current_active + 1) % ObjectType.size()
	switch_to(next_index)

func _update_visibility():
	var mapping = {
		ObjectType.MAIN: main,
		ObjectType.ARCHIVE: archive,
		ObjectType.CASE: case,
		ObjectType.EVIDENCE: evidence,
	}
	for type in mapping:
		var obj = mapping[type]
		if obj:
			obj.visible = (type == current_active)
			obj.set_process(type == current_active)
			obj.set_physics_process(type == current_active)
