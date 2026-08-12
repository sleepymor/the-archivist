extends Control
class_name CustomerVisual

@export var body_node: TextureRect
@export var hair_node: TextureRect
@export var cloth_node: TextureRect
@export var case_pool_compiler_path: NodePath = NodePath("../../GameData/CasePoolCompiler")

const FEMALE_BODY: Texture2D = preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Body.png")
const FEMALE_HAIR: Array[Texture2D] = [
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Hair 1.png"),
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Hair 2.png"),
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Hair 3.png")
]
const FEMALE_CLOTH: Array[Texture2D] = [
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Cloth 1.png"),
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Cloth 2.png"),
	preload("res://assets/images/Character/Belanda/Fem/Fem Belanda Cloth 3.png")
]

const MALE_BODY: Texture2D = preload("res://assets/images/Character/Belanda/Male/Male belanda Body.png")
const MALE_HAIR: Array[Texture2D] = [
	preload("res://assets/images/Character/Belanda/Male/Hair 1.png"),
	preload("res://assets/images/Character/Belanda/Male/Hair 2.png"),
	preload("res://assets/images/Character/Belanda/Male/Hair 3.png")
]
const MALE_CLOTH: Array[Texture2D] = [
	preload("res://assets/images/Character/Belanda/Male/Cloth 1.png"),
	preload("res://assets/images/Character/Belanda/Male/Cloth 2.png"),
	preload("res://assets/images/Character/Belanda/Male/Cloth 3.png")
]

var _case_pool_compiler: Node = null

func _ready() -> void:
	if body_node == null or hair_node == null or cloth_node == null:
		push_warning("CustomerVisual: one or more visual TextureRect nodes are not assigned")

	_case_pool_compiler = get_node_or_null(case_pool_compiler_path)
	if _case_pool_compiler == null:
		push_warning("CustomerVisual: CasePoolCompiler not found at %s" % case_pool_compiler_path)
		return

	if _case_pool_compiler.has_signal("case_shown"):
		_case_pool_compiler.case_shown.connect(_on_case_shown)

	if typeof(_case_pool_compiler.current_case) == TYPE_DICTIONARY and not _case_pool_compiler.current_case.is_empty():
		_update_character_visual(_case_pool_compiler.current_case)

func _on_case_shown(case_data: Dictionary) -> void:
	_update_character_visual(case_data)

func _update_character_visual(case_data: Dictionary) -> void:
	var requester: Dictionary = case_data.get("requester", {})
	var gender: String = str(requester.get("gender", "")).to_lower().strip_edges()
	if gender != "female" and gender != "male":
		gender = _infer_gender_from_name(str(requester.get("character_name", "")))

	var body_tex: Texture2D = MALE_BODY
	var hair_tex: Texture2D = MALE_HAIR[randi() % MALE_HAIR.size()]
	var cloth_tex: Texture2D = MALE_CLOTH[randi() % MALE_CLOTH.size()]

	if gender == "female":
		body_tex = FEMALE_BODY
		hair_tex = FEMALE_HAIR[randi() % FEMALE_HAIR.size()]
		cloth_tex = FEMALE_CLOTH[randi() % FEMALE_CLOTH.size()]

	if body_node != null:
		body_node.texture = body_tex
	if hair_node != null:
		hair_node.texture = hair_tex
	if cloth_node != null:
		cloth_node.texture = cloth_tex

func _infer_gender_from_name(name: String) -> String:
	var lower_name = name.to_lower().strip_edges()
	if lower_name.is_empty():
		return "male"

	var female_indicators = ["a", "i", "ah", "iy", "ti", "ni"]
	for indicator in female_indicators:
		if lower_name.ends_with(indicator):
			return "female"

	return "male"
