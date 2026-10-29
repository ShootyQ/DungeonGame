class_name CombatUnit
extends Node2D

signal died(unit: CombatUnit)
signal hp_changed(unit: CombatUnit, new_hp: int, max_hp: int)

@export var unit_name: String = "Unit"
@export var is_player: bool = false
@export var max_hp: int = 20
var current_hp: int = 20
var grid_pos: Vector2i = Vector2i.ZERO

var die: DieData
var loaded_face: Dictionary = {}

var intent_type: String = "NONE" # "NONE", "MOVE", "ATTACK"
var target_grid_pos: Vector2i = Vector2i.ZERO

var sprite: Sprite2D
var hp_bar: ProgressBar
var intent_icon: Sprite2D
var loaded_face_icon: TextureRect

func setup(p_name: String, p_is_player: bool, p_max_hp: int, p_texture: Texture2D, p_grid_pos: Vector2i, p_die: DieData) -> void:
	unit_name = p_name
	is_player = p_is_player
	max_hp = p_max_hp
	current_hp = p_max_hp
	grid_pos = p_grid_pos
	die = p_die
	
	# Sprite
	sprite = Sprite2D.new()
	sprite.texture = p_texture
	sprite.centered = true
	add_child(sprite)
	
	# Intent Badge above unit head
	intent_icon = Sprite2D.new()
	intent_icon.position = Vector2(0, -42)
	intent_icon.scale = Vector2(0.8, 0.8)
	intent_icon.visible = false
	add_child(intent_icon)
	
	# HP Bar
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.show_percentage = false
	hp_bar.size = Vector2(44, 7)
	hp_bar.position = Vector2(-22, -32)
	
	# Style the HP bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	bg_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.8, 0.3) if is_player else Color(0.9, 0.25, 0.25)
	fill_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(hp_bar)
	
	# Roll initial face
	roll_next_face()

func roll_next_face() -> Dictionary:
	if die:
		loaded_face = die.roll_random_face()
	return loaded_face

func set_intent(type: String, target_pos: Vector2i) -> void:
	intent_type = type
	target_grid_pos = target_pos
	
	if type == "MOVE":
		intent_icon.texture = load("res://assets/ui/intent_enemy_move.svg")
		intent_icon.visible = true
	elif type == "ATTACK":
		intent_icon.texture = load("res://assets/ui/intent_enemy_attack.svg")
		intent_icon.visible = true
	else:
		intent_icon.visible = false

func clear_intent() -> void:
	intent_type = "NONE"
	target_grid_pos = grid_pos
	if intent_icon:
		intent_icon.visible = false

func take_damage(dmg: int) -> void:
	current_hp = max(0, current_hp - dmg)
	hp_bar.value = current_hp
	hp_changed.emit(self, current_hp, max_hp)
	
	# Hit flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 0.4), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if current_hp <= 0:
		died.emit(self)

func animate_move_to(target_world_pos: Vector2, duration: float = 0.35) -> Tween:
	var tween = create_tween()
	# Slight hop arc
	var mid_pos = (position + target_world_pos) * 0.5 + Vector2(0, -14)
	tween.tween_property(self, "position", mid_pos, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_world_pos, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween

func animate_attack_thrust(target_world_pos: Vector2, duration: float = 0.35) -> Tween:
	var original_pos = position
	var thrust_dir = (target_world_pos - original_pos).normalized() * 24.0
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + thrust_dir, duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_pos, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func animate_bump_back(origin_world_pos: Vector2, duration: float = 0.3) -> Tween:
	var tween = create_tween()
	tween.tween_property(self, "position", origin_world_pos, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return tween
