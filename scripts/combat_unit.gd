class_name CombatUnit
extends Node2D

signal died(unit: CombatUnit)
signal hp_changed(unit: CombatUnit, new_hp: int, max_hp: int)

@export var unit_name: String = "Unit"
@export var is_player: bool = false
@export var max_hp: int = 20
var current_hp: int = 20
var is_alive: bool = true
var is_active_in_combat: bool = false
var room_id: int = 0
var grid_pos: Vector2i = Vector2i.ZERO

# New Tactical Properties
var unit_type: String = "grunt" # "grunt", "charger", "shieldbearer", "pyromancer", "brawler"
var facing_dir: Vector2i = Vector2i(0, 1) # (0,1)=Down, (0,-1)=Up, (1,0)=Right, (-1,0)=Left
var is_stunned: bool = false
var has_shield: bool = false
var shield_broken: bool = false
var telegraphed_tiles: Array = []

var die: DieData
var loaded_face: Dictionary = {}

var intent_type: String = "NONE" # "NONE", "MOVE", "ATTACK", "CHARGE", "SWEEP", "BLAST", "STUNNED"
var target_grid_pos: Vector2i = Vector2i.ZERO

var sprite: Sprite2D
var hp_bar: ProgressBar
var intent_plate: PanelContainer
var intent_icon: TextureRect
var intent_label: Label
var hero_plate: PanelContainer
var hero_icon: TextureRect
var hero_label: Label
var shield_icon: Sprite2D
var stun_icon: Sprite2D

func setup(p_name: String, p_is_player: bool, p_max_hp: int, p_texture: Texture2D, p_grid_pos: Vector2i, p_die: DieData, p_type: String = "grunt") -> void:
	unit_name = p_name
	is_player = p_is_player
	max_hp = p_max_hp
	current_hp = p_max_hp
	grid_pos = p_grid_pos
	die = p_die
	unit_type = p_type
	has_shield = (p_type == "shieldbearer")
	
	# Sprite
	sprite = Sprite2D.new()
	sprite.texture = p_texture
	sprite.centered = true
	add_child(sprite)
	
	# Overhead Intent Plate (Enemies) - Compact shoulder badge off to the side
	if not is_player:
		intent_plate = PanelContainer.new()
		intent_plate.z_as_relative = false
		intent_plate.z_index = 26
		intent_plate.position = Vector2(10, -30)
		intent_plate.custom_minimum_size = Vector2(48, 20)
		intent_plate.visible = false
		add_child(intent_plate)
		
		var i_hbox = HBoxContainer.new()
		i_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		i_hbox.add_theme_constant_override("separation", 4)
		intent_plate.add_child(i_hbox)
		
		intent_icon = TextureRect.new()
		intent_icon.custom_minimum_size = Vector2(16, 16)
		intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		i_hbox.add_child(intent_icon)
		
		intent_label = Label.new()
		intent_label.text = "4 DMG"
		intent_label.add_theme_font_size_override("font_size", 11)
		i_hbox.add_child(intent_label)
	else:
		# Shoulder Die Plate (Hero) - Compact shoulder badge off to the side
		hero_plate = PanelContainer.new()
		hero_plate.z_as_relative = false
		hero_plate.z_index = 26
		hero_plate.position = Vector2(12, -30)
		hero_plate.custom_minimum_size = Vector2(48, 20)
		var hp_style = StyleBoxFlat.new()
		hp_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
		hp_style.border_color = Color(0.98, 0.82, 0.2)
		hp_style.set_border_width_all(1.5)
		hp_style.set_corner_radius_all(4)
		hp_style.content_margin_left = 4
		hp_style.content_margin_right = 4
		hp_style.content_margin_top = 1
		hp_style.content_margin_bottom = 1
		hero_plate.add_theme_stylebox_override("panel", hp_style)
		hero_plate.visible = false
		add_child(hero_plate)
		
		var h_hbox = HBoxContainer.new()
		h_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		h_hbox.add_theme_constant_override("separation", 4)
		hero_plate.add_child(h_hbox)
		
		hero_icon = TextureRect.new()
		hero_icon.custom_minimum_size = Vector2(16, 16)
		hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_hbox.add_child(hero_icon)
		
		hero_label = Label.new()
		hero_label.text = "4 DMG"
		hero_label.add_theme_font_size_override("font_size", 11)
		hero_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
		h_hbox.add_child(hero_label)
	
	# Shield indicator for Shieldbearers
	shield_icon = Sprite2D.new()
	shield_icon.texture = load("res://assets/ui/shield_badge.svg")
	shield_icon.position = Vector2(20, -22)
	shield_icon.scale = Vector2(0.75, 0.75)
	shield_icon.visible = has_shield
	add_child(shield_icon)
	
	# Stun indicator
	stun_icon = Sprite2D.new()
	stun_icon.texture = load("res://assets/ui/stun_badge.svg")
	stun_icon.position = Vector2(0, -65)
	stun_icon.scale = Vector2(0.9, 0.9)
	stun_icon.visible = false
	add_child(stun_icon)
	
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
		if is_player:
			update_hero_die_badge()
	return loaded_face

func update_hero_die_badge() -> void:
	if not is_player or not hero_plate:
		return
	if loaded_face == null or loaded_face.is_empty():
		hero_plate.visible = false
		return
		
	var dmg = loaded_face.get("damage", 0)
	var icon_path = loaded_face.get("icon", "res://assets/ui/die_face_1.svg")
	
	if ResourceLoader.exists(icon_path):
		hero_icon.texture = load(icon_path)
		
	hero_label.text = "%d DMG" % dmg
	hero_plate.visible = true
	
	# Gentle scale pop
	hero_plate.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(hero_plate, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_intent(type: String, target_pos: Vector2i, p_telegraphed: Array = [], custom_dmg: int = -1) -> void:
	intent_type = type
	target_grid_pos = target_pos
	telegraphed_tiles = p_telegraphed
	
	if not intent_plate:
		return
		
	if type == "NONE":
		intent_plate.visible = false
		return
		
	var dmg = custom_dmg
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	p_style.set_corner_radius_all(4)
	p_style.set_border_width_all(1.5)
	p_style.content_margin_left = 4
	p_style.content_margin_right = 4
	p_style.content_margin_top = 1
	p_style.content_margin_bottom = 1
	
	if type == "MOVE":
		intent_icon.texture = load("res://assets/ui/intent_enemy_move.svg")
		intent_label.text = "MOVE"
		intent_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
		p_style.border_color = Color(0.2, 0.6, 0.9)
	elif type == "ATTACK":
		if dmg < 0:
			dmg = loaded_face.get("damage", 4) if loaded_face else 4
		intent_icon.texture = load("res://assets/ui/intent_enemy_attack.svg")
		intent_label.text = "%d" % dmg
		intent_label.add_theme_color_override("font_color", Color(0.98, 0.35, 0.35))
		p_style.border_color = Color(0.9, 0.2, 0.2)
	elif type == "CHARGE":
		if dmg < 0: dmg = 8
		intent_icon.texture = load("res://assets/ui/intent_enemy_charge.svg")
		intent_label.text = "%d" % dmg
		intent_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		p_style.border_color = Color(0.95, 0.45, 0.1)
	elif type == "SWEEP":
		if dmg < 0: dmg = 6
		intent_icon.texture = load("res://assets/ui/intent_enemy_sweep.svg")
		intent_label.text = "%d" % dmg
		intent_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.65))
		p_style.border_color = Color(0.9, 0.25, 0.6)
	elif type == "BLAST":
		if dmg < 0: dmg = 7
		intent_icon.texture = load("res://assets/ui/intent_enemy_blast.svg")
		intent_label.text = "%d" % dmg
		intent_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.2))
		p_style.border_color = Color(0.95, 0.7, 0.1)
	elif type == "STUNNED":
		intent_icon.texture = load("res://assets/ui/stun_badge.svg")
		intent_label.text = "STUN"
		intent_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
		p_style.border_color = Color(0.7, 0.6, 0.2)
	else:
		intent_plate.visible = false
		return
		
	intent_plate.add_theme_stylebox_override("panel", p_style)
	intent_plate.visible = true
	
	# Scale punch animation
	intent_plate.scale = Vector2(1.15, 1.15)
	var tween = create_tween()
	tween.tween_property(intent_plate, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_stunned(val: bool) -> void:
	is_stunned = val
	stun_icon.visible = val
	if val:
		clear_intent()
		intent_type = "STUNNED"
		if intent_plate:
			intent_plate.visible = false

func clear_intent() -> void:
	intent_type = "NONE"
	target_grid_pos = grid_pos
	telegraphed_tiles.clear()
	if intent_plate:
		intent_plate.visible = false

func take_damage(dmg: int) -> void:
	if not is_alive:
		return
	current_hp = max(0, current_hp - dmg)
	hp_bar.value = current_hp
	hp_changed.emit(self, current_hp, max_hp)
	
	# Hit flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 0.4), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if current_hp <= 0:
		is_alive = false
		clear_intent()
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
