class_name CombatArena
extends Node2D

const DungeonGenerator = preload("res://scripts/dungeon_generator.gd")

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 80
const GRID_HEIGHT: int = 60
const BOARD_OFFSET: Vector2 = Vector2(0, 0)

enum GameMode { EXPLORATION, COMBAT_COUNTDOWN, COMBAT_PULSE, GAME_OVER }
var current_mode: GameMode = GameMode.EXPLORATION

enum PulseState { PLANNING, RESOLVING }
var pulse_state: PulseState = PulseState.PLANNING

const PLANNING_TIME: float = 3.0
var pulse_timer: float = PLANNING_TIME
var show_telegraphs: bool = true

# Units
var player: CombatUnit
var all_enemies: Array[CombatUnit] = []
var active_combat_enemies: Array[CombatUnit] = []
var current_combat_room_id: int = 0

# Player planned intents in combat
var player_move_target: Vector2i = Vector2i(-1, -1)
var player_attack_target: Vector2i = Vector2i(-1, -1)

# Dungeon generation data
var dungeon_data: Dictionary = {}
var dungeon_rooms: Array[Dictionary] = []

# Grid data: 0 = floor, 1 = wall, 2 = door
var grid: Array = []
var doors: Array[Dictionary] = [] # [{pos, room_id, is_open, sprite}]
var fog_overlays: Dictionary = {} # room_id -> ColorRect
var chests: Array[Dictionary] = [] # [{pos, is_open, sprite, reward}]
var hazard_tiles: Dictionary = {} # Vector2i -> {duration: int, sprite: Sprite2D}

# Node references
var camera: Camera2D
var board_container: Node2D
var tile_sprites: Node2D
var hazard_container: Node2D
var prop_container: Node2D
var door_container: Node2D
var chest_container: Node2D
var reticle_container: Node2D
var unit_container: Node2D
var lighting_container: Node2D
var fog_container: Node2D
var effects_container: Node2D

# Atmospheric Lighting References
var torch_lights: Array[Dictionary] = [] # [{glow: Sprite2D, base_scale: Vector2, seed: float, base_alpha: float}]
var player_light: Sprite2D

# Reticle indicators & High-Visibility Overlay
var target_overlay_container: Node2D
var move_indicator: Sprite2D
var attack_indicator: Sprite2D
var attack_reticle_tween: Tween
var danger_indicators: Array[Sprite2D] = []
var combat_targeting_mode: String = "AUTO" # "AUTO" or "STRIKE"
var exploration_dust_timer: float = 0.0

# UI references (in CanvasLayer)
var canvas_layer: CanvasLayer
var hud_root: Control
var explore_banner: PanelContainer
var combat_hud: PanelContainer
var timer_bar: ProgressBar
var timer_label: Label
var phase_title: Label
var commit_button: Button
var telegraph_button: Button
var aim_mode_button: Button
var restart_button: Button

# Player Die HUD
var player_die_icon: TextureRect
var player_die_title: Label
var player_die_desc: Label
var last_action_label: Label

# Backpack & Inventory State
var backpack_weapons: Array[DieData] = []
var backpack_relics: Array[Dictionary] = [] # [{name, desc}]
var is_backpack_open: bool = false

# Audio System & Volume Settings
var music_player: AudioStreamPlayer
var music_stream: AudioStreamMP3
var dice_tumble_sounds: Array[AudioStream] = []
var sfx_dice_lock: AudioStream
var sfx_pulse_tick: AudioStream
var sfx_pulse_heartbeat: AudioStream
var sfx_sword_slash: AudioStream
var sfx_hammer_slam: AudioStream
var sfx_shield_parry: AudioStream
var sfx_crit_sting: AudioStream
var sfx_attack_whiff: AudioStream
var sfx_enemy_intent: AudioStream
var sfx_charger_rush: AudioStream
var sfx_pyro_flame: AudioStream
var sfx_door_creak: AudioStream
var sfx_torch_crackle: AudioStream
var sfx_wind_whisper: AudioStream
var sfx_chest_open: AudioStream
var sfx_loot_pickup: AudioStream
var sfx_backpack_equip: AudioStream
var ambient_wind_player: AudioStreamPlayer
var ambient_torch_player: AudioStreamPlayer
var last_pulse_tick_sec: int = -1
var music_volume: float = 0.65
var sfx_volume: float = 0.85
var ambience_volume: float = 0.40
var is_audio_settings_open: bool = false
var audio_settings_modal: PanelContainer
var music_slider: HSlider
var sfx_slider: HSlider
var ambience_slider: HSlider
var music_val_label: Label
var sfx_val_label: Label
var ambience_val_label: Label
var backpack_modal: PanelContainer
var dice_rack_container: HBoxContainer
var backpack_items_container: VBoxContainer
var relics_container: HBoxContainer
var equipped_weapon_title: Label
var equipped_weapon_stats: Label

# Enemy intel label
var enemy_intel_label: Label
var countdown_overlay: Control
var countdown_number: Label
var countdown_subtitle: Label
var log_label: RichTextLabel

# Main Menu, Fullscreen & Header UI
var main_menu_modal: Control
var is_main_menu_open: bool = true
var menu_fs_btn: Button
var exp_fs_btn: Button
var combat_fs_btn: Button
var audio_fs_btn: Button
var exp_hp_label: Label
var exp_hp_bar: ProgressBar
var exp_chambers_label: Label
var breached_rooms: Array[int] = []
var cleared_rooms: Array[int] = []

# Cached Die Textures for Animations
var cached_die_textures: Array[Texture2D] = []

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.027, 0.035, 0.055, 1.0))
	_cache_die_textures()
	_setup_audio_system()
	_setup_dungeon_layout()
	_create_scene_hierarchy()
	_build_board_visuals()
	_spawn_props_and_decorations()
	_create_doors()
	_create_fog_of_war()
	_spawn_units()
	_setup_lighting_and_sconces()
	_setup_hud()
	_setup_backpack_ui()
	_setup_audio_ui()
	_setup_main_menu_ui()
	_enter_exploration_mode()

func _cache_die_textures() -> void:
	cached_die_textures.clear()
	for i in range(1, 7):
		var p = "res://assets/ui/die_face_%d.svg" % i
		if ResourceLoader.exists(p):
			cached_die_textures.append(load(p))
	if ResourceLoader.exists("res://assets/ui/die_face_fire.svg"):
		cached_die_textures.append(load("res://assets/ui/die_face_fire.svg"))

func _setup_dungeon_layout() -> void:
	dungeon_data = DungeonGenerator.generate()
	grid = dungeon_data["grid"]
	dungeon_rooms = dungeon_data["rooms"]

func _create_scene_hierarchy() -> void:
	# Canvas Background (Abyss plane extends far out to prevent border seams)
	var bg = ColorRect.new()
	bg.position = Vector2(-4000, -4000)
	bg.size = Vector2(GRID_WIDTH * TILE_SIZE + 8000, GRID_HEIGHT * TILE_SIZE + 8000)
	bg.color = Color(0.027, 0.035, 0.055, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Smooth Scrolling Camera clamped strictly inside dungeon boundaries
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID_WIDTH * TILE_SIZE
	camera.limit_bottom = GRID_HEIGHT * TILE_SIZE
	camera.limit_smoothed = true
	add_child(camera)
	
	board_container = Node2D.new()
	board_container.position = BOARD_OFFSET
	add_child(board_container)
	
	tile_sprites = Node2D.new()
	tile_sprites.z_index = 0
	tile_sprites.modulate = Color(0.44, 0.46, 0.54) # Atmospheric shadowy dungeon ambient base
	board_container.add_child(tile_sprites)
	
	hazard_container = Node2D.new()
	hazard_container.z_index = 1
	board_container.add_child(hazard_container)
	
	prop_container = Node2D.new()
	prop_container.z_index = 2
	prop_container.modulate = Color(0.58, 0.60, 0.68)
	board_container.add_child(prop_container)
	
	door_container = Node2D.new()
	door_container.z_index = 3
	board_container.add_child(door_container)
	
	chest_container = Node2D.new()
	chest_container.z_index = 4
	board_container.add_child(chest_container)
	
	reticle_container = Node2D.new()
	reticle_container.z_index = 5
	board_container.add_child(reticle_container)
	
	unit_container = Node2D.new()
	unit_container.z_index = 6
	board_container.add_child(unit_container)
	
	lighting_container = Node2D.new()
	lighting_container.z_index = 8
	board_container.add_child(lighting_container)
	
	fog_container = Node2D.new()
	fog_container.z_index = 10
	board_container.add_child(fog_container)
	
	effects_container = Node2D.new()
	effects_container.z_index = 15
	board_container.add_child(effects_container)
	
	# Dedicated High-Visibility Overlay for Targeting Reticle (Above all units, lights, fog, badges!)
	target_overlay_container = Node2D.new()
	target_overlay_container.z_index = 32
	board_container.add_child(target_overlay_container)
	
	# Reticle Sprites
	move_indicator = Sprite2D.new()
	move_indicator.texture = load("res://assets/ui/indicator_move.svg")
	move_indicator.centered = true
	move_indicator.visible = false
	reticle_container.add_child(move_indicator)
	
	attack_indicator = Sprite2D.new()
	attack_indicator.texture = load("res://assets/ui/indicator_attack.svg")
	attack_indicator.centered = true
	attack_indicator.visible = false
	target_overlay_container.add_child(attack_indicator)

func _build_board_visuals() -> void:
	var tex_floor_clean = load("res://assets/sprites/tile_floor.svg")
	var tex_floor_cracked = load("res://assets/sprites/tile_floor_cracked.svg")
	var tex_floor_rubble = load("res://assets/sprites/tile_floor_rubble.svg")
	var tex_floor_bones = load("res://assets/sprites/tile_floor_bones.svg")
	var tex_floor_sigil = load("res://assets/sprites/tile_floor_sigil.svg")
	var tex_floor_puddle = load("res://assets/sprites/tile_floor_puddle.svg")
	var tex_floor_drain = load("res://assets/sprites/tile_floor_drain.svg")
	var tex_floor_moss = load("res://assets/sprites/tile_floor_moss.svg")
	var tex_floor_blood = load("res://assets/sprites/tile_floor_blood.svg")
	var tex_floor_ornate = load("res://assets/sprites/tile_floor_ornate.svg")
	var tex_floor_runic = load("res://assets/sprites/tile_floor_runic.svg")
	
	# Horizontal Top Walls
	var tex_wall_clean = load("res://assets/sprites/tile_wall.svg")
	var tex_wall_crumbled = load("res://assets/sprites/tile_wall_crumbled.svg")
	var tex_wall_moss = load("res://assets/sprites/tile_wall_moss.svg")
	var tex_wall_alcove = load("res://assets/sprites/tile_wall_alcove.svg")
	var tex_wall_chains = load("res://assets/sprites/tile_wall_chains.svg")

	# Vertical Side Walls
	var tex_wall_side_left = load("res://assets/sprites/tile_wall_side_left.svg")
	var tex_wall_side_left_crumbled = load("res://assets/sprites/tile_wall_side_left_crumbled.svg")
	var tex_wall_side_left_moss = load("res://assets/sprites/tile_wall_side_left_moss.svg")
	var tex_wall_side_right = load("res://assets/sprites/tile_wall_side_right.svg")
	var tex_wall_side_right_crumbled = load("res://assets/sprites/tile_wall_side_right_crumbled.svg")
	var tex_wall_side_right_moss = load("res://assets/sprites/tile_wall_side_right_moss.svg")

	# Deep interior solid bedrock
	var tex_wall_solid = load("res://assets/sprites/tile_wall_solid.svg")

	var floor_tex_map = {
		"cracked": tex_floor_cracked,
		"rubble": tex_floor_rubble,
		"bones": tex_floor_bones,
		"sigil": tex_floor_sigil,
		"puddle": tex_floor_puddle,
		"drain": tex_floor_drain,
		"moss": tex_floor_moss,
		"blood": tex_floor_blood,
		"ornate": tex_floor_ornate,
		"runic": tex_floor_runic
	}
	var wall_tex_map = {
		"alcove": tex_wall_alcove,
		"chains": tex_wall_chains
	}

	var special_floors: Dictionary = dungeon_data.get("special_floors", {})
	var special_walls: Dictionary = dungeon_data.get("special_walls", {})

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var tile_type = grid[y][x]
			var sprite = Sprite2D.new()
			var cell = Vector2i(x, y)
			
			if tile_type == 1:
				var floor_east = (x + 1 < GRID_WIDTH) and (grid[y][x + 1] == 0 or grid[y][x + 1] == 2)
				var floor_west = (x - 1 >= 0) and (grid[y][x - 1] == 0 or grid[y][x - 1] == 2)
				var floor_south = (y + 1 < GRID_HEIGHT) and (grid[y + 1][x] == 0 or grid[y + 1][x] == 2)
				var floor_north = (y - 1 >= 0) and (grid[y - 1][x] == 0 or grid[y - 1][x] == 2)

				var h = (x * 17 + y * 31) % 100

				if special_walls.has(cell) and floor_south:
					var w_key = special_walls[cell]
					sprite.texture = wall_tex_map.get(w_key, tex_wall_clean)
				elif floor_east and not floor_south and not floor_west:
					if h < 25:
						sprite.texture = tex_wall_side_left_moss
					elif h < 50:
						sprite.texture = tex_wall_side_left_crumbled
					else:
						sprite.texture = tex_wall_side_left
				elif floor_west and not floor_south and not floor_east:
					if h < 25:
						sprite.texture = tex_wall_side_right_moss
					elif h < 50:
						sprite.texture = tex_wall_side_right_crumbled
					else:
						sprite.texture = tex_wall_side_right
				elif floor_south:
					if h < 25:
						sprite.texture = tex_wall_moss
					elif h < 50:
						sprite.texture = tex_wall_crumbled
					else:
						sprite.texture = tex_wall_clean
				elif floor_north:
					if h < 30:
						sprite.texture = tex_wall_moss
					elif h < 55:
						sprite.texture = tex_wall_crumbled
					else:
						sprite.texture = tex_wall_clean
				elif floor_east:
					sprite.texture = tex_wall_side_left
				elif floor_west:
					sprite.texture = tex_wall_side_right
				else:
					sprite.texture = tex_wall_solid
			else:
				# Floor tile
				if special_floors.has(cell):
					var s_key = special_floors[cell]
					sprite.texture = floor_tex_map.get(s_key, tex_floor_clean)
				else:
					var fh = (x * 13 + y * 29) % 100
					if fh < 8:
						sprite.texture = tex_floor_cracked
					elif fh < 14:
						sprite.texture = tex_floor_rubble
					else:
						sprite.texture = tex_floor_clean
						
			sprite.position = Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			tile_sprites.add_child(sprite)

func _spawn_props_and_decorations() -> void:
	var tex_pillar = load("res://assets/sprites/prop_pillar.svg")
	var tex_crates = load("res://assets/sprites/prop_crates.svg")
	var tex_chains = load("res://assets/sprites/prop_chains.svg")
	var tex_web = load("res://assets/sprites/prop_cobweb.svg")

	var prop_tex_map = {
		"pillar": tex_pillar,
		"crates": tex_crates,
		"chains": tex_chains,
		"web": tex_web
	}

	for p in dungeon_data.get("props", []):
		var p_type = p["type"]
		if prop_tex_map.has(p_type):
			var spr = Sprite2D.new()
			spr.texture = prop_tex_map[p_type]
			spr.position = grid_to_world(p["pos"]) + p.get("offset", Vector2.ZERO)
			prop_container.add_child(spr)

func _setup_lighting_and_sconces() -> void:
	torch_lights.clear()
	var tex_sconce = load("res://assets/sprites/torch_sconce.svg")
	var tex_glow = load("res://assets/sprites/light_glow.svg")

	var sconce_positions = dungeon_data.get("torches", [])

	for pos in sconce_positions:
		var world_pos = grid_to_world(pos)
		
		# Wall Sconce Iron Bracket & Torch
		var sconce_spr = Sprite2D.new()
		sconce_spr.texture = tex_sconce
		sconce_spr.position = world_pos + Vector2(0, -18)
		lighting_container.add_child(sconce_spr)

		# Warm Radial Light Aura
		var glow = Sprite2D.new()
		glow.texture = tex_glow
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.modulate = Color(1.0, 0.70, 0.30, 0.70)
		glow.scale = Vector2(1.2, 1.2)
		glow.position = world_pos + Vector2(0, -10)
		lighting_container.add_child(glow)

		torch_lights.append({
			"glow": glow,
			"base_scale": Vector2(1.2, 1.2),
			"base_alpha": 0.70,
			"seed": randf_range(0.0, 100.0)
		})

	# Knight's Personal Travel Torch / Lantern
	player_light = Sprite2D.new()
	player_light.texture = tex_glow
	var p_mat = CanvasItemMaterial.new()
	p_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	player_light.material = p_mat
	player_light.modulate = Color(1.0, 0.82, 0.52, 0.55)
	player_light.scale = Vector2(1.05, 1.05)
	if player:
		player_light.position = player.position
	lighting_container.add_child(player_light)

func _get_door_orientation(door_pos: Vector2i, room_id: int) -> String:
	for r in dungeon_rooms:
		if r["id"] == room_id:
			var rect: Rect2i = r["rect"]
			# Vertical side walls (Left or Right wall of room: runs up-and-down!)
			if door_pos.x == rect.position.x or door_pos.x == rect.end.x - 1:
				return "vertical"
			# Horizontal top wall (North entrance: walking up into room)
			elif door_pos.y == rect.position.y:
				return "north"
			# Horizontal bottom wall (South entrance: walking down into room)
			elif door_pos.y == rect.end.y - 1:
				return "south"
				
	return "vertical"

func _create_doors() -> void:
	doors.clear()
	var door_tex_map = {
		"north": {
			"closed": load("res://assets/sprites/door_closed.svg"),
			"open": load("res://assets/sprites/door_open.svg")
		},
		"south": {
			"closed": load("res://assets/sprites/door_south_closed.svg"),
			"open": load("res://assets/sprites/door_south_open.svg")
		},
		"vertical": {
			"closed": load("res://assets/sprites/door_vertical_closed.svg"),
			"open": load("res://assets/sprites/door_vertical_open.svg")
		}
	}

	for cfg in dungeon_data.get("doors", []):
		var orient = _get_door_orientation(cfg["pos"], cfg["room_id"])
		var sprite = Sprite2D.new()
		sprite.texture = door_tex_map[orient]["closed"]
		sprite.position = grid_to_world(cfg["pos"])
		door_container.add_child(sprite)
		doors.append({
			"pos": cfg["pos"],
			"room_id": cfg["room_id"],
			"orientation": orient,
			"is_open": false,
			"sprite": sprite
		})

func _create_fog_of_war() -> void:
	fog_overlays.clear()
	for r in dungeon_rooms:
		if r["id"] == 0:
			continue # Entrance room starts revealed
		var rect: Rect2i = r["rect"]
		var fog = ColorRect.new()
		fog.position = Vector2(rect.position.x * TILE_SIZE, rect.position.y * TILE_SIZE)
		fog.size = Vector2(rect.size.x * TILE_SIZE, rect.size.y * TILE_SIZE)
		fog.color = Color(0.027, 0.035, 0.055, 0.98)
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_container.add_child(fog)
		fog_overlays[r["id"]] = fog

func _spawn_units() -> void:
	all_enemies.clear()
	active_combat_enemies.clear()
	backpack_weapons.clear()
	backpack_relics.clear()
	
	# Hero (Starts in Entrance Room)
	var spawn_pos = dungeon_data.get("player_spawn", Vector2i(6, 30))
	player = CombatUnit.new()
	unit_container.add_child(player)
	var start_sword = DieData.create_default_d6_sword()
	player.setup("Knight", true, 35, load("res://assets/sprites/hero.svg"), spawn_pos, start_sword)
	player.position = grid_to_world(player.grid_pos)
	player.died.connect(_on_player_died)
	player.hp_changed.connect(func(_u, new_hp, m_hp):
		if is_instance_valid(exp_hp_bar):
			exp_hp_bar.max_value = m_hp
			exp_hp_bar.value = new_hp
			exp_hp_label.text = "❤️ %d / %d" % [new_hp, m_hp]
	)
	
	# Initial Backpack: Starter Sword + Phalanx Warhammer
	backpack_weapons.append(start_sword.duplicate_die())
	backpack_weapons.append(DieData.create_warhammer())
	
	# Populate procedural enemies
	for e in dungeon_data.get("enemies", []):
		var en = _create_enemy(e["name"], e["hp"], e["tex"], e["pos"], e["room_id"], e.get("type", "grunt"))
		if e.has("facing"):
			en.facing_dir = e["facing"]
		all_enemies.append(en)
	
	for enemy in all_enemies:
		enemy.visible = true
		enemy.is_active_in_combat = false
	
	for enemy in all_enemies:
		enemy.visible = true
		enemy.is_active_in_combat = false

func _create_enemy(p_name: String, hp: int, tex_path: String, pos: Vector2i, p_room_id: int, p_type: String = "grunt") -> CombatUnit:
	var enemy = CombatUnit.new()
	unit_container.add_child(enemy)
	enemy.setup(p_name, false, hp, load(tex_path), pos, DieData.create_default_d6_sword(), p_type)
	enemy.position = grid_to_world(pos)
	enemy.room_id = p_room_id
	enemy.died.connect(_on_enemy_died)
	return enemy

func _setup_hud() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(hud_root)
	
	# 1. Polished Exploration Banner (Top)
	explore_banner = PanelContainer.new()
	explore_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	explore_banner.offset_left = 16
	explore_banner.offset_right = -16
	explore_banner.offset_top = 10
	explore_banner.offset_bottom = 74
	var exp_style = StyleBoxFlat.new()
	exp_style.bg_color = Color(0.08, 0.10, 0.16, 0.94)
	exp_style.border_color = Color(0.22, 0.74, 0.5)
	exp_style.set_border_width_all(2)
	exp_style.set_corner_radius_all(8)
	exp_style.content_margin_left = 14
	exp_style.content_margin_right = 14
	exp_style.content_margin_top = 6
	exp_style.content_margin_bottom = 6
	explore_banner.add_theme_stylebox_override("panel", exp_style)
	hud_root.add_child(explore_banner)
	
	var exp_hbox = HBoxContainer.new()
	exp_hbox.add_theme_constant_override("separation", 16)
	explore_banner.add_child(exp_hbox)
	
	# Left: Hero Status & Health Bar
	var hero_vbox = VBoxContainer.new()
	hero_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	exp_hbox.add_child(hero_vbox)

	var hero_title = Label.new()
	hero_title.text = "🛡️ KNIGHT HERO"
	hero_title.add_theme_font_size_override("font_size", 14)
	hero_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.98))
	hero_vbox.add_child(hero_title)

	var hp_hbox = HBoxContainer.new()
	hp_hbox.add_theme_constant_override("separation", 6)
	hero_vbox.add_child(hp_hbox)

	exp_hp_label = Label.new()
	exp_hp_label.text = "❤️ 30 / 30"
	exp_hp_label.add_theme_font_size_override("font_size", 12)
	exp_hp_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	hp_hbox.add_child(exp_hp_label)

	exp_hp_bar = ProgressBar.new()
	exp_hp_bar.min_value = 0
	exp_hp_bar.max_value = 30
	exp_hp_bar.value = 30
	exp_hp_bar.show_percentage = false
	exp_hp_bar.custom_minimum_size = Vector2(90, 8)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.8, 0.4)
	hp_fill.set_corner_radius_all(2)
	exp_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_hbox.add_child(exp_hp_bar)

	# Center: Dungeon Objective & Chambers Progress
	var obj_vbox = VBoxContainer.new()
	obj_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	exp_hbox.add_child(obj_vbox)

	var exp_title = Label.new()
	exp_title.text = "🏰 DUNGEON DEPTHS • EXPLORATION"
	exp_title.add_theme_font_size_override("font_size", 15)
	exp_title.add_theme_color_override("font_color", Color(0.3, 0.85, 0.55))
	obj_vbox.add_child(exp_title)

	var total_hostile = maxi(1, dungeon_rooms.size() - 1)
	exp_chambers_label = Label.new()
	exp_chambers_label.text = "Chambers Breached: 0 / %d  |  Move with [WASD]  |  Breach chamber doors to engage" % total_hostile
	exp_chambers_label.add_theme_font_size_override("font_size", 12)
	exp_chambers_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	obj_vbox.add_child(exp_chambers_label)

	# Right: Action Buttons
	var right_btn_hbox = HBoxContainer.new()
	right_btn_hbox.add_theme_constant_override("separation", 8)
	exp_hbox.add_child(right_btn_hbox)

	var exp_bag_btn = Button.new()
	exp_bag_btn.text = "🎒 Backpack (B)"
	exp_bag_btn.pressed.connect(_toggle_backpack)
	right_btn_hbox.add_child(exp_bag_btn)

	var exp_audio_btn = Button.new()
	exp_audio_btn.text = "🔊 Sound (V)"
	exp_audio_btn.pressed.connect(_toggle_audio_settings)
	right_btn_hbox.add_child(exp_audio_btn)

	exp_fs_btn = Button.new()
	var cur_fs = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	exp_fs_btn.text = "⛶ Windowed (F11)" if cur_fs else "⛶ Fullscreen (F11)"
	exp_fs_btn.pressed.connect(toggle_fullscreen)
	right_btn_hbox.add_child(exp_fs_btn)

	var exp_menu_btn = Button.new()
	exp_menu_btn.text = "☰ Menu (ESC)"
	exp_menu_btn.pressed.connect(func():
		is_main_menu_open = !is_main_menu_open
		if main_menu_modal:
			main_menu_modal.visible = is_main_menu_open
	)
	right_btn_hbox.add_child(exp_menu_btn)
	
	# 2. Combat HUD (Top-Wide Dock)
	combat_hud = PanelContainer.new()
	combat_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	combat_hud.offset_left = 16
	combat_hud.offset_right = -16
	combat_hud.offset_top = 10
	combat_hud.offset_bottom = 86
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.08, 0.10, 0.15, 0.96)
	c_style.border_color = Color(0.22, 0.74, 0.97)
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(8)
	c_style.content_margin_left = 14
	c_style.content_margin_right = 14
	c_style.content_margin_top = 6
	c_style.content_margin_bottom = 6
	combat_hud.add_theme_stylebox_override("panel", c_style)
	combat_hud.visible = false
	hud_root.add_child(combat_hud)
	
	var combat_hbox = HBoxContainer.new()
	combat_hbox.add_theme_constant_override("separation", 18)
	combat_hud.add_child(combat_hbox)
	
	# Player Loaded Die in Combat (Clickable to open Dice Inspector!)
	player_die_icon = TextureRect.new()
	player_die_icon.custom_minimum_size = Vector2(56, 56)
	player_die_icon.pivot_offset = Vector2(28, 28)
	player_die_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_die_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_die_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	player_die_icon.tooltip_text = "Click to inspect your Dice Rack!"
	player_die_icon.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_backpack()
	)
	combat_hbox.add_child(player_die_icon)
	
	var die_vbox = VBoxContainer.new()
	die_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_hbox.add_child(die_vbox)
	
	player_die_title = Label.new()
	player_die_title.text = "SLASH (4 DMG)"
	player_die_title.add_theme_font_size_override("font_size", 16)
	player_die_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	die_vbox.add_child(player_die_title)
	
	player_die_desc = Label.new()
	player_die_desc.text = "Pre-loaded face ready!"
	player_die_desc.add_theme_font_size_override("font_size", 12)
	player_die_desc.add_theme_color_override("font_color", Color(0.4, 0.85, 0.6))
	die_vbox.add_child(player_die_desc)
	
	# Center: Pulse Timer & Phase
	var pulse_center_vbox = VBoxContainer.new()
	pulse_center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse_center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_hbox.add_child(pulse_center_vbox)
	
	var pulse_head_hbox = HBoxContainer.new()
	pulse_center_vbox.add_child(pulse_head_hbox)
	
	phase_title = Label.new()
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_font_size_override("font_size", 16)
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	pulse_head_hbox.add_child(phase_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse_head_hbox.add_child(spacer)
	
	timer_label = Label.new()
	timer_label.text = "3.0s"
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Color(0.98, 0.75, 0.18))
	pulse_head_hbox.add_child(timer_label)
	
	timer_bar = ProgressBar.new()
	timer_bar.min_value = 0.0
	timer_bar.max_value = PLANNING_TIME
	timer_bar.value = PLANNING_TIME
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 8)
	var timer_fill = StyleBoxFlat.new()
	timer_fill.bg_color = Color(0.2, 0.8, 0.4)
	timer_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	pulse_center_vbox.add_child(timer_bar)
	
	last_action_label = Label.new()
	last_action_label.text = "🎯 Threat Intel: Inspect incoming monster intents!"
	last_action_label.add_theme_font_size_override("font_size", 12)
	last_action_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	pulse_center_vbox.add_child(last_action_label)
	
	# Right: Threat Intel & Buttons
	var action_vbox = VBoxContainer.new()
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_hbox.add_child(action_vbox)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	action_vbox.add_child(btn_hbox)
	
	commit_button = Button.new()
	commit_button.text = "⚡ COMMIT (SPACE)"
	commit_button.pressed.connect(_on_commit_pressed)
	btn_hbox.add_child(commit_button)
	
	aim_mode_button = Button.new()
	aim_mode_button.text = "🎯 Aim: AUTO (Q)"
	aim_mode_button.pressed.connect(_toggle_combat_targeting_mode)
	btn_hbox.add_child(aim_mode_button)
	
	var bag_btn = Button.new()
	bag_btn.text = "🎒 Dice / Bag (B)"
	bag_btn.pressed.connect(_toggle_backpack)
	btn_hbox.add_child(bag_btn)
	
	telegraph_button = Button.new()
	telegraph_button.text = "👁️ Telegraphs: ON"
	telegraph_button.pressed.connect(_on_toggle_telegraphs)
	btn_hbox.add_child(telegraph_button)

	combat_fs_btn = Button.new()
	combat_fs_btn.text = "⛶ Windowed (F11)" if cur_fs else "⛶ Fullscreen (F11)"
	combat_fs_btn.pressed.connect(toggle_fullscreen)
	btn_hbox.add_child(combat_fs_btn)
	
	restart_button = Button.new()
	restart_button.text = "🔄 Restart (R)"
	restart_button.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(restart_button)
	
	var c_audio_btn = Button.new()
	c_audio_btn.text = "🔊 Sound (V)"
	c_audio_btn.pressed.connect(_toggle_audio_settings)
	btn_hbox.add_child(c_audio_btn)
	
	enemy_intel_label = Label.new()
	enemy_intel_label.text = "Monsters engaged"
	enemy_intel_label.add_theme_font_size_override("font_size", 12)
	enemy_intel_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	action_vbox.add_child(enemy_intel_label)
	
	# 3. Fullscreen Dramatic 3-2-1 Countdown Overlay (Centered Perfectly)
	countdown_overlay = Control.new()
	countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.visible = false
	hud_root.add_child(countdown_overlay)
	
	var dim_bg = ColorRect.new()
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0.03, 0.04, 0.07, 0.65)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.add_child(dim_bg)

	var center_count = CenterContainer.new()
	center_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.add_child(center_count)
	
	var count_vbox = VBoxContainer.new()
	count_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	count_vbox.add_theme_constant_override("separation", 12)
	center_count.add_child(count_vbox)
	
	countdown_subtitle = Label.new()
	countdown_subtitle.text = "⚔️ ENEMY ENGAGED ⚔️"
	countdown_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_subtitle.add_theme_font_size_override("font_size", 24)
	countdown_subtitle.add_theme_color_override("font_color", Color(0.95, 0.35, 0.2))
	count_vbox.add_child(countdown_subtitle)
	
	countdown_number = Label.new()
	countdown_number.text = "3"
	countdown_number.custom_minimum_size = Vector2(400, 140)
	countdown_number.pivot_offset = Vector2(200, 70)
	countdown_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_number.add_theme_font_size_override("font_size", 100)
	countdown_number.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	count_vbox.add_child(countdown_number)
	
	# 4. Compact Bottom Combat Log
	var log_panel = PanelContainer.new()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	log_panel.offset_left = 20
	log_panel.offset_right = -20
	log_panel.offset_top = -74
	log_panel.offset_bottom = -10
	var l_style = StyleBoxFlat.new()
	l_style.bg_color = Color(0.06, 0.08, 0.11, 0.85)
	l_style.set_corner_radius_all(6)
	l_style.content_margin_left = 12
	l_style.content_margin_right = 12
	l_style.content_margin_top = 4
	l_style.content_margin_bottom = 4
	log_panel.add_theme_stylebox_override("panel", l_style)
	hud_root.add_child(log_panel)
	
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.text = "[color=#38bdf8]Dungeon loaded.[/color] [color=#94a3b8]5 chambers await. Push enemies into walls or each other to stun them![/color]\n"
	log_panel.add_child(log_label)

func _setup_backpack_ui() -> void:
	backpack_modal = PanelContainer.new()
	backpack_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	backpack_modal.custom_minimum_size = Vector2(920, 580)
	backpack_modal.offset_left = -460
	backpack_modal.offset_top = -290
	backpack_modal.offset_right = 460
	backpack_modal.offset_bottom = 290
	backpack_modal.visible = false
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	b_style.border_color = Color(0.92, 0.65, 0.15)
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(10)
	b_style.content_margin_left = 20
	b_style.content_margin_right = 20
	b_style.content_margin_top = 16
	b_style.content_margin_bottom = 16
	backpack_modal.add_theme_stylebox_override("panel", b_style)
	hud_root.add_child(backpack_modal)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	backpack_modal.add_child(main_vbox)
	
	# Header Row
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title = Label.new()
	title.text = "🎒 ADVENTURER'S BACKPACK & DICE INSPECTOR"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	header_hbox.add_child(title)
	
	var hint = Label.new()
	hint.text = "  [Press B, I or ESC to close]"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	header_hbox.add_child(hint)
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)
	
	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.pressed.connect(_toggle_backpack)
	header_hbox.add_child(close_btn)
	
	# Section 1: Active Equipped Weapon & Physical Dice Rack
	var active_sec_panel = PanelContainer.new()
	var act_style = StyleBoxFlat.new()
	act_style.bg_color = Color(0.10, 0.13, 0.19, 0.85)
	act_style.border_color = Color(0.2, 0.7, 0.95)
	act_style.set_border_width_all(1)
	act_style.set_corner_radius_all(6)
	act_style.content_margin_left = 14
	act_style.content_margin_right = 14
	act_style.content_margin_top = 10
	act_style.content_margin_bottom = 12
	active_sec_panel.add_theme_stylebox_override("panel", act_style)
	main_vbox.add_child(active_sec_panel)
	
	var act_vbox = VBoxContainer.new()
	act_vbox.add_theme_constant_override("separation", 8)
	active_sec_panel.add_child(act_vbox)
	
	var act_header_hbox = HBoxContainer.new()
	act_vbox.add_child(act_header_hbox)
	
	equipped_weapon_title = Label.new()
	equipped_weapon_title.text = "⚔️ EQUIPPED: RUSTY D6 SWORD"
	equipped_weapon_title.add_theme_font_size_override("font_size", 15)
	equipped_weapon_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.98))
	act_header_hbox.add_child(equipped_weapon_title)
	
	var eq_spacer = Control.new()
	eq_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_header_hbox.add_child(eq_spacer)
	
	equipped_weapon_stats = Label.new()
	equipped_weapon_stats.text = "Mean DMG: 4.0 | Faces: 6"
	equipped_weapon_stats.add_theme_font_size_override("font_size", 13)
	equipped_weapon_stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	act_header_hbox.add_child(equipped_weapon_stats)
	
	# The 6-Face Visual Rack
	dice_rack_container = HBoxContainer.new()
	dice_rack_container.add_theme_constant_override("separation", 8)
	act_vbox.add_child(dice_rack_container)
	
	# Section 2: Weapons in Backpack
	var bag_label = Label.new()
	bag_label.text = "📦 WEAPONS IN BACKPACK (Click to swap equipped die)"
	bag_label.add_theme_font_size_override("font_size", 13)
	bag_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	main_vbox.add_child(bag_label)
	
	var bag_scroll = ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(0, 140)
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(bag_scroll)
	
	backpack_items_container = VBoxContainer.new()
	backpack_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_items_container.add_theme_constant_override("separation", 6)
	bag_scroll.add_child(backpack_items_container)
	
	# Section 3: Relics Shelf
	var relic_header = Label.new()
	relic_header.text = "🔮 COLLECTED RUNES & RELICS"
	relic_header.add_theme_font_size_override("font_size", 13)
	relic_header.add_theme_color_override("font_color", Color(0.7, 0.5, 0.95))
	main_vbox.add_child(relic_header)
	
	relics_container = HBoxContainer.new()
	relics_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(relics_container)

func _setup_audio_system() -> void:
	dice_tumble_sounds.clear()
	for i in range(1, 4):
		var p = "res://assets/audio/dice_tumble_%d.wav" % i
		if ResourceLoader.exists(p):
			dice_tumble_sounds.append(load(p))
	if ResourceLoader.exists("res://assets/audio/dice_slam_lock.wav"):
		sfx_dice_lock = load("res://assets/audio/dice_slam_lock.wav")
	if ResourceLoader.exists("res://assets/audio/pulse_tick_urgent.wav"):
		sfx_pulse_tick = load("res://assets/audio/pulse_tick_urgent.wav")
	if ResourceLoader.exists("res://assets/audio/pulse_heartbeat_low.wav"):
		sfx_pulse_heartbeat = load("res://assets/audio/pulse_heartbeat_low.wav")
	if ResourceLoader.exists("res://assets/audio/sword_slash_flesh.wav"):
		sfx_sword_slash = load("res://assets/audio/sword_slash_flesh.wav")
	if ResourceLoader.exists("res://assets/audio/blunt_hammer_slam.wav"):
		sfx_hammer_slam = load("res://assets/audio/blunt_hammer_slam.wav")
	if ResourceLoader.exists("res://assets/audio/shield_parry_clink.wav"):
		sfx_shield_parry = load("res://assets/audio/shield_parry_clink.wav")
	if ResourceLoader.exists("res://assets/audio/critical_hit_sting.wav"):
		sfx_crit_sting = load("res://assets/audio/critical_hit_sting.wav")
	if ResourceLoader.exists("res://assets/audio/attack_whiff_whoosh.wav"):
		sfx_attack_whiff = load("res://assets/audio/attack_whiff_whoosh.wav")
	if ResourceLoader.exists("res://assets/audio/enemy_intent_cue.wav"):
		sfx_enemy_intent = load("res://assets/audio/enemy_intent_cue.wav")
	if ResourceLoader.exists("res://assets/audio/charger_rush_roar.wav"):
		sfx_charger_rush = load("res://assets/audio/charger_rush_roar.wav")
	if ResourceLoader.exists("res://assets/audio/pyro_flame_ignite.wav"):
		sfx_pyro_flame = load("res://assets/audio/pyro_flame_ignite.wav")
	if ResourceLoader.exists("res://assets/audio/heavy_door_creak.wav"):
		sfx_door_creak = load("res://assets/audio/heavy_door_creak.wav")
	if ResourceLoader.exists("res://assets/audio/torch_crackle_ambient.wav"):
		sfx_torch_crackle = load("res://assets/audio/torch_crackle_ambient.wav")
	if ResourceLoader.exists("res://assets/audio/dungeon_wind_whisper.wav"):
		sfx_wind_whisper = load("res://assets/audio/dungeon_wind_whisper.wav")
	if ResourceLoader.exists("res://assets/audio/chest_open_creak.wav"):
		sfx_chest_open = load("res://assets/audio/chest_open_creak.wav")
	if ResourceLoader.exists("res://assets/audio/loot_pickup_jingle.wav"):
		sfx_loot_pickup = load("res://assets/audio/loot_pickup_jingle.wav")
	if ResourceLoader.exists("res://assets/audio/backpack_equip_snap.wav"):
		sfx_backpack_equip = load("res://assets/audio/backpack_equip_snap.wav")
		
	# Music Player (Plays the fantasy clarinet dungeon music)
	music_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/music_dungeon_clarinet.mp3"):
		music_stream = load("res://assets/audio/music_dungeon_clarinet.mp3") as AudioStreamMP3
		if music_stream:
			music_stream.loop = true
			music_player.stream = music_stream
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	if music_stream:
		music_player.play()

	# Ambient Subterranean Wind Player (Subtle background draft - kept fairly quiet)
	ambient_wind_player = AudioStreamPlayer.new()
	if sfx_wind_whisper:
		var wind_wav = sfx_wind_whisper as AudioStreamWAV
		if wind_wav:
			wind_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient_wind_player.stream = sfx_wind_whisper
		ambient_wind_player.volume_db = linear_to_db(ambience_volume * 0.20) - 6.0
	add_child(ambient_wind_player)
	if sfx_wind_whisper:
		ambient_wind_player.play()

	# Ambient Wall Torch Crackle Player (Gentle licking flame and embers)
	ambient_torch_player = AudioStreamPlayer.new()
	if sfx_torch_crackle:
		var torch_wav = sfx_torch_crackle as AudioStreamWAV
		if torch_wav:
			torch_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient_torch_player.stream = sfx_torch_crackle
		ambient_torch_player.volume_db = linear_to_db(ambience_volume * 0.32)
	add_child(ambient_torch_player)
	if sfx_torch_crackle:
		ambient_torch_player.play()

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not stream or sfx_volume <= 0.01:
		return
	var player_sfx = AudioStreamPlayer.new()
	player_sfx.stream = stream
	player_sfx.pitch_scale = pitch_scale
	player_sfx.volume_db = linear_to_db(sfx_volume) + volume_offset_db
	add_child(player_sfx)
	player_sfx.play()
	player_sfx.finished.connect(player_sfx.queue_free)

func play_dice_tumble_sfx() -> void:
	if dice_tumble_sounds.is_empty():
		return
	var s = dice_tumble_sounds.pick_random()
	play_sfx(s, randf_range(0.96, 1.04))

func play_dice_lock_sfx() -> void:
	if sfx_dice_lock:
		play_sfx(sfx_dice_lock, randf_range(0.97, 1.03))

func play_pulse_tick_sfx() -> void:
	if sfx_pulse_tick:
		play_sfx(sfx_pulse_tick, randf_range(0.98, 1.02), -2.0)

func play_pulse_heartbeat_sfx() -> void:
	if sfx_pulse_heartbeat:
		play_sfx(sfx_pulse_heartbeat, 1.0, 2.0)

func play_sword_slash_sfx() -> void:
	if sfx_sword_slash:
		play_sfx(sfx_sword_slash, randf_range(0.95, 1.05))

func play_hammer_slam_sfx() -> void:
	if sfx_hammer_slam:
		play_sfx(sfx_hammer_slam, randf_range(0.95, 1.05))

func play_shield_parry_sfx() -> void:
	if sfx_shield_parry:
		play_sfx(sfx_shield_parry, randf_range(0.98, 1.02), 1.0)

func play_critical_hit_sfx() -> void:
	if sfx_crit_sting:
		play_sfx(sfx_crit_sting, randf_range(0.98, 1.02), 2.5)

func play_attack_whiff_sfx() -> void:
	if sfx_attack_whiff:
		play_sfx(sfx_attack_whiff, randf_range(0.96, 1.04))

func play_enemy_intent_sfx() -> void:
	if sfx_enemy_intent:
		play_sfx(sfx_enemy_intent, randf_range(0.95, 1.05))

func play_charger_rush_sfx() -> void:
	if sfx_charger_rush:
		play_sfx(sfx_charger_rush, randf_range(0.96, 1.04), 1.5)

func play_pyro_flame_sfx() -> void:
	if sfx_pyro_flame:
		play_sfx(sfx_pyro_flame, randf_range(0.96, 1.04), 1.0)

func play_door_creak_sfx() -> void:
	if sfx_door_creak:
		play_sfx(sfx_door_creak, randf_range(0.96, 1.04), 2.0)

func play_torch_crackle_sfx() -> void:
	if sfx_torch_crackle:
		play_sfx(sfx_torch_crackle, randf_range(0.95, 1.05), -4.0)

func play_wind_whisper_sfx() -> void:
	if sfx_wind_whisper:
		# Wind kept fairly quiet
		play_sfx(sfx_wind_whisper, randf_range(0.95, 1.05), -14.0)

func play_chest_open_sfx() -> void:
	if sfx_chest_open:
		play_sfx(sfx_chest_open, randf_range(0.97, 1.03), 1.5)

func play_loot_pickup_sfx() -> void:
	if sfx_loot_pickup:
		play_sfx(sfx_loot_pickup, randf_range(0.98, 1.02), 1.0)

func play_backpack_equip_sfx() -> void:
	if sfx_backpack_equip:
		play_sfx(sfx_backpack_equip, randf_range(0.96, 1.04), 1.0)

func set_music_volume(val: float) -> void:
	music_volume = clamp(val, 0.0, 1.0)
	if music_player:
		if music_volume <= 0.01:
			music_player.volume_db = -80.0
		else:
			music_player.volume_db = linear_to_db(music_volume)
	if music_slider:
		music_slider.value = music_volume
	if music_val_label:
		music_val_label.text = "%d%%" % int(music_volume * 100)

func set_sfx_volume(val: float) -> void:
	sfx_volume = clamp(val, 0.0, 1.0)
	if sfx_slider:
		sfx_slider.value = sfx_volume
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(sfx_volume * 100)

func set_ambience_volume(val: float) -> void:
	ambience_volume = clamp(val, 0.0, 1.0)
	if ambient_wind_player:
		if ambience_volume <= 0.01:
			ambient_wind_player.volume_db = -80.0
		else:
			ambient_wind_player.volume_db = linear_to_db(ambience_volume * 0.20) - 6.0
	if ambient_torch_player:
		if ambience_volume <= 0.01:
			ambient_torch_player.volume_db = -80.0
		else:
			ambient_torch_player.volume_db = linear_to_db(ambience_volume * 0.32)
	if ambience_slider:
		ambience_slider.value = ambience_volume
	if ambience_val_label:
		ambience_val_label.text = "%d%%" % int(ambience_volume * 100)

func _toggle_audio_settings() -> void:
	is_audio_settings_open = !is_audio_settings_open
	if audio_settings_modal:
		audio_settings_modal.visible = is_audio_settings_open
	if is_audio_settings_open:
		play_dice_tumble_sfx()

func _setup_audio_ui() -> void:
	audio_settings_modal = PanelContainer.new()
	audio_settings_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	audio_settings_modal.custom_minimum_size = Vector2(600, 480)
	audio_settings_modal.offset_left = -300
	audio_settings_modal.offset_top = -240
	audio_settings_modal.offset_right = 300
	audio_settings_modal.offset_bottom = 240
	audio_settings_modal.visible = false
	
	var a_style = StyleBoxFlat.new()
	a_style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	a_style.border_color = Color(0.38, 0.74, 0.97)
	a_style.set_border_width_all(2)
	a_style.set_corner_radius_all(10)
	a_style.content_margin_left = 22
	a_style.content_margin_right = 22
	a_style.content_margin_top = 18
	a_style.content_margin_bottom = 18
	audio_settings_modal.add_theme_stylebox_override("panel", a_style)
	hud_root.add_child(audio_settings_modal)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	audio_settings_modal.add_child(vbox)

	# Header Row
	var head_hbox = HBoxContainer.new()
	vbox.add_child(head_hbox)

	var title = Label.new()
	title.text = "🔊 AUDIO & VOLUME SETTINGS"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	head_hbox.add_child(title)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hbox.add_child(sp)

	audio_fs_btn = Button.new()
	var cur_fs = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	audio_fs_btn.text = "⛶ Windowed (F11)" if cur_fs else "⛶ Fullscreen (F11)"
	audio_fs_btn.pressed.connect(toggle_fullscreen)
	head_hbox.add_child(audio_fs_btn)

	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.pressed.connect(_toggle_audio_settings)
	head_hbox.add_child(close_btn)

	# Music Volume Row
	var mus_vbox = VBoxContainer.new()
	mus_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(mus_vbox)

	var mus_head = HBoxContainer.new()
	mus_vbox.add_child(mus_head)
	var mus_lbl = Label.new()
	mus_lbl.text = "🎵 Dungeon Music (Clarinet Groove)"
	mus_lbl.add_theme_font_size_override("font_size", 14)
	mus_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	mus_head.add_child(mus_lbl)

	var m_sp = Control.new()
	m_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mus_head.add_child(m_sp)

	music_val_label = Label.new()
	music_val_label.text = "%d%%" % int(music_volume * 100)
	music_val_label.add_theme_font_size_override("font_size", 14)
	music_val_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	mus_head.add_child(music_val_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.02
	music_slider.value = music_volume
	music_slider.value_changed.connect(set_music_volume)
	mus_vbox.add_child(music_slider)

	# Ambience Volume Row
	var amb_vbox = VBoxContainer.new()
	amb_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(amb_vbox)

	var amb_head = HBoxContainer.new()
	amb_vbox.add_child(amb_head)
	var amb_lbl = Label.new()
	amb_lbl.text = "🌬️ Dungeon Ambience (Quiet Wind & Torch Crackle)"
	amb_lbl.add_theme_font_size_override("font_size", 14)
	amb_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	amb_head.add_child(amb_lbl)

	var a_sp = Control.new()
	a_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amb_head.add_child(a_sp)

	ambience_val_label = Label.new()
	ambience_val_label.text = "%d%%" % int(ambience_volume * 100)
	ambience_val_label.add_theme_font_size_override("font_size", 14)
	ambience_val_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	amb_head.add_child(ambience_val_label)

	ambience_slider = HSlider.new()
	ambience_slider.min_value = 0.0
	ambience_slider.max_value = 1.0
	ambience_slider.step = 0.02
	ambience_slider.value = ambience_volume
	ambience_slider.value_changed.connect(set_ambience_volume)
	amb_vbox.add_child(ambience_slider)

	# Sound FX Volume Row
	var sfx_vbox = VBoxContainer.new()
	sfx_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(sfx_vbox)

	var sfx_head = HBoxContainer.new()
	sfx_vbox.add_child(sfx_head)
	var sfx_lbl = Label.new()
	sfx_lbl.text = "🎲 Dice Tumbler, Combat & Monster SFX"
	sfx_lbl.add_theme_font_size_override("font_size", 14)
	sfx_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	sfx_head.add_child(sfx_lbl)

	var s_sp = Control.new()
	s_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_head.add_child(s_sp)

	sfx_val_label = Label.new()
	sfx_val_label.text = "%d%%" % int(sfx_volume * 100)
	sfx_val_label.add_theme_font_size_override("font_size", 14)
	sfx_val_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	sfx_head.add_child(sfx_val_label)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.02
	sfx_slider.value = sfx_volume
	sfx_slider.value_changed.connect(set_sfx_volume)
	sfx_vbox.add_child(sfx_slider)

	# Quick Action Buttons Row 1: Dice & Pulse Timing
	var test_hbox = HBoxContainer.new()
	test_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(test_hbox)

	var test_roll_btn = Button.new()
	test_roll_btn.text = "🎲 Dice Roll"
	test_roll_btn.pressed.connect(play_dice_tumble_sfx)
	test_hbox.add_child(test_roll_btn)

	var test_lock_btn = Button.new()
	test_lock_btn.text = "⚡ Dice Slam"
	test_lock_btn.pressed.connect(play_dice_lock_sfx)
	test_hbox.add_child(test_lock_btn)

	var test_tick_btn = Button.new()
	test_tick_btn.text = "⏱️ Pulse Tick"
	test_tick_btn.pressed.connect(play_pulse_tick_sfx)
	test_hbox.add_child(test_tick_btn)

	var test_sub_btn = Button.new()
	test_sub_btn.text = "💓 Pulse Boom"
	test_sub_btn.pressed.connect(play_pulse_heartbeat_sfx)
	test_hbox.add_child(test_sub_btn)

	var test_intent_btn = Button.new()
	test_intent_btn.text = "👹 Intent Growl"
	test_intent_btn.pressed.connect(play_enemy_intent_sfx)
	test_hbox.add_child(test_intent_btn)

	# Quick Action Buttons Row 2: Combat Attacks & Impacts
	var test_hbox2 = HBoxContainer.new()
	test_hbox2.add_theme_constant_override("separation", 6)
	vbox.add_child(test_hbox2)

	var test_slash_btn = Button.new()
	test_slash_btn.text = "⚔️ Slash"
	test_slash_btn.pressed.connect(play_sword_slash_sfx)
	test_hbox2.add_child(test_slash_btn)

	var test_hammer_btn = Button.new()
	test_hammer_btn.text = "🔨 Hammer"
	test_hammer_btn.pressed.connect(play_hammer_slam_sfx)
	test_hbox2.add_child(test_hammer_btn)

	var test_parry_btn = Button.new()
	test_parry_btn.text = "🛡️ Parry"
	test_parry_btn.pressed.connect(play_shield_parry_sfx)
	test_hbox2.add_child(test_parry_btn)

	var test_crit_btn = Button.new()
	test_crit_btn.text = "💥 Crit Sting"
	test_crit_btn.pressed.connect(play_critical_hit_sfx)
	test_hbox2.add_child(test_crit_btn)

	var test_whiff_btn = Button.new()
	test_whiff_btn.text = "💨 Whiff"
	test_whiff_btn.pressed.connect(play_attack_whiff_sfx)
	test_hbox2.add_child(test_whiff_btn)

	# Quick Action Buttons Row 3: Monsters & Chamber Actions
	var test_hbox3 = HBoxContainer.new()
	test_hbox3.add_theme_constant_override("separation", 6)
	vbox.add_child(test_hbox3)

	var test_charge_btn = Button.new()
	test_charge_btn.text = "🐂 Charger"
	test_charge_btn.pressed.connect(play_charger_rush_sfx)
	test_hbox3.add_child(test_charge_btn)

	var test_flame_btn = Button.new()
	test_flame_btn.text = "🔥 Flame Blast"
	test_flame_btn.pressed.connect(play_pyro_flame_sfx)
	test_hbox3.add_child(test_flame_btn)

	var test_door_btn = Button.new()
	test_door_btn.text = "🚪 Door Creak"
	test_door_btn.pressed.connect(play_door_creak_sfx)
	test_hbox3.add_child(test_door_btn)

	var test_torch_btn = Button.new()
	test_torch_btn.text = "🪵 Torch"
	test_torch_btn.pressed.connect(play_torch_crackle_sfx)
	test_hbox3.add_child(test_torch_btn)

	var test_wind_btn = Button.new()
	test_wind_btn.text = "🌬️ Soft Wind"
	test_wind_btn.pressed.connect(play_wind_whisper_sfx)
	test_hbox3.add_child(test_wind_btn)

	# Quick Action Buttons Row 4: Loot, Inventory & Master Mute
	var test_hbox4 = HBoxContainer.new()
	test_hbox4.add_theme_constant_override("separation", 6)
	vbox.add_child(test_hbox4)

	var test_chest_btn = Button.new()
	test_chest_btn.text = "🎁 Chest"
	test_chest_btn.pressed.connect(play_chest_open_sfx)
	test_hbox4.add_child(test_chest_btn)

	var test_loot_btn = Button.new()
	test_loot_btn.text = "✨ Loot"
	test_loot_btn.pressed.connect(play_loot_pickup_sfx)
	test_hbox4.add_child(test_loot_btn)

	var test_equip_btn = Button.new()
	test_equip_btn.text = "🎒 Equip"
	test_equip_btn.pressed.connect(play_backpack_equip_sfx)
	test_hbox4.add_child(test_equip_btn)

	var mute_btn = Button.new()
	mute_btn.text = "🔇 Master Mute"
	mute_btn.pressed.connect(func():
		if music_volume > 0.0 or sfx_volume > 0.0 or ambience_volume > 0.0:
			set_music_volume(0.0)
			set_sfx_volume(0.0)
			set_ambience_volume(0.0)
		else:
			set_music_volume(0.65)
			set_sfx_volume(0.85)
			set_ambience_volume(0.40)
	)
	test_hbox4.add_child(mute_btn)

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	var is_fs = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_log("[color=#38bdf8]⛶ Display: Windowed Mode[/color]")
		_update_fullscreen_buttons(false)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_log("[color=#38bdf8]⛶ Display: Fullscreen Mode[/color]")
		_update_fullscreen_buttons(true)

func _update_fullscreen_buttons(is_fs: bool) -> void:
	var txt = "⛶ Windowed (F11)" if is_fs else "⛶ Fullscreen (F11)"
	if is_instance_valid(exp_fs_btn):
		exp_fs_btn.text = txt
	if is_instance_valid(combat_fs_btn):
		combat_fs_btn.text = txt
	if is_instance_valid(audio_fs_btn):
		audio_fs_btn.text = txt
	if is_instance_valid(menu_fs_btn):
		menu_fs_btn.text = txt

func _toggle_main_menu() -> void:
	is_main_menu_open = !is_main_menu_open
	if main_menu_modal:
		main_menu_modal.visible = is_main_menu_open
	if is_main_menu_open:
		play_dice_tumble_sfx()

func _on_enter_dungeon_pressed() -> void:
	is_main_menu_open = false
	if main_menu_modal:
		main_menu_modal.visible = false
	play_dice_tumble_sfx()
	_log("[color=#38bdf8]⚔️ Entering dungeon corridors... Explore with [WASD]![/color]")

func _setup_main_menu_ui() -> void:
	main_menu_modal = Control.new()
	main_menu_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_modal.visible = is_main_menu_open
	hud_root.add_child(main_menu_modal)
	
	# Atmospheric dark backdrop
	var dark_bg = ColorRect.new()
	dark_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0.04, 0.05, 0.08, 0.92)
	main_menu_modal.add_child(dark_bg)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 500)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	p_style.border_color = Color(0.92, 0.65, 0.15)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 28
	p_style.content_margin_right = 28
	p_style.content_margin_top = 22
	p_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	
	# Title Header
	var title = Label.new()
	title.text = "⚔️ DUNGEON DICE 🎲"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "A Tactical Pulse-Action Deck-Dice Dungeon Crawler"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	vbox.add_child(sub)
	
	# Action Buttons
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)
	
	var enter_btn = Button.new()
	enter_btn.text = "▶ ENTER DUNGEON (Space / Enter)"
	enter_btn.custom_minimum_size = Vector2(0, 44)
	enter_btn.add_theme_font_size_override("font_size", 16)
	enter_btn.pressed.connect(_on_enter_dungeon_pressed)
	btn_vbox.add_child(enter_btn)
	
	menu_fs_btn = Button.new()
	var cur_fs = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	menu_fs_btn.text = "⛶ Windowed (F11)" if cur_fs else "⛶ Fullscreen (F11)"
	menu_fs_btn.custom_minimum_size = Vector2(0, 38)
	menu_fs_btn.add_theme_font_size_override("font_size", 14)
	menu_fs_btn.pressed.connect(toggle_fullscreen)
	btn_vbox.add_child(menu_fs_btn)
	
	var audio_btn = Button.new()
	audio_btn.text = "🔊 Audio & Volume Settings (V)"
	audio_btn.custom_minimum_size = Vector2(0, 38)
	audio_btn.add_theme_font_size_override("font_size", 14)
	audio_btn.pressed.connect(_toggle_audio_settings)
	btn_vbox.add_child(audio_btn)
	
	var bag_btn = Button.new()
	bag_btn.text = "🎒 Backpack & Weapon Dice Rack (B)"
	bag_btn.custom_minimum_size = Vector2(0, 38)
	bag_btn.add_theme_font_size_override("font_size", 14)
	bag_btn.pressed.connect(_toggle_backpack)
	btn_vbox.add_child(bag_btn)
	
	# Quick Controls Guide Card
	var guide_panel = PanelContainer.new()
	var g_style = StyleBoxFlat.new()
	g_style.bg_color = Color(0.05, 0.07, 0.10, 0.8)
	g_style.border_color = Color(0.2, 0.3, 0.45)
	g_style.set_border_width_all(1)
	g_style.set_corner_radius_all(6)
	g_style.content_margin_left = 14
	g_style.content_margin_right = 14
	g_style.content_margin_top = 10
	g_style.content_margin_bottom = 10
	guide_panel.add_theme_stylebox_override("panel", g_style)
	vbox.add_child(guide_panel)
	
	var guide_vbox = VBoxContainer.new()
	guide_vbox.add_theme_constant_override("separation", 4)
	guide_panel.add_child(guide_vbox)
	
	var g_title = Label.new()
	g_title.text = "📜 ADVENTURER'S FIELD GUIDE"
	g_title.add_theme_font_size_override("font_size", 12)
	g_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	guide_vbox.add_child(g_title)
	
	var tips = [
		"• [W][A][S][D]: Move hero in exploration & choose combat move during planning.",
		"• [CLICK / Q]: Left-click enemy/path, Right-click any square to strike. [Q] toggles Strike Aim.",
		"• [SPACE]: Commit tactical combat moves & attacks before pulses resolve.",
		"• [B]: Open Backpack to inspect loaded die faces & equip newly claimed weapon dice.",
		"• [F11]: Toggle fullscreen mode at any time."
	]
	for t in tips:
		var lbl = Label.new()
		lbl.text = t
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
		guide_vbox.add_child(lbl)

func _toggle_backpack() -> void:
	is_backpack_open = !is_backpack_open
	backpack_modal.visible = is_backpack_open
	if is_backpack_open:
		play_dice_tumble_sfx()
		_render_backpack_ui()

func _render_backpack_ui() -> void:
	if not player or not player.die:
		return
		
	# Update active equipped weapon header
	equipped_weapon_title.text = "⚔️ EQUIPPED WEAPON: %s (%s DIE)" % [player.die.name.to_upper(), player.die.die_type.to_upper()]
	equipped_weapon_stats.text = "Faces: %d  |  Avg DMG: %.1f  |  Loaded Face: %s (%d DMG)" % [
		player.die.faces.size(),
		player.die.get_average_damage(),
		player.loaded_face.get("title", "NONE"),
		player.loaded_face.get("damage", 0)
	]
	
	# 1. Populate Physical Dice Rack Shelf
	for child in dice_rack_container.get_children():
		dice_rack_container.remove_child(child)
		child.queue_free()
		
	for i in range(player.die.faces.size()):
		var face = player.die.faces[i]
		var is_loaded = (face.get("title") == player.loaded_face.get("title") and face.get("damage") == player.loaded_face.get("damage") and face.get("roll") == player.loaded_face.get("roll"))
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(130, 140)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var c_style = StyleBoxFlat.new()
		c_style.set_corner_radius_all(6)
		c_style.content_margin_left = 6
		c_style.content_margin_right = 6
		c_style.content_margin_top = 6
		c_style.content_margin_bottom = 6
		
		if is_loaded:
			c_style.bg_color = Color(0.20, 0.16, 0.06, 0.95)
			c_style.border_color = Color(0.98, 0.82, 0.2)
			c_style.set_border_width_all(2)
		else:
			c_style.bg_color = Color(0.08, 0.10, 0.15, 0.85)
			c_style.border_color = Color(0.2, 0.3, 0.45)
			c_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", c_style)
		dice_rack_container.add_child(card)
		
		var cvbox = VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 3)
		card.add_child(cvbox)
		
		var roll_lbl = Label.new()
		roll_lbl.text = "FACE %d" % face.get("roll", i + 1)
		roll_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roll_lbl.add_theme_font_size_override("font_size", 11)
		roll_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2) if is_loaded else Color(0.38, 0.74, 0.97))
		cvbox.add_child(roll_lbl)
		
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(face.get("icon", "res://assets/ui/die_face_1.svg"))
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cvbox.add_child(icon_rect)
		
		var t_lbl = Label.new()
		t_lbl.text = face.get("title", "")
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 12)
		t_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		cvbox.add_child(t_lbl)
		
		var d_lbl = Label.new()
		var dmg = face.get("damage", 0)
		d_lbl.text = "%d DMG" % dmg if dmg > 0 else "0 DMG"
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.add_theme_font_size_override("font_size", 12)
		d_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4) if dmg > 0 else Color(0.6, 0.6, 0.6))
		cvbox.add_child(d_lbl)
		
		var st_lbl = Label.new()
		var desc = face.get("desc", "")
		if face.get("knockback", false):
			st_lbl.text = "💥 PUSH / SLAM"
			st_lbl.add_theme_color_override("font_color", Color(0.95, 0.7, 0.2))
		elif desc.contains("Burn") or desc.contains("Fire"):
			st_lbl.text = "🔥 BURN AREA"
			st_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.2))
		elif desc.contains("Shield"):
			st_lbl.text = "🛡️ BREAK GUARD"
			st_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.95))
		else:
			st_lbl.text = "NORMAL STRIKE"
			st_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st_lbl.add_theme_font_size_override("font_size", 9)
		cvbox.add_child(st_lbl)
		
		if is_loaded:
			var act_tag = Label.new()
			act_tag.text = "▶ ACTIVE NEXT"
			act_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			act_tag.add_theme_font_size_override("font_size", 10)
			act_tag.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
			cvbox.add_child(act_tag)
			
	# 2. Populate Backpack Weapons List
	for child in backpack_items_container.get_children():
		backpack_items_container.remove_child(child)
		child.queue_free()
		
	for w in backpack_weapons:
		var row = PanelContainer.new()
		var r_style = StyleBoxFlat.new()
		var is_current = (w.name == player.die.name)
		r_style.bg_color = Color(0.12, 0.15, 0.22, 0.8) if is_current else Color(0.08, 0.10, 0.14, 0.7)
		r_style.border_color = Color(0.3, 0.8, 0.5) if is_current else Color(0.2, 0.25, 0.35)
		r_style.set_border_width_all(1)
		r_style.set_corner_radius_all(6)
		r_style.content_margin_left = 12
		r_style.content_margin_right = 12
		r_style.content_margin_top = 6
		r_style.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", r_style)
		backpack_items_container.add_child(row)
		
		var rhbox = HBoxContainer.new()
		rhbox.add_theme_constant_override("separation", 14)
		row.add_child(rhbox)
		
		var w_icon = TextureRect.new()
		w_icon.texture = load(w.icon_path)
		w_icon.custom_minimum_size = Vector2(36, 36)
		w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rhbox.add_child(w_icon)
		
		var w_vbox = VBoxContainer.new()
		w_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rhbox.add_child(w_vbox)
		
		var w_name_lbl = Label.new()
		w_name_lbl.text = w.name
		w_name_lbl.add_theme_font_size_override("font_size", 14)
		w_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		w_vbox.add_child(w_name_lbl)
		
		var w_sub_lbl = Label.new()
		w_sub_lbl.text = "Die: %s  |  Avg DMG: %.1f  |  Faces: %d" % [w.die_type.to_upper(), w.get_average_damage(), w.faces.size()]
		w_sub_lbl.add_theme_font_size_override("font_size", 11)
		w_sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		w_vbox.add_child(w_sub_lbl)
		
		var mini_hbox = HBoxContainer.new()
		mini_hbox.add_theme_constant_override("separation", 4)
		for f in w.faces:
			var m_tex = TextureRect.new()
			m_tex.texture = load(f.get("icon", "res://assets/ui/die_face_1.svg"))
			m_tex.custom_minimum_size = Vector2(20, 20)
			m_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			m_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mini_hbox.add_child(m_tex)
		rhbox.add_child(mini_hbox)
		
		if is_current:
			var eq_tag = Label.new()
			eq_tag.text = "✓ EQUIPPED"
			eq_tag.add_theme_font_size_override("font_size", 12)
			eq_tag.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
			rhbox.add_child(eq_tag)
		else:
			var eq_btn = Button.new()
			eq_btn.text = "⚔️ Equip"
			eq_btn.pressed.connect(func(): _equip_weapon_from_backpack(w))
			rhbox.add_child(eq_btn)
			
	# 3. Populate Relics Shelf
	for child in relics_container.get_children():
		relics_container.remove_child(child)
		child.queue_free()
		
	if backpack_relics.is_empty():
		var no_r = Label.new()
		no_r.text = "No relics found yet. Slay chamber guardians and loot chests to earn runes!"
		no_r.add_theme_font_size_override("font_size", 12)
		no_r.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		relics_container.add_child(no_r)
	else:
		for r in backpack_relics:
			var r_panel = PanelContainer.new()
			var rp_style = StyleBoxFlat.new()
			rp_style.bg_color = Color(0.12, 0.10, 0.18, 0.85)
			rp_style.border_color = Color(0.7, 0.4, 0.9)
			rp_style.set_border_width_all(1)
			rp_style.set_corner_radius_all(4)
			rp_style.content_margin_left = 10
			rp_style.content_margin_right = 10
			rp_style.content_margin_top = 4
			rp_style.content_margin_bottom = 4
			r_panel.add_theme_stylebox_override("panel", rp_style)
			relics_container.add_child(r_panel)
			
			var r_vbox = VBoxContainer.new()
			r_panel.add_child(r_vbox)
			
			var rn = Label.new()
			rn.text = r["name"]
			rn.add_theme_font_size_override("font_size", 12)
			rn.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
			r_vbox.add_child(rn)
			
			var rd = Label.new()
			rd.text = r["desc"]
			rd.add_theme_font_size_override("font_size", 10)
			rd.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
			r_vbox.add_child(rd)

func _equip_weapon_from_backpack(weapon: DieData) -> void:
	player.die = weapon.duplicate_die()
	player.roll_next_face()
	play_backpack_equip_sfx()
	play_dice_lock_sfx()
	_update_hud_display()
	_render_backpack_ui()
	_animate_hud_die_tumbler()
	_animate_overhead_hero_roll()
	_log("[color=#38bdf8]⚔️ Swapped equipped weapon to [b]%s[/b]! Loaded face: %s[/color]" % [player.die.name, player.loaded_face.get("title", "")])
	_show_floating_text(player.position, "EQUIPPED: %s" % player.die.name, Color(0.3, 0.8, 0.95))

func _add_weapon_to_backpack(weapon: DieData) -> void:
	for w in backpack_weapons:
		if w.name == weapon.name:
			return
	backpack_weapons.append(weapon.duplicate_die())
	if is_backpack_open:
		_render_backpack_ui()

func _sync_equipped_weapon_to_backpack() -> void:
	for i in range(backpack_weapons.size()):
		if backpack_weapons[i].name == player.die.name:
			backpack_weapons[i] = player.die.duplicate_die()
			return
	backpack_weapons.append(player.die.duplicate_die())

func _add_relic(r_name: String, r_desc: String) -> void:
	for r in backpack_relics:
		if r["name"] == r_name:
			return
	backpack_relics.append({
		"name": r_name,
		"desc": r_desc
	})
	if is_backpack_open:
		_render_backpack_ui()

func _process(delta: float) -> void:
	# Smooth Camera Follow
	if player and is_instance_valid(player):
		var target_pos = player.position + BOARD_OFFSET
		camera.position = camera.position.lerp(target_pos, delta * 6.0)
		if player_light and is_instance_valid(player_light):
			player_light.position = player.position
		
	# Dynamic gentle torch flickering
	_process_torch_flicker(delta)
		
	if current_mode == GameMode.EXPLORATION:
		_process_exploration_movement(delta)
	elif current_mode == GameMode.COMBAT_PULSE:
		_process_combat_pulse(delta)

func _process_torch_flicker(_delta: float) -> void:
	var time_ms = Time.get_ticks_msec()
	for t in torch_lights:
		var glow = t["glow"]
		if not is_instance_valid(glow):
			continue
		var s = t["seed"]
		var flicker_scale = 1.0 + sin(time_ms * 0.005 + s) * 0.03 + sin(time_ms * 0.012 + s * 1.8) * 0.015
		glow.scale = t["base_scale"] * flicker_scale
		var flicker_alpha = t["base_alpha"] * (1.0 + sin(time_ms * 0.007 + s * 1.4) * 0.06 + (randf() - 0.5) * 0.02)
		glow.modulate.a = clamp(flicker_alpha, 0.25, 0.65)

func _process_exploration_movement(delta: float) -> void:
	if is_backpack_open or is_audio_settings_open or is_main_menu_open:
		if is_instance_valid(player):
			player.is_moving = false
		return
		
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0
		
	if move_vec != Vector2.ZERO:
		move_vec = move_vec.normalized()
		player.is_moving = true
		if move_vec.x < -0.1 and player.sprite:
			player.sprite.flip_h = true
		elif move_vec.x > 0.1 and player.sprite:
			player.sprite.flip_h = false
			
		exploration_dust_timer -= delta
		if exploration_dust_timer <= 0.0:
			exploration_dust_timer = 0.22
			_spawn_dust_puff(player.position + Vector2(0, 16))
			
		var speed = 200.0
		var desired_pos = player.position + move_vec * speed * delta
		
		var p_grid = world_to_grid(desired_pos)
		if is_valid_grid_pos(p_grid):
			var tile = grid[p_grid.y][p_grid.x]
			if tile == 2:
				_check_door_interaction(p_grid)
			elif tile == 0:
				player.position = desired_pos
				player.grid_pos = p_grid
			else:
				# Simple sliding along walls
				var slide_x = Vector2(desired_pos.x, player.position.y)
				var grid_x = world_to_grid(slide_x)
				if is_valid_grid_pos(grid_x) and grid[grid_x.y][grid_x.x] == 0:
					player.position = slide_x
					player.grid_pos = grid_x
				else:
					var slide_y = Vector2(player.position.x, desired_pos.y)
					var grid_y = world_to_grid(slide_y)
					if is_valid_grid_pos(grid_y) and grid[grid_y.y][grid_y.x] == 0:
						player.position = slide_y
						player.grid_pos = grid_y
	else:
		player.is_moving = false
						
	# Check proximity to closed doors
	for door in doors:
		if not door["is_open"]:
			var d_world = grid_to_world(door["pos"])
			if player.position.distance_to(d_world) < 48.0:
				_open_door(door)
				
	# Check proximity to chests
	for chest in chests:
		if not chest["is_open"]:
			var c_world = grid_to_world(chest["pos"])
			if player.position.distance_to(c_world) < 48.0:
				_open_chest(chest)

func _check_door_interaction(door_grid_pos: Vector2i) -> void:
	for door in doors:
		if door["pos"] == door_grid_pos and not door["is_open"]:
			_open_door(door)
			break

func _get_room_breach_entrance_tile(r_id: int, door_pos: Vector2i) -> Vector2i:
	for r in dungeon_rooms:
		if r["id"] == r_id:
			var rect: Rect2i = r["rect"]
			# Look for an adjacent floor tile inside this room's rectangular bounds
			var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
			for d in dirs:
				var candidate = door_pos + d
				if rect.has_point(candidate) and grid[candidate.y][candidate.x] == 0:
					return candidate
			return r["center"]
	return door_pos

func _open_door(door: Dictionary) -> void:
	play_door_creak_sfx()
	var r_id = door["room_id"]
	current_combat_room_id = r_id
	var total_hostile = maxi(1, dungeon_rooms.size() - 1)
	if not breached_rooms.has(r_id):
		breached_rooms.append(r_id)
		if is_instance_valid(exp_chambers_label):
			exp_chambers_label.text = "Chambers Breached: %d / %d  |  Move with [WASD]" % [breached_rooms.size(), total_hostile]
	
	var door_open_tex_map = {
		"north": load("res://assets/sprites/door_open.svg"),
		"south": load("res://assets/sprites/door_south_open.svg"),
		"vertical": load("res://assets/sprites/door_vertical_open.svg")
	}

	# Open all door tiles associated with this room (supports double doors)
	for d in doors:
		if d["room_id"] == r_id and not d["is_open"]:
			d["is_open"] = true
			var orient = d.get("orientation", "north")
			d["sprite"].texture = door_open_tex_map.get(orient, door_open_tex_map["north"])
			grid[d["pos"].y][d["pos"].x] = 0
			_spawn_dust_puff(d["sprite"].position)
			var d_tween = create_tween()
			d_tween.tween_property(d["sprite"], "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			d_tween.tween_property(d["sprite"], "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	_log("[color=#f59e0b]🚪 Chamber %d breached! Fog fades away![/color]" % r_id)
	
	# Hero strides cleanly inside the room past the doorway chokepoint
	var breach_tile = _get_room_breach_entrance_tile(r_id, door["pos"])
	player.grid_pos = breach_tile
	var stride_tween = create_tween()
	stride_tween.tween_property(player, "position", grid_to_world(breach_tile), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade Fog of War
	if fog_overlays.has(r_id):
		var fog = fog_overlays[r_id]
		var tween = create_tween()
		tween.tween_property(fog, "modulate:a", 0.0, 0.4)
		tween.tween_callback(fog.queue_free)
		fog_overlays.erase(r_id)
		
	# Find and activate living monsters in this room
	var engaged_monsters: Array[CombatUnit] = []
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0 and enemy.room_id == r_id:
			enemy.is_active_in_combat = true
			engaged_monsters.append(enemy)
			_show_floating_text(enemy.position, "!", Color(0.95, 0.2, 0.2))
			
	if not engaged_monsters.is_empty():
		_start_combat_countdown(engaged_monsters)

func _open_chest(chest: Dictionary) -> void:
	play_chest_open_sfx()
	play_loot_pickup_sfx()
	chest["is_open"] = true
	chest["sprite"].texture = load("res://assets/sprites/chest_open.svg")
	var c_spr = chest["sprite"]
	var c_tween = create_tween()
	c_tween.tween_property(c_spr, "scale", Vector2(1.3, 0.7), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c_tween.tween_property(c_spr, "scale", Vector2(0.85, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c_tween.tween_property(c_spr, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_spawn_chest_loot_burst(grid_to_world(chest["pos"]))
	_show_floating_text(grid_to_world(chest["pos"]), "LOOT UNLOCKED!", Color(0.98, 0.85, 0.2))
	
	var reward_type = chest.get("reward", "flame_rune")
	if reward_type == "flame_rune":
		# Add Pyromancer's Wand to backpack
		var wand = DieData.create_pyromancer_wand()
		_add_weapon_to_backpack(wand)
		if player and player.die and player.die.faces.size() >= 4:
			var fire_face = {
				"roll": 4,
				"title": "FLAME RUNE",
				"desc": "8 Damage + Burn Hazard!",
				"damage": 8,
				"knockback": false,
				"icon": "res://assets/ui/die_face_fire.svg"
			}
			player.die.faces[3] = fire_face
			player.loaded_face = fire_face
		_sync_equipped_weapon_to_backpack()
		_add_relic("Flame Rune", "🔥 Upgrades Face 4 to 8 DMG with Fire Hazards + unlocks Pyromancer's Flame Wand!")
		_update_hud_display()
		_log("[color=#f97316][b]🔥 TREASURE: Flame Rune etched + Pyromancer's Flame Wand added to Backpack![/b][/color]")
	elif reward_type == "shield_basher":
		var warhammer = DieData.create_warhammer()
		_add_weapon_to_backpack(warhammer)
		if player and player.die and player.die.faces.size() >= 2:
			var bash_face = {
				"roll": 2,
				"title": "SHIELD BASHER",
				"desc": "5 Damage + Breaks Guard!",
				"damage": 5,
				"knockback": true,
				"icon": "res://assets/ui/die_face_5.svg"
			}
			player.die.faces[1] = bash_face
			player.loaded_face = bash_face
		_sync_equipped_weapon_to_backpack()
		_add_relic("Shield Basher", "🛡️ Upgrades Face 2 to 5 DMG with Shield-Breaking capability.")
		_update_hud_display()
		_log("[color=#38bdf8][b]🛡️ TREASURE: Shield Basher etched + Phalanx Warhammer added to Backpack![/b][/color]")
	elif reward_type == "chaos_blast":
		if player and player.die and player.die.faces.size() >= 3:
			var chaos_face = {
				"roll": 3,
				"title": "CHAOS SHOCKWAVE",
				"desc": "7 Damage + Heavy Push!",
				"damage": 7,
				"knockback": true,
				"icon": "res://assets/ui/die_face_6.svg"
			}
			player.die.faces[2] = chaos_face
			player.loaded_face = chaos_face
		_sync_equipped_weapon_to_backpack()
		_add_relic("Chaos Shockwave", "🔮 Upgrades Face 3 to 7 DMG with a directional shockwave.")
		_update_hud_display()
		_log("[color=#a855f7][b]🔮 TREASURE: Chaos Shockwave etched into your weapon die![/b][/color]")
	elif reward_type == "executioner_edge":
		var axe = DieData.create_executioner_axe()
		_add_weapon_to_backpack(axe)
		if player and player.die and not player.die.faces.is_empty():
			var exec_face = {
				"roll": 1,
				"title": "EXECUTIONER",
				"desc": "10 Damage + Wall Slam!",
				"damage": 10,
				"knockback": true,
				"icon": "res://assets/ui/die_face_6.svg"
			}
			player.die.faces[0] = exec_face
			player.loaded_face = exec_face
		_sync_equipped_weapon_to_backpack()
		_add_relic("Executioner's Edge", "⚡ Replaces Face 1 MISS with a 10 DMG Wall Slam + unlocks Executioner's Greataxe!")
		_update_hud_display()
		_log("[color=#eab308][b]⚡ TREASURE: Executioner's Edge + Greataxe added to Backpack![/b][/color]")
	elif reward_type == "dungeon_crown":
		_add_relic("Crown of the Dungeon Master", "👑 Legendary victory relic! All chambers purged.")
		_log("[color=#22c55e][b]👑 RELIC OF VICTORY: You claimed the Dungeon Crown! All chambers conquered![/b][/color]")

func _start_combat_countdown(engaged_monsters: Array[CombatUnit]) -> void:
	current_mode = GameMode.COMBAT_COUNTDOWN
	active_combat_enemies = engaged_monsters
	
	# Smoothly snap player to breach entrance grid tile inside the chamber
	var snap_target = grid_to_world(player.grid_pos)
	var snap_tween = create_tween()
	snap_tween.tween_property(player, "position", snap_target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	explore_banner.visible = false
	countdown_overlay.visible = true
	
	_log("[color=#ef4444][b]⚔️ TACTICAL PULSE ENGAGING IN 3... 2... 1...[/b][/color]")
	
	var count_seq = create_tween()
	count_seq.tween_callback(func():
		countdown_number.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
		countdown_number.text = "3"
		countdown_number.scale = Vector2(1.5, 1.5)
		play_pulse_tick_sfx()
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "2"
		countdown_number.scale = Vector2(1.5, 1.5)
		play_pulse_tick_sfx()
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "1"
		countdown_number.scale = Vector2(1.5, 1.5)
		play_pulse_tick_sfx()
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "BATTLE!"
		countdown_number.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		countdown_number.scale = Vector2(1.5, 1.5)
		play_dice_lock_sfx()
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.4)
	
	count_seq.tween_callback(func():
		countdown_overlay.visible = false
		_start_combat_pulse_mode()
	)

func _start_combat_pulse_mode() -> void:
	current_mode = GameMode.COMBAT_PULSE
	combat_hud.visible = true
	_start_planning_phase()

func _enter_exploration_mode() -> void:
	current_mode = GameMode.EXPLORATION
	pulse_state = PulseState.PLANNING
	active_combat_enemies.clear()
	player_move_target = Vector2i(-1, -1)
	player_attack_target = Vector2i(-1, -1)
	
	explore_banner.visible = true
	combat_hud.visible = false
	countdown_overlay.visible = false
	
	move_indicator.visible = false
	attack_indicator.visible = false
	for danger in danger_indicators:
		if is_instance_valid(danger):
			danger.queue_free()
	danger_indicators.clear()

func _process_combat_pulse(delta: float) -> void:
	if pulse_state == PulseState.PLANNING:
		pulse_timer -= delta
		timer_bar.value = max(0.0, pulse_timer)
		timer_label.text = "%.1fs" % max(0.0, pulse_timer)
		
		var ratio = pulse_timer / PLANNING_TIME
		var fill_style = timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if ratio > 0.5:
				fill_style.bg_color = Color(0.2, 0.8, 0.4)
			elif ratio > 0.25:
				fill_style.bg_color = Color(0.95, 0.75, 0.2)
			else:
				fill_style.bg_color = Color(0.95, 0.25, 0.25)
				
		if pulse_timer <= 0.0:
			_resolve_pulse()
		else:
			# Urgent clock ticking when planning timer is running low (<= 2s)
			var current_sec = int(ceil(pulse_timer))
			if current_sec <= 2 and current_sec > 0 and current_sec != last_pulse_tick_sec:
				last_pulse_tick_sec = current_sec
				play_pulse_tick_sfx()
				if phase_title:
					var p_tween = create_tween()
					p_tween.tween_property(phase_title, "scale", Vector2(1.1, 1.1), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					p_tween.tween_property(phase_title, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			return

	if is_main_menu_open:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
				_on_enter_dungeon_pressed()
				return
			elif event.keycode == KEY_W or event.keycode == KEY_A or event.keycode == KEY_S or event.keycode == KEY_D:
				_on_enter_dungeon_pressed()
				return
			elif event.keycode == KEY_B or event.keycode == KEY_I:
				_toggle_backpack()
				return
			elif event.keycode == KEY_V:
				_toggle_audio_settings()
				return
		return

	if current_mode == GameMode.GAME_OVER:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_on_restart_pressed()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_on_restart_pressed()
		elif event.keycode == KEY_B or event.keycode == KEY_I:
			_toggle_backpack()
			return
		elif event.keycode == KEY_V:
			_toggle_audio_settings()
			return
		elif event.keycode == KEY_M:
			if music_volume > 0.0:
				set_music_volume(0.0)
				_log("[color=#94a3b8]🎵 Music muted (Press M to unmute)[/color]")
			else:
				set_music_volume(0.65)
				_log("[color=#38bdf8]🎵 Music unmuted (65%)[/color]")
			return
		elif event.keycode == KEY_ESCAPE:
			if is_audio_settings_open:
				_toggle_audio_settings()
				return
			elif is_backpack_open:
				_toggle_backpack()
				return
			elif current_mode == GameMode.EXPLORATION:
				_toggle_main_menu()
				return
		elif current_mode == GameMode.COMBAT_PULSE and pulse_state == PulseState.PLANNING:
			if event.keycode == KEY_SPACE:
				_on_commit_pressed()
			elif event.keycode == KEY_T:
				_on_toggle_telegraphs()
			elif event.keycode == KEY_Q or event.keycode == KEY_TAB:
				_toggle_combat_targeting_mode()
			elif event.keycode == KEY_W or event.keycode == KEY_UP:
				_select_combat_move_dir(Vector2i(0, -1))
			elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
				_select_combat_move_dir(Vector2i(0, 1))
			elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
				_select_combat_move_dir(Vector2i(-1, 0))
			elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
				_select_combat_move_dir(Vector2i(1, 0))
				
	# If backpack, audio modal or main menu is open, don't register clicks on the floor
	if is_backpack_open or is_audio_settings_open or is_main_menu_open:
		return
				
	# Board clicks in combat planning mode (board_container handles camera offset automatically!)
	if current_mode == GameMode.COMBAT_PULSE and pulse_state == PulseState.PLANNING and event is InputEventMouseButton and event.pressed:
		var local_mouse = board_container.get_local_mouse_position()
		if local_mouse.x >= 0 and local_mouse.x < GRID_WIDTH * TILE_SIZE and local_mouse.y >= 0 and local_mouse.y < GRID_HEIGHT * TILE_SIZE:
			var clicked_grid = world_to_grid(local_mouse)
			if is_valid_grid_pos(clicked_grid):
				if event.button_index == MOUSE_BUTTON_LEFT:
					_handle_combat_left_click(clicked_grid)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_handle_combat_right_click(clicked_grid)

func _toggle_combat_targeting_mode() -> void:
	if combat_targeting_mode == "AUTO":
		combat_targeting_mode = "STRIKE"
		if is_instance_valid(aim_mode_button):
			aim_mode_button.text = "🎯 Aim: STRIKE (Q)"
		_log("[color=#f59e0b]🎯 Strike Aim Mode LOCKED. Left-click any square to target strike.[/color]")
	else:
		combat_targeting_mode = "AUTO"
		if is_instance_valid(aim_mode_button):
			aim_mode_button.text = "🎯 Aim: AUTO (Q)"
		_log("[color=#38bdf8]🎯 Aim Mode AUTO. Click enemy/path to strike, floor to move.[/color]")
	_update_combat_plan_hud()

func _select_combat_move_dir(dir: Vector2i) -> void:
	var target = player.grid_pos + dir
	if not is_valid_grid_pos(target) or grid[target.y][target.x] != 0:
		_log("[color=#ef4444]Cannot move into wall![/color]")
		return
	if player_move_target == target:
		player_move_target = Vector2i(-1, -1)
		move_indicator.visible = false
		_log("[color=#94a3b8]Holding position.[/color]")
	else:
		player_move_target = target
		move_indicator.position = grid_to_world(target)
		move_indicator.visible = true
		_log("[color=#38bdf8]Move target → (%d, %d)[/color]" % [target.x, target.y])
	_update_combat_plan_hud()

func _update_combat_plan_hud() -> void:
	if not is_instance_valid(last_action_label):
		return
	var move_str = "(%d, %d)" % [player_move_target.x, player_move_target.y] if player_move_target != Vector2i(-1, -1) else "Hold [WASD]"
	var strike_str = "(%d, %d)" % [player_attack_target.x, player_attack_target.y] if player_attack_target != Vector2i(-1, -1) else "None [R-Click/Aim]"
	last_action_label.text = "🦶 Move: %s   •   ⚔️ Strike: %s   [Q: Aim Mode]" % [move_str, strike_str]

func _handle_combat_left_click(pos: Vector2i) -> void:
	# 1. Direct Click on Living Enemy -> Target Strike
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == pos:
			_toggle_attack_target(pos, enemy.unit_name)
			return

	# 2. Click on Projected Destination of a Moving/Charging Enemy -> Intercept Strike!
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.intent_type in ["MOVE", "CHARGE"]:
			if enemy.target_grid_pos == pos or (enemy.intent_type == "CHARGE" and enemy.telegraphed_tiles.has(pos)):
				_toggle_attack_target(pos, "intercept strike on %s" % enemy.unit_name)
				return

	# 3. Click on Player -> Clear Move (Hold Position)
	if pos == player.grid_pos:
		player_move_target = Vector2i(-1, -1)
		move_indicator.visible = false
		_log("[color=#94a3b8]Holding position.[/color]")
		_update_combat_plan_hud()
		return

	# 4. If Shift key is held OR Strike Aim Mode is active -> Strike target on ANY tile!
	if Input.is_key_pressed(KEY_SHIFT) or combat_targeting_mode == "STRIKE":
		_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])
		return

	# 5. Empty Floor Tile
	if grid[pos.y][pos.x] == 0:
		var diff = (pos - player.grid_pos).abs()
		var is_adjacent = (diff.x <= 1 and diff.y <= 1)
		if is_adjacent:
			if player_move_target == pos:
				# Already set as move destination -> promote/toggle attack strike!
				_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])
			elif player_move_target != Vector2i(-1, -1):
				# Move already selected elsewhere -> this click is for attack strike!
				_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])
			else:
				# First click sets move target
				player_move_target = pos
				move_indicator.position = grid_to_world(pos)
				move_indicator.visible = true
				_log("[color=#38bdf8]Move target → (%d, %d)[/color]" % [pos.x, pos.y])
		else:
			# Non-adjacent tile -> aim prediction strike
			_toggle_attack_target(pos, "prediction tile (%d, %d)" % [pos.x, pos.y])
			
	_update_combat_plan_hud()

func _handle_combat_right_click(pos: Vector2i) -> void:
	# Right-click ALWAYS sets or toggles attack strike target on ANY tile!
	_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])

func _toggle_attack_target(pos: Vector2i, label: String) -> void:
	if player_attack_target == pos:
		player_attack_target = Vector2i(-1, -1)
		attack_indicator.visible = false
		if attack_reticle_tween and attack_reticle_tween.is_valid():
			attack_reticle_tween.kill()
		_log("[color=#94a3b8]Cancelled strike on %s[/color]" % label)
	else:
		player_attack_target = pos
		attack_indicator.position = grid_to_world(pos)
		attack_indicator.visible = true
		attack_indicator.scale = Vector2(1.35, 1.35)
		
		# Breathing looping reticle tween so target is unmissable
		if attack_reticle_tween and attack_reticle_tween.is_valid():
			attack_reticle_tween.kill()
		attack_reticle_tween = create_tween().set_loops()
		attack_reticle_tween.tween_property(attack_indicator, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		attack_reticle_tween.tween_property(attack_indicator, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		play_dice_lock_sfx()
		_log("[color=#ef4444]🎯 Locked strike on %s → (%d, %d)[/color]" % [label, pos.x, pos.y])

	# Update targeted visual glow on enemies
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy):
			var is_tgt = (enemy.grid_pos == player_attack_target or (enemy.intent_type in ["MOVE", "CHARGE"] and enemy.target_grid_pos == player_attack_target))
			if enemy.has_method("set_targeted"):
				enemy.set_targeted(is_tgt)
				
	_update_combat_plan_hud()

func _start_planning_phase() -> void:
	# Clear any lingering attack impacts or popups immediately so the field is completely unobstructed!
	if effects_container:
		for child in effects_container.get_children():
			effects_container.remove_child(child)
			child.queue_free()

	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
		return
		
	pulse_state = PulseState.PLANNING
	pulse_timer = PLANNING_TIME
	last_pulse_tick_sec = -1
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	commit_button.disabled = false
	
	player_move_target = Vector2i(-1, -1)
	player_attack_target = Vector2i(-1, -1)
	move_indicator.visible = false
	attack_indicator.visible = false
	if attack_reticle_tween and attack_reticle_tween.is_valid():
		attack_reticle_tween.kill()
	attack_indicator.scale = Vector2.ONE
	
	for ind in danger_indicators:
		if is_instance_valid(ind):
			ind.queue_free()
	danger_indicators.clear()
	
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_targeted"):
			enemy.set_targeted(false)
	
	# Trigger Pre-Pulse Dice Roll Tumble & Reveal
	_trigger_pulse_roll()
	
	_plan_enemy_intents()
	_update_hud_display()
	_update_combat_plan_hud()

func has_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if from_pos == to_pos:
		return true
		
	var p0 = Vector2(from_pos.x + 0.5, from_pos.y + 0.5)
	var p1 = Vector2(to_pos.x + 0.5, to_pos.y + 0.5)
	var diff = p1 - p0
	var dist = diff.length()
	var step_count = int(ceil(dist * 4.0)) # 4 samples per tile
	
	for s in range(1, step_count):
		var pt = p0 + diff * (float(s) / float(step_count))
		var g_tile = Vector2i(int(floor(pt.x)), int(floor(pt.y)))
		if g_tile == from_pos or g_tile == to_pos:
			continue
		if not is_valid_grid_pos(g_tile):
			return false
		# Any wall or closed door blocks line of sight
		if grid[g_tile.y][g_tile.x] != 0:
			return false
			
	return true

func _find_strafe_step(enemy: CombatUnit, prefer_retreat: bool = false) -> Vector2i:
	var blocked: Dictionary = {}
	for other in active_combat_enemies:
		if is_instance_valid(other) and other != enemy and other.is_alive and other.current_hp > 0:
			blocked[other.grid_pos] = true
			if other.intent_type == "MOVE":
				blocked[other.target_grid_pos] = true
			elif other.intent_type == "CHARGE":
				for ct in other.telegraphed_tiles:
					blocked[ct] = true

	var candidates: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	var cur_dist_sq = (enemy.grid_pos - player.grid_pos).length_squared()

	for d in directions:
		var n = enemy.grid_pos + d
		if not is_valid_grid_pos(n) or grid[n.y][n.x] != 0:
			continue
		if n == player.grid_pos or blocked.has(n):
			continue
		
		if prefer_retreat:
			# Want to increase distance from player and preserve line of sight
			var n_dist_sq = (n - player.grid_pos).length_squared()
			if n_dist_sq > cur_dist_sq and has_line_of_sight(n, player.grid_pos):
				candidates.append(n)
		else:
			# Lateral / flanking strafe: stays adjacent to player (diff <= 1) but moves away from current tile!
			var p_diff = (n - player.grid_pos).abs()
			if max(p_diff.x, p_diff.y) == 1:
				candidates.append(n)

	if candidates.is_empty():
		return enemy.grid_pos

	candidates.shuffle()
	return candidates[0]

func _plan_enemy_intents() -> void:
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
			
		# Reset shield broken state per round
		enemy.shield_broken = false
		
		# If enemy was stunned from a wall-crash or push, they skip intent!
		if enemy.is_stunned:
			enemy.set_stunned(false) # Will recover after this turn
			enemy.set_intent("STUNNED", enemy.grid_pos)
			_show_floating_text(enemy.position, "DIZZY!", Color(0.95, 0.85, 0.2))
			continue
			
		var diff = player.grid_pos - enemy.grid_pos
		var abs_diff = diff.abs()
		var dist_chebyshev = max(abs_diff.x, abs_diff.y)
		var has_los = has_line_of_sight(enemy.grid_pos, player.grid_pos)
		
		# 1. GOBLIN CHARGER: Straight line 3-tile rush (Requires direct line of sight without walls!)
		if enemy.unit_type == "charger":
			var can_charge = false
			var charge_dir = Vector2i.ZERO
			if abs_diff.y <= 1 and abs_diff.x >= 2 and abs_diff.x <= 4:
				charge_dir = Vector2i(1 if diff.x > 0 else -1, 0)
				can_charge = true
			elif abs_diff.x <= 1 and abs_diff.y >= 2 and abs_diff.y <= 4:
				charge_dir = Vector2i(0, 1 if diff.y > 0 else -1)
				can_charge = true
				
			if can_charge and has_los:
				var charge_tiles: Array[Vector2i] = []
				for step in range(1, 4):
					var c_tile = enemy.grid_pos + charge_dir * step
					if is_valid_grid_pos(c_tile) and grid[c_tile.y][c_tile.x] == 0:
						charge_tiles.append(c_tile)
						if show_telegraphs:
							_spawn_danger_indicator(c_tile)
				enemy.facing_dir = charge_dir
				enemy.set_intent("CHARGE", enemy.grid_pos + charge_dir * 3, charge_tiles)
				continue
			elif dist_chebyshev <= 1:
				# Adjacent! Cannot charge. Reposition or strafe back to line up a charge corridor!
				var retreat_step = _find_strafe_step(enemy, true)
				if retreat_step != enemy.grid_pos and is_valid_grid_pos(retreat_step) and grid[retreat_step.y][retreat_step.x] == 0:
					enemy.facing_dir = (retreat_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", retreat_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(retreat_step)
					_show_floating_text(enemy.position, "REPOSITION!", Color(1.0, 0.65, 0.2))
					continue
				else:
					var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
					if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
						enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
						enemy.set_intent("MOVE", next_step)
						if show_telegraphs:
							_spawn_enemy_move_indicator(next_step)
					else:
						enemy.set_intent("NONE", enemy.grid_pos)
					continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
					enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", next_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(next_step)
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
				
		# 2. CULTIST PYROMANCER: 3-Tile Cross Flame Blast
		if enemy.unit_type == "pyromancer":
			if dist_chebyshev <= 1:
				# Hero in melee range! Smart pyromancer kites/retreats away to cast safely
				var retreat_step = _find_strafe_step(enemy, true)
				if retreat_step != enemy.grid_pos and is_valid_grid_pos(retreat_step) and grid[retreat_step.y][retreat_step.x] == 0:
					enemy.facing_dir = (player.grid_pos - retreat_step).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", retreat_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(retreat_step)
					_show_floating_text(enemy.position, "KITING!", Color(0.4, 0.8, 1.0))
					continue
				# If cornered against wall with no retreat, blast at point blank!
			
			if dist_chebyshev <= 4 and has_los:
				var blast_tiles: Array[Vector2i] = [player.grid_pos]
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var b_tile = player.grid_pos + d
					if is_valid_grid_pos(b_tile) and grid[b_tile.y][b_tile.x] == 0:
						if has_line_of_sight(player.grid_pos, b_tile):
							blast_tiles.append(b_tile)
				if show_telegraphs:
					for bt in blast_tiles:
						_spawn_danger_indicator(bt)
				enemy.set_intent("BLAST", player.grid_pos, blast_tiles)
				continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
					enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", next_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(next_step)
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
			
		# 3. ORC BRAWLER: Wide 3-Tile Cleave Sweep + Smart Lateral Strafing
		if enemy.unit_type == "brawler":
			if dist_chebyshev <= 1 and has_los:
				# 35% chance to strafe sideways / flank hero to avoid hero's incoming frontal swing
				if randf() < 0.35:
					var strafe_step = _find_strafe_step(enemy, false)
					if strafe_step != enemy.grid_pos:
						enemy.facing_dir = (player.grid_pos - strafe_step).clamp(Vector2i(-1,-1), Vector2i(1,1))
						enemy.set_intent("MOVE", strafe_step)
						if show_telegraphs:
							_spawn_enemy_move_indicator(strafe_step)
						_show_floating_text(enemy.position, "STRAFE!", Color(0.4, 0.8, 1.0))
						continue
						
				var sweep_dir = (player.grid_pos - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.facing_dir = sweep_dir
				var sweep_tiles: Array[Vector2i] = [player.grid_pos]
				if sweep_dir.x != 0:
					sweep_tiles.append(enemy.grid_pos + Vector2i(sweep_dir.x, 1))
					sweep_tiles.append(enemy.grid_pos + Vector2i(sweep_dir.x, -1))
				else:
					sweep_tiles.append(enemy.grid_pos + Vector2i(1, sweep_dir.y))
					sweep_tiles.append(enemy.grid_pos + Vector2i(-1, sweep_dir.y))
					
				var valid_sweep: Array[Vector2i] = []
				for st in sweep_tiles:
					if is_valid_grid_pos(st) and grid[st.y][st.x] == 0:
						valid_sweep.append(st)
						if show_telegraphs:
							_spawn_danger_indicator(st)
				enemy.set_intent("SWEEP", player.grid_pos, valid_sweep)
				continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
					enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", next_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(next_step)
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
			
		# 4. SKELETON SHIELDBEARER & GRUNTS
		if dist_chebyshev <= 1 and has_los:
			# 35% chance to strafe sideways / flank hero to avoid hero's incoming attack
			if randf() < 0.35:
				var strafe_step = _find_strafe_step(enemy, false)
				if strafe_step != enemy.grid_pos:
					enemy.facing_dir = (player.grid_pos - strafe_step).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", strafe_step)
					if show_telegraphs:
						_spawn_enemy_move_indicator(strafe_step)
					_show_floating_text(enemy.position, "STRAFE!", Color(0.4, 0.8, 1.0))
					continue
					
			enemy.facing_dir = (player.grid_pos - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
			enemy.set_intent("ATTACK", player.grid_pos)
			if show_telegraphs:
				_spawn_danger_indicator(player.grid_pos)
		else:
			var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
			if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_intent("MOVE", next_step)
				if show_telegraphs:
					_spawn_enemy_move_indicator(next_step)
			else:
				enemy.set_intent("NONE", enemy.grid_pos)

func _find_smart_path_step(from_pos: Vector2i, target_pos: Vector2i, current_unit: CombatUnit) -> Vector2i:
	var diff = (target_pos - from_pos).abs()
	if diff.x <= 1 and diff.y <= 1:
		return from_pos

	var queue: Array[Vector2i] = [from_pos]
	var visited: Dictionary = {}
	visited[from_pos] = from_pos
	
	var blocked: Dictionary = {}
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != 0:
				blocked[Vector2i(x, y)] = true
				
	# Anti-clash coordination: block where other enemies are AND where they've claimed to move
	for other in active_combat_enemies:
		if is_instance_valid(other) and other != current_unit and other.is_alive and other.current_hp > 0:
			blocked[other.grid_pos] = true
			if other.intent_type == "MOVE":
				blocked[other.target_grid_pos] = true
			elif other.intent_type == "CHARGE":
				for ct in other.telegraphed_tiles:
					blocked[ct] = true

	var target_found: bool = false
	var goal_tile: Vector2i = from_pos
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	while not queue.is_empty():
		var curr = queue.pop_front()
		var dist_to_target = (target_pos - curr).abs()
		if dist_to_target.x <= 1 and dist_to_target.y <= 1:
			goal_tile = curr
			target_found = true
			break
			
		for d in directions:
			var neighbor = curr + d
			if is_valid_grid_pos(neighbor):
				if not blocked.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = curr
					queue.push_back(neighbor)

	if not target_found or goal_tile == from_pos:
		return from_pos

	var curr_trace = goal_tile
	var path: Array[Vector2i] = [curr_trace]
	while curr_trace != from_pos:
		curr_trace = visited[curr_trace]
		path.push_front(curr_trace)

	if path.size() >= 2:
		return path[1]

	return from_pos

func _spawn_danger_indicator(pos: Vector2i) -> void:
	var danger = Sprite2D.new()
	danger.texture = load("res://assets/ui/danger_tile.svg")
	danger.position = grid_to_world(pos)
	danger.visible = show_telegraphs
	reticle_container.add_child(danger)
	danger_indicators.append(danger)

func _spawn_enemy_move_indicator(pos: Vector2i) -> void:
	var move_ind = Sprite2D.new()
	move_ind.texture = load("res://assets/ui/indicator_enemy_move.svg")
	move_ind.position = grid_to_world(pos)
	move_ind.visible = show_telegraphs
	reticle_container.add_child(move_ind)
	danger_indicators.append(move_ind)

func _update_hud_display() -> void:
	if is_instance_valid(exp_hp_bar) and player:
		exp_hp_bar.max_value = player.max_hp
		exp_hp_bar.value = player.current_hp
		exp_hp_label.text = "❤️ %d / %d" % [player.current_hp, player.max_hp]
		
	var p_face = player.loaded_face
	if not p_face.is_empty():
		player_die_icon.texture = load(p_face["icon"])
		player_die_title.text = "🎲 %s  •  💥 %d DMG" % [p_face["title"], p_face["damage"]]
		player_die_desc.text = p_face["desc"]
		if player.has_method("update_hero_die_badge"):
			player.update_hero_die_badge()
		
	var monster_info: Array[String] = []
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0:
			var act = "⚔️ Strike"
			if enemy.intent_type == "CHARGE": act = "⏩ CHARGE"
			elif enemy.intent_type == "BLAST": act = "🔥 BLAST"
			elif enemy.intent_type == "SWEEP": act = "🪓 CLEAVE"
			elif enemy.intent_type == "MOVE": act = "👟 Advance"
			elif enemy.intent_type == "STUNNED": act = "💫 Stunned"
			monster_info.append("%s [%s, HP %d]" % [enemy.unit_name, act, enemy.current_hp])
	enemy_intel_label.text = "Threats: " + " | ".join(monster_info)

func _resolve_pulse() -> void:
	pulse_state = PulseState.RESOLVING
	commit_button.disabled = true
	phase_title.text = "💥 PULSE: SIMULTANEOUS CLASH!"
	phase_title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	
	# Deep cinematic sub-bass heartbeat pulse impact!
	play_pulse_heartbeat_sfx()
	
	var planned_player_pos = player_move_target if player_move_target != Vector2i(-1, -1) else player.grid_pos
	
	# STEP 1: MOVEMENT PHASE (0.35s)
	_log("[b]▶ MOVEMENT PHASE[/b]")
	var move_destinations = {}
	move_destinations[player] = planned_player_pos
	
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			move_destinations[enemy] = enemy.target_grid_pos if enemy.intent_type == "MOVE" else enemy.grid_pos
			
	for unit in move_destinations.keys():
		var dest = move_destinations[unit]
		if dest != unit.grid_pos:
			var clash = false
			for other_unit in move_destinations.keys():
				if other_unit != unit and move_destinations[other_unit] == dest:
					clash = true
					break
			if clash:
				_log("[color=#f59e0b]⚡ Clash on tile (%d, %d)! Stumbled back.[/color]" % [dest.x, dest.y])
				_show_floating_text(grid_to_world(dest), "CLASH!", Color(0.95, 0.7, 0.1))
				unit.animate_bump_back(grid_to_world(unit.grid_pos))
			else:
				unit.grid_pos = dest
				unit.animate_move_to(grid_to_world(dest))
				
	await get_tree().create_timer(0.35).timeout
	
	# STEP 2: CHARGE RESOLUTION (Chargers rush forward, slam into walls or other units!)
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.intent_type == "CHARGE":
			play_charger_rush_sfx()
			var charge_path = enemy.telegraphed_tiles
			var stopped = false
			for t_tile in charge_path:
				if stopped: break
				
				# Check if tile has hero
				if player.grid_pos == t_tile:
					enemy.animate_attack_thrust(grid_to_world(t_tile))
					var charge_face = {"title": "CHARGE SLAM", "damage": 8, "icon": "res://assets/ui/intent_enemy_charge.svg", "roll": 6}
					await _play_attack_impact_animation(player.position, charge_face, false)
					player.take_damage(8)
					_log("[color=#ef4444]💥 %s charged into Hero for 8 damage![/color]" % enemy.unit_name)
					_show_floating_text(player.position, "-8 HP (CHARGE)", Color(0.95, 0.2, 0.2))
					stopped = true
					break
					
				# Check if tile has other monster (Friendly Fire / Collision!)
				for other in active_combat_enemies:
					if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == t_tile:
						other.take_damage(6)
						enemy.take_damage(4)
						_log("[color=#f97316]💥 %s bowled over %s! FRIENDLY FIRE (6 DMG)![/color]" % [enemy.unit_name, other.unit_name])
						_show_floating_text(other.position, "COLLISION! -6 HP", Color(0.95, 0.6, 0.1))
						stopped = true
						break
						
				if not stopped:
					enemy.grid_pos = t_tile
					enemy.animate_move_to(grid_to_world(t_tile), 0.15)
					
			if not stopped:
				# Check if charger slammed into a wall at end of rush!
				var next_tile = enemy.grid_pos + enemy.facing_dir
				if not is_valid_grid_pos(next_tile) or grid[next_tile.y][next_tile.x] != 0:
					enemy.take_damage(6)
					enemy.set_stunned(true)
					_log("[color=#eab308]💥 %s CRASHED into wall! (6 Wall-Slam DMG + STUNNED!)[/color]" % enemy.unit_name)
					_show_floating_text(enemy.position, "WALL CRASH! STUNNED!", Color(0.98, 0.85, 0.2))
					enemy.animate_bump_back(grid_to_world(enemy.grid_pos))
					
	await get_tree().create_timer(0.25).timeout
	
	# STEP 3: PLAYER ATTACK PHASE (0.35s)
	_log("[b]▶ HERO ATTACK PHASE[/b]")
	if player_attack_target != Vector2i(-1, -1):
		player.animate_attack_thrust(grid_to_world(player_attack_target))
		var face = player.loaded_face
		var dmg = face.get("damage", 0)
		var is_knockback = face.get("knockback", false)
		
		var hit_enemy: CombatUnit = null
		for enemy in active_combat_enemies:
			if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == player_attack_target:
				hit_enemy = enemy
				break
				
		if hit_enemy:
			if dmg == 0:
				_log("[color=#94a3b8]Hero rolled MISS! Stumbled.[/color]")
				await _play_attack_impact_animation(hit_enemy.position, face, false)
				_show_floating_text(hit_enemy.position, "MISS!", Color(0.6, 0.6, 0.6))
			else:
				# CHECK SHIELDBEARER FRONTAL DEFENSE (Puzzle Mechanic!)
				var attack_blocked = false
				if hit_enemy.has_shield and not hit_enemy.shield_broken:
					var attack_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					# If hit comes directly from the front the shieldbearer is facing:
					if hit_enemy.facing_dir == -attack_dir or hit_enemy.facing_dir == Vector2i.ZERO:
						if is_knockback or dmg >= 8:
							# Heavy or knockback breaks shield!
							hit_enemy.shield_broken = true
							_log("[color=#38bdf8]⚡ Hero's heavy strike SHATTERED %s's shield![/color]" % hit_enemy.unit_name)
							_show_floating_text(hit_enemy.position, "GUARD BROKEN!", Color(0.3, 0.8, 0.95))
						else:
							attack_blocked = true
							_log("[color=#94a3b8]🛡️ %s's tower shield BLOCKED the front strike! (0 DMG - Flank or use Heavy!)[/color]" % hit_enemy.unit_name)
							_show_floating_text(hit_enemy.position, "BLOCKED BY SHIELD!", Color(0.38, 0.74, 0.97))
							
				await _play_attack_impact_animation(hit_enemy.position, face, attack_blocked)
				var attack_dir = (hit_enemy.position - player.position).normalized()
				if attack_blocked:
					_spawn_shield_barrier_vfx(hit_enemy.position)
				elif is_knockback or dmg >= 8:
					_spawn_shockwave(hit_enemy.position, Color(0.96, 0.72, 0.2))
				else:
					_spawn_slash_vfx(hit_enemy.position, attack_dir)
					
				if not attack_blocked:
					hit_enemy.take_damage(dmg, attack_dir)
					_log("[color=#22c55e]Hero struck %s for %d damage![/color]" % [hit_enemy.unit_name, dmg])
					_show_floating_text(hit_enemy.position, "-%d DMG" % dmg, Color(0.95, 0.85, 0.2))
					
					# PUSH / WALL SLAM PUZZLE MECHANIC
					if is_knockback and hit_enemy.is_alive:
						var push_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1, -1), Vector2i(1, 1))
						var pushed_pos = hit_enemy.grid_pos + push_dir
						
						# Check if pushed into wall -> WALL SLAM + STUN!
						if not is_valid_grid_pos(pushed_pos) or grid[pushed_pos.y][pushed_pos.x] != 0:
							hit_enemy.take_damage(4)
							hit_enemy.set_stunned(true)
							_log("[color=#eab308]💥 WALL SLAM! %s slammed into wall (+4 DMG + STUNNED!)[/color]" % hit_enemy.unit_name)
							_show_floating_text(hit_enemy.position, "WALL SLAM! (STUNNED)", Color(0.98, 0.8, 0.2))
							hit_enemy.animate_bump_back(grid_to_world(hit_enemy.grid_pos))
						else:
							# Check if pushed into another monster -> COLLISION!
							var collided_monster: CombatUnit = null
							for other in active_combat_enemies:
								if is_instance_valid(other) and other != hit_enemy and other.is_alive and other.grid_pos == pushed_pos:
									collided_monster = other
									break
							if collided_monster:
								collided_monster.take_damage(4)
								hit_enemy.take_damage(4)
								_log("[color=#f97316]💥 %s pushed into %s! COLLISION (4 DMG each)![/color]" % [hit_enemy.unit_name, collided_monster.unit_name])
								_show_floating_text(collided_monster.position, "COLLISION! -4 HP", Color(0.95, 0.6, 0.1))
							else:
								hit_enemy.grid_pos = pushed_pos
								hit_enemy.animate_move_to(grid_to_world(pushed_pos), 0.2)
		else:
			_log("[color=#94a3b8]Hero struck empty air! Target dodged.[/color]")
			_show_floating_text(grid_to_world(player_attack_target), "WHIFF!", Color(0.6, 0.7, 0.8))
			
	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
		return
		
	# STEP 4: ENEMY ATTACKS (Cleaves, Blasts, Strikes & Friendly Fire)
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive: continue
		
		# PYROMANCER BLAST (AoE)
		if enemy.intent_type == "BLAST":
			play_pyro_flame_sfx()
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			_log("[color=#f97316]🔥 %s detonated a Flame Blast![/color]" % enemy.unit_name)
			_spawn_fire_blast_vfx(enemy.telegraphed_tiles)
			_shake_camera(6.0, 0.2)
			for b_tile in enemy.telegraphed_tiles:
				_spawn_hazard_tile(b_tile)
				if player.grid_pos == b_tile:
					var blast_face = {"title": "FLAME BLAST", "damage": 7, "icon": "res://assets/ui/die_face_fire.svg", "roll": 5}
					await _play_attack_impact_animation(player.position, blast_face, false)
					player.take_damage(7, (player.position - grid_to_world(enemy.target_grid_pos)).normalized())
					_log("[color=#ef4444]Hero caught in flame blast! (-7 HP)[/color]")
					_show_floating_text(player.position, "-7 HP (FIRE)", Color(0.95, 0.25, 0.25))
				# Friendly fire on any other monster in blast!
				for other in active_combat_enemies:
					if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == b_tile:
						other.take_damage(7, (other.position - grid_to_world(enemy.target_grid_pos)).normalized())
						_log("[color=#f97316]Friendly fire! %s caught in blast (-7 HP)[/color]" % other.unit_name)
						_show_floating_text(other.position, "-7 HP (FIRE)", Color(0.95, 0.6, 0.1))
						
		# ORC BRAWLER SWEEP (3-Tile Arc)
		elif enemy.intent_type == "SWEEP":
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			_log("[color=#ef4444]🪓 %s unleashes a WIDE CLEAVE SWEEP![/color]" % enemy.unit_name)
			_spawn_cleave_sweep_vfx(grid_to_world(enemy.target_grid_pos), enemy.facing_dir)
			_shake_camera(5.0, 0.18)
			for s_tile in enemy.telegraphed_tiles:
				if player.grid_pos == s_tile:
					var cleave_face = {"title": "CLEAVE SWEEP", "damage": 6, "icon": "res://assets/ui/icon_axe.svg", "roll": 5}
					await _play_attack_impact_animation(player.position, cleave_face, false)
					player.take_damage(6, (player.position - enemy.position).normalized())
					_log("[color=#ef4444]Hero caught in cleave arc! (-6 HP)[/color]")
					_show_floating_text(player.position, "-6 HP", Color(0.95, 0.25, 0.25))
				for other in active_combat_enemies:
					if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == s_tile:
						other.take_damage(6, (other.position - enemy.position).normalized())
						_log("[color=#f97316]Friendly fire! %s caught in cleave (-6 HP)[/color]" % other.unit_name)
						_show_floating_text(other.position, "-6 HP", Color(0.95, 0.6, 0.1))
						
		# STANDARD MELEE STRIKE
		elif enemy.intent_type == "ATTACK":
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			var face = enemy.loaded_face
			var dmg = face.get("damage", 4)
			var e_dir = (grid_to_world(enemy.target_grid_pos) - enemy.position).normalized()
			
			if player.grid_pos == enemy.target_grid_pos:
				_spawn_slash_vfx(player.position, e_dir, Color(0.95, 0.35, 0.35))
				_shake_camera(4.0, 0.15)
				await _play_attack_impact_animation(player.position, face, false)
				player.take_damage(dmg, e_dir)
				_log("[color=#ef4444]%s struck Hero for %d damage![/color]" % [enemy.unit_name, dmg])
				_show_floating_text(player.position, "-%d HP" % dmg, Color(0.95, 0.25, 0.25))
			else:
				_log("[color=#38bdf8]Hero dodged %s's strike![/color]" % enemy.unit_name)
				_show_floating_text(player.position, "DODGED!", Color(0.2, 0.8, 0.4))
				
	# STEP 5: HAZARD TILE TICKS
	_process_hazard_tiles()
	
	await get_tree().create_timer(0.35).timeout
	
	if player.current_hp <= 0:
		_game_over()
		return
		
	# STEP 6: NEXT PULSE (Rolls & tumble animations trigger in _start_planning_phase)
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.clear_intent()
			
	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
	else:
		_start_planning_phase()

func _spawn_hazard_tile(pos: Vector2i) -> void:
	if hazard_tiles.has(pos):
		hazard_tiles[pos]["duration"] = 2
		return
		
	var h_sprite = Sprite2D.new()
	h_sprite.texture = load("res://assets/ui/hazard_fire_tile.svg")
	h_sprite.position = grid_to_world(pos)
	hazard_container.add_child(h_sprite)
	
	hazard_tiles[pos] = {
		"duration": 2, # Lasts 2 pulses
		"sprite": h_sprite
	}

func _process_hazard_tiles() -> void:
	var expired = []
	for pos in hazard_tiles.keys():
		var h = hazard_tiles[pos]
		# Check if player on fire
		if player.grid_pos == pos:
			player.take_damage(3)
			_show_floating_text(player.position, "-3 BURN!", Color(0.95, 0.4, 0.1))
			
		# Check if monster on fire
		for enemy in active_combat_enemies:
			if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == pos:
				enemy.take_damage(3)
				_show_floating_text(enemy.position, "-3 BURN!", Color(0.95, 0.4, 0.1))
				
		h["duration"] -= 1
		if h["duration"] <= 0:
			expired.append(pos)
			
	for p in expired:
		if hazard_tiles.has(p):
			hazard_tiles[p]["sprite"].queue_free()
			hazard_tiles.erase(p)

func _on_active_room_cleared() -> void:
	var total_hostile = maxi(1, dungeon_rooms.size() - 1)
	if not cleared_rooms.has(current_combat_room_id):
		cleared_rooms.append(current_combat_room_id)
		if is_instance_valid(exp_chambers_label):
			exp_chambers_label.text = "Chambers Conquered: %d / %d  |  Move with [WASD]" % [cleared_rooms.size(), total_hostile]
	all_enemies = all_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	
	# Spawn chest for the room that was cleared
	var chest_pos = player.grid_pos
	for r in dungeon_rooms:
		if r["id"] == current_combat_room_id:
			chest_pos = r["center"]
			break
			
	var reward_type = "flame_rune"
	if current_combat_room_id >= dungeon_rooms.size() - 1:
		reward_type = "dungeon_crown" # Final Boss Vault
	else:
		var reward_pool = ["flame_rune", "shield_basher", "chaos_blast", "executioner_edge"]
		reward_type = reward_pool[(current_combat_room_id - 1) % reward_pool.size()]
		
	_spawn_treasure_chest(chest_pos, reward_type)
		
	var any_remaining = not all_enemies.is_empty()
	if not any_remaining:
		_game_conquered()
	else:
		_log("[color=#22c55e][b]🏆 CHAMBER CLEARED! A treasure chest has appeared! Returning to Exploration mode...[/b][/color]")
		_show_floating_text(player.position, "ROOM CLEARED!", Color(0.2, 0.9, 0.4))
		var t = create_tween()
		t.tween_interval(1.0)
		t.tween_callback(_enter_exploration_mode)

func _spawn_treasure_chest(pos: Vector2i, reward_type: String = "flame_rune") -> void:
	for c in chests:
		if c["pos"] == pos:
			return # Avoid duplicate
			
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/chest_closed.svg")
	sprite.position = grid_to_world(pos)
	chest_container.add_child(sprite)
	
	sprite.scale = Vector2(0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	chests.append({
		"pos": pos,
		"is_open": false,
		"sprite": sprite,
		"reward": reward_type
	})

func _show_floating_text(world_pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	# Offset off to the side so it doesn't cover the unit or northern tile!
	label.position = world_pos + Vector2(24, -28)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.z_as_relative = false
	label.z_index = 32
	effects_container.add_child(label)
	
	var tween = create_tween()
	# Float up-and-away diagonally to the side
	tween.tween_property(label, "position", label.position + Vector2(10, -28), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func _spawn_slash_vfx(target_pos: Vector2, dir: Vector2, color: Color = Color(0.38, 0.85, 1.0), scale_mult: float = 1.0) -> void:
	if not effects_container: return
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/ui/vfx_slash_arc.svg")
	spr.position = target_pos
	spr.rotation = dir.angle() if dir != Vector2.ZERO else randf_range(-0.4, 0.4)
	spr.modulate = color
	spr.scale = Vector2(0.2, 0.2)
	effects_container.add_child(spr)
	
	var t = create_tween()
	t.tween_property(spr, "scale", Vector2(1.25 * scale_mult, 1.25 * scale_mult), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(spr, "rotation", spr.rotation + 0.4, 0.16)
	t.tween_property(spr, "modulate:a", 0.0, 0.12)
	t.tween_callback(spr.queue_free)

func _spawn_shockwave(target_pos: Vector2, color: Color = Color(0.96, 0.72, 0.2)) -> void:
	if not effects_container: return
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/ui/vfx_shockwave.svg")
	spr.position = target_pos
	spr.modulate = color
	spr.scale = Vector2(0.2, 0.2)
	effects_container.add_child(spr)
	
	var t = create_tween()
	t.tween_property(spr, "scale", Vector2(1.6, 1.6), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(spr, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(spr.queue_free)

func _spawn_shield_barrier_vfx(target_pos: Vector2) -> void:
	if not effects_container: return
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/ui/vfx_shield_barrier.svg")
	spr.position = target_pos
	spr.scale = Vector2(0.4, 0.4)
	effects_container.add_child(spr)
	
	var t = create_tween()
	t.tween_property(spr, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(spr, "scale", Vector2.ONE, 0.1)
	t.tween_property(spr, "modulate:a", 0.0, 0.18)
	t.tween_callback(spr.queue_free)

func _spawn_fire_blast_vfx(target_tiles: Array) -> void:
	if not effects_container: return
	for i in range(target_tiles.size()):
		var tile = target_tiles[i]
		var spr = Sprite2D.new()
		spr.texture = load("res://assets/ui/vfx_fire_blast.svg")
		spr.position = grid_to_world(tile)
		spr.scale = Vector2(0.2, 0.2)
		spr.rotation = randf_range(0.0, TAU)
		effects_container.add_child(spr)
		
		var t = create_tween()
		if i > 0:
			t.tween_interval(i * 0.03)
		t.tween_property(spr, "scale", Vector2(1.3, 1.3), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(spr, "rotation", spr.rotation + 0.8, 0.22)
		t.tween_property(spr, "modulate:a", 0.0, 0.15)
		t.tween_callback(spr.queue_free)

func _spawn_cleave_sweep_vfx(target_pos: Vector2, facing: Vector2i) -> void:
	if not effects_container: return
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/ui/vfx_slash_arc.svg")
	spr.position = target_pos
	spr.modulate = Color(1.0, 0.35, 0.2)
	spr.scale = Vector2(0.3, 0.3)
	spr.rotation = Vector2(facing).angle() if facing != Vector2i.ZERO else 0.0
	effects_container.add_child(spr)
	
	var t = create_tween()
	t.tween_property(spr, "scale", Vector2(2.0, 2.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(spr, "rotation", spr.rotation + 1.2, 0.22)
	t.tween_property(spr, "modulate:a", 0.0, 0.14)
	t.tween_callback(spr.queue_free)

func _spawn_dust_puff(pos: Vector2) -> void:
	if not effects_container: return
	var spr = Sprite2D.new()
	spr.texture = load("res://assets/ui/vfx_dust_puff.svg")
	spr.position = pos + Vector2(randf_range(-4, 4), randf_range(-2, 2))
	spr.scale = Vector2(0.3, 0.3)
	spr.modulate = Color(1.0, 1.0, 1.0, 0.6)
	effects_container.add_child(spr)
	
	var t = create_tween()
	t.tween_property(spr, "scale", Vector2(0.9, 0.9), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(spr, "position:y", spr.position.y - 8.0, 0.24)
	t.parallel().tween_property(spr, "modulate:a", 0.0, 0.24)
	t.tween_callback(spr.queue_free)

func _spawn_chest_loot_burst(pos: Vector2) -> void:
	if not effects_container: return
	for i in range(6):
		var spr = Sprite2D.new()
		spr.texture = load("res://assets/ui/vfx_coin_sparkle.svg")
		spr.position = pos
		spr.scale = Vector2(0.4, 0.4)
		effects_container.add_child(spr)
		
		var angle = deg_to_rad(-140.0 + (i * 20.0) + randf_range(-6.0, 6.0))
		var dist = randf_range(30.0, 55.0)
		var dest = pos + Vector2(cos(angle), sin(angle)) * dist
		
		var t = create_tween()
		t.tween_property(spr, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(spr, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(spr, "rotation", randf_range(-3.0, 3.0), 0.45)
		t.tween_property(spr, "position:y", dest.y + 12.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(spr, "modulate:a", 0.0, 0.2)
		t.tween_callback(spr.queue_free)

func _shake_camera(intensity: float = 4.0, duration: float = 0.18) -> void:
	if not camera:
		return
	var tween = create_tween()
	var steps = int(duration / 0.03)
	for i in range(steps):
		var damp = 1.0 - (float(i) / float(steps))
		var shake_vec = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)) * damp
		tween.tween_property(camera, "offset", shake_vec, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _trigger_pulse_roll() -> void:
	if not player or not player.die:
		return
		
	# Play acoustic dice tumbling clatter
	play_dice_tumble_sfx()
		
	# 1. Roll actual next faces
	player.roll_next_face()
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.roll_next_face()
			
	# 2. Animate HUD Die Tumbler
	_animate_hud_die_tumbler()
	
	# 3. Animate Hero Overhead Tumbler
	_animate_overhead_hero_roll()
	
	# 4. Animate Enemies Overhead Tumbler
	_animate_overhead_enemies_roll()
	
	_log("[color=#facc15]🎲 Pulse Roll: Hero loaded [b]%s[/b] (%d DMG)![/color]" % [player.loaded_face.get("title", ""), player.loaded_face.get("damage", 0)])

func _animate_hud_die_tumbler() -> void:
	if not player_die_icon or not player or not player.die:
		return
		
	var roll_tween = create_tween()
	var final_tex_path = player.loaded_face.get("icon", "res://assets/ui/die_face_1.svg")
	var final_tex = load(final_tex_path) if ResourceLoader.exists(final_tex_path) else null
	
	player_die_title.text = "🎲 ROLLING..."
	player_die_title.add_theme_color_override("font_color", Color(0.98, 0.8, 0.2))
	player_die_desc.text = "Tumbling %s..." % player.die.name
	
	# Rapid face shuffles (6 steps over 0.36s)
	for i in range(6):
		roll_tween.tween_callback(func():
			if not cached_die_textures.is_empty():
				player_die_icon.texture = cached_die_textures.pick_random()
			player_die_icon.rotation = randf_range(-0.35, 0.35)
			player_die_icon.scale = Vector2(1.2, 1.2)
		)
		roll_tween.tween_interval(0.06)
		
	# Settle on final face with punch scale
	roll_tween.tween_callback(func():
		player_die_icon.rotation = 0.0
		if final_tex:
			player_die_icon.texture = final_tex
		player_die_icon.scale = Vector2(1.4, 1.4)
		_update_hud_display()
		if is_backpack_open:
			_render_backpack_ui()
	)
	roll_tween.tween_property(player_die_icon, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_overhead_hero_roll() -> void:
	if not player:
		return
		
	if player.has_method("update_hero_die_badge"):
		# Shuffle hero plate icon during the roll tumble
		if player.hero_plate:
			player.hero_plate.visible = true
			var roll_tween = create_tween()
			for i in range(5):
				roll_tween.tween_callback(func():
					if not cached_die_textures.is_empty() and player.hero_icon:
						player.hero_icon.texture = cached_die_textures.pick_random()
					if player.hero_plate:
						player.hero_plate.scale = Vector2(1.2, 1.2)
				)
				roll_tween.tween_interval(0.06)
			roll_tween.tween_callback(func():
				player.update_hero_die_badge()
			)

func _animate_overhead_enemies_roll() -> void:
	if not active_combat_enemies.is_empty():
		play_enemy_intent_sfx()
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if enemy.intent_plate and enemy.intent_icon:
			enemy.intent_plate.visible = true
			var roll_tween = create_tween()
			for i in range(4):
				roll_tween.tween_callback(func():
					if not cached_die_textures.is_empty() and enemy.intent_icon:
						enemy.intent_icon.texture = cached_die_textures.pick_random()
					if enemy.intent_plate:
						enemy.intent_plate.scale = Vector2(1.15, 1.15)
				)
				roll_tween.tween_interval(0.06)
			roll_tween.tween_callback(func():
				if enemy.intent_plate:
					enemy.intent_plate.scale = Vector2.ONE
			)

func _play_attack_impact_animation(target_world_pos: Vector2, face: Dictionary, is_blocked: bool = false) -> void:
	var impact_node = Node2D.new()
	# Position off to the side flank so the target tile and surrounding grid remain completely visible!
	var side_offset_x = 76.0
	if camera and target_world_pos.x > (camera.position.x + 140.0):
		side_offset_x = -76.0
	var final_impact_pos = target_world_pos + Vector2(side_offset_x, -16.0)
	impact_node.position = final_impact_pos
	impact_node.z_as_relative = false
	impact_node.z_index = 35 # High z-index so it floats above all units and walls
	effects_container.add_child(impact_node)
	
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(8)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 6
	p_style.content_margin_bottom = 6
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	
	var dmg = face.get("damage", 0)
	var is_crit = (face.get("roll", 0) == 6 or dmg >= 9)
	var is_miss = (dmg == 0)
	
	if is_blocked:
		p_style.border_color = Color(0.38, 0.74, 0.97)
		p_style.set_border_width_all(2.5)
	elif is_crit:
		p_style.border_color = Color(1.0, 0.4, 0.15)
		p_style.set_border_width_all(2.5)
	elif is_miss:
		p_style.border_color = Color(0.5, 0.55, 0.65)
		p_style.set_border_width_all(1.5)
	else:
		p_style.border_color = Color(0.98, 0.82, 0.2)
		p_style.set_border_width_all(2.5)
		
	panel.add_theme_stylebox_override("panel", p_style)
	impact_node.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	var icon = TextureRect.new()
	var icon_path = face.get("icon", "res://assets/ui/die_face_1.svg")
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	
	var title_lbl = Label.new()
	var action_title = face.get("title", "STRIKE")
	if is_blocked:
		title_lbl.text = "🛡️ BLOCKED!"
		title_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	elif is_crit:
		title_lbl.text = "⚡ %s (CRIT!)" % action_title
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	elif is_miss:
		title_lbl.text = "💨 MISS"
		title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	else:
		title_lbl.text = "⚔️ %s" % action_title
		title_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	title_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_lbl)
	
	var dmg_lbl = Label.new()
	if is_blocked:
		dmg_lbl.text = "0 DMG"
		dmg_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	elif is_miss:
		dmg_lbl.text = "0 DMG"
		dmg_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		dmg_lbl.text = "%d DMG" % dmg
		dmg_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55) if not is_crit else Color(1.0, 0.85, 0.2))
	dmg_lbl.add_theme_font_size_override("font_size", 18) # Bold damage number
	vbox.add_child(dmg_lbl)
	
	# Center the panel around impact_node position
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-70, -28)
	
	# Initial pose for slam: scaled small and elevated
	impact_node.scale = Vector2(0.2, 0.2)
	impact_node.position.y -= 25.0
	impact_node.rotation = randf_range(-0.35, 0.35)
	
	var tween = create_tween()
	# Fast punchy slam down onto the side flank!
	tween.tween_property(impact_node, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact_node, "position:y", final_impact_pos.y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact_node, "rotation", 0.0, 0.12)
	
	# Camera shake and dynamic combat sound impact!
	_shake_camera(5.0 if is_crit else (2.0 if is_blocked else 3.5), 0.15)
	if is_crit:
		play_critical_hit_sfx()
	elif is_blocked:
		play_shield_parry_sfx()
	elif is_miss:
		play_attack_whiff_sfx()
	elif "HAMMER" in action_title.to_upper() or "BASH" in action_title.to_upper() or "SMASH" in action_title.to_upper() or dmg >= 8:
		play_hammer_slam_sfx()
	else:
		play_sword_slash_sfx()
	
	# Update HUD Last Action Callout
	if last_action_label:
		if is_blocked:
			last_action_label.text = "🛡️ LAST STRIKE: %s blocked by shield! (0 DMG)" % action_title
			last_action_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		elif is_miss:
			last_action_label.text = "💨 LAST STRIKE: Missed / Whiffed! (0 DMG)"
			last_action_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		elif is_crit:
			last_action_label.text = "⚡ LAST STRIKE: %s [CRIT %d DMG]!" % [action_title, dmg]
			last_action_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		else:
			last_action_label.text = "⚔️ LAST STRIKE: %s dealt %d DMG!" % [action_title, dmg]
			last_action_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			
	# Hold for readability (snappy 0.45s so it never hangs into planning!)
	await get_tree().create_timer(0.45).timeout
	
	if not is_instance_valid(impact_node) or not impact_node.is_inside_tree():
		return

	# Smoothly pop and dissolve out
	var fade_tween = create_tween()
	fade_tween.tween_property(impact_node, "scale", Vector2(1.35, 1.35), 0.15)
	fade_tween.parallel().tween_property(impact_node, "modulate:a", 0.0, 0.15)
	fade_tween.parallel().tween_property(impact_node, "position:y", impact_node.position.y - 16.0, 0.15)
	fade_tween.tween_callback(impact_node.queue_free)
	await fade_tween.finished

func _on_player_died(_unit: CombatUnit) -> void:
	_game_over()

func _on_enemy_died(enemy: CombatUnit) -> void:
	all_enemies.erase(enemy)
	_log("[color=#fbbf24]💀 %s has been slain![/color]" % enemy.unit_name)
	_show_floating_text(enemy.position, "SLAIN!", Color(0.95, 0.8, 0.1))
	_spawn_shockwave(enemy.position, Color(0.85, 0.25, 0.25))
	_shake_camera(4.5, 0.18)
	var death_tween = enemy.animate_death_collapse()
	death_tween.tween_callback(func():
		if is_instance_valid(enemy):
			enemy.queue_free()
	)

func _game_conquered() -> void:
	current_mode = GameMode.GAME_OVER
	phase_title.text = "🏆 DUNGEON CONQUERED!"
	phase_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	_log("[color=#22c55e][b]🎉 VICTORY! All 5 chambers purged. You are the Dungeon Conqueror! Press R to play again.[/b][/color]")
	_enter_exploration_mode()

func _game_over() -> void:
	current_mode = GameMode.GAME_OVER
	phase_title.text = "💀 DEFEAT! YOU PERISHED"
	phase_title.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	_log("[color=#ef4444][b]DEFEAT! The dungeon claimed your soul. Press R to restart.[/b][/color]")

func _on_commit_pressed() -> void:
	if current_mode == GameMode.COMBAT_PULSE and pulse_state == PulseState.PLANNING:
		play_dice_lock_sfx()
		_resolve_pulse()

func _on_toggle_telegraphs() -> void:
	show_telegraphs = !show_telegraphs
	telegraph_button.text = "👁️ Telegraphs: ON" if show_telegraphs else "👁️ Telegraphs: OFF"
	for danger in danger_indicators:
		if is_instance_valid(danger):
			danger.visible = show_telegraphs
	_log("[color=#94a3b8]Telegraphs %s[/color]" % ("enabled" if show_telegraphs else "disabled"))

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _log(bbcode: String) -> void:
	if log_label:
		log_label.text += bbcode + "\n"

func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_SIZE + TILE_SIZE * 0.5, pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func world_to_grid(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / TILE_SIZE)), int(floor(world.y / TILE_SIZE)))

func is_valid_grid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT
