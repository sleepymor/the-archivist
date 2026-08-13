extends Control
class_name CharacterDisplay

@export var body_rect: TextureRect
@export var hair_rect: TextureRect
@export var outfit_rect: TextureRect

@export var male_body_texture: Texture2D
@export var female_body_texture: Texture2D

@export var male_hair_textures: Array[Texture2D] = []
@export var male_outfit_textures: Array[Texture2D] = []
@export var female_hair_textures: Array[Texture2D] = []
@export var female_outfit_textures: Array[Texture2D] = []

func show_character(character_name: String) -> void:
	var gender: String = GenderDetector.guess_gender(character_name)

	if body_rect:
		body_rect.texture = female_body_texture if gender == "female" else male_body_texture

	var hair_pool: Array[Texture2D] = female_hair_textures if gender == "female" else male_hair_textures
	var outfit_pool: Array[Texture2D] = female_outfit_textures if gender == "female" else male_outfit_textures

	if hair_rect and not hair_pool.is_empty():
		hair_rect.texture = hair_pool.pick_random()

	if outfit_rect and not outfit_pool.is_empty():
		outfit_rect.texture = outfit_pool.pick_random()

func clear() -> void:
	if body_rect:
		body_rect.texture = null
	if hair_rect:
		hair_rect.texture = null
	if outfit_rect:
		outfit_rect.texture = null
