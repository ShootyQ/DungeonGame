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
var player_move_target_2: Vector2i = Vector2i(-1, -1)
var player_attack_target: Vector2i = Vector2i(-1, -1)
var player_attack_target_2: Vector2i = Vector2i(-1, -1)
var player_action_order: String = "move_first" # "move_first", "attack_first"
var action_order_btn: Button
var stance_btn_1: Button
var stance_btn_2: Button
var move_indicator_2: Sprite2D
var attack_indicator_2: Sprite2D

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

# Character Equipment & Stash State (10 Slots)
const BASE_HP: int = 20
var equipped_gear: Dictionary = {
	"helmet": null,
	"necklace": null,
	"chestplate": null,
	"hand_1": null,
	"hand_2": null,
	"gloves": null,
	"pants": null,
	"boots": null,
	"ring_1": null,
	"ring_2": null
}
var inventory_items: Array[ItemData] = []
var selected_inventory_tab: String = "All"
var room_torches: Dictionary = {} # room_id -> Array[{sconce, glow}]

# Character Creation & Customization State
var char_custom_view_container: VBoxContainer
var custom_gender: String = "male"
var custom_face: int = 1
var custom_hair: String = "short_brown"
var custom_cloak: String = "cloak_blue"
var custom_preview_visual: HeroVisual

# Diablo Inventory UI State
var item_tooltip_panel: PanelContainer
var item_tooltip_title: Label
var item_tooltip_type: Label
var item_tooltip_stats: Label
var item_tooltip_desc: Label
var item_tooltip_value: Label
var item_tooltip_actions: Label
var selected_stash_item: ItemData = null

# Character Sheet UI Nodes
var char_title_label: Label
var char_level_label: Label
var char_exp_bar: ProgressBar
var char_exp_label: Label
var char_hp_label: Label
var char_armor_label: Label
var char_dmg_label: Label
var char_str_label: Label
var char_dex_label: Label
var char_int_label: Label
var char_stat_points_container: HBoxContainer
var active_weapon_trait_label: Label
var char_paper_doll_container: VBoxContainer
var inventory_stash_container: GridContainer
var inventory_scroll: ScrollContainer
var socket_prompt_bar: PanelContainer
var filter_tab_buttons: Dictionary = {}

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

# Step 4: Gold Economy, Town Blacksmith & Estate Manor
var exp_gold_label: Label
var char_gold_label: Label
var current_backpack_view: String = "hero"
var hero_view_container: HBoxContainer
var blacksmith_view_container: VBoxContainer
var estate_view_container: VBoxContainer
var view_tab_buttons: Dictionary = {}

var blacksmith_face_wares: Array[ItemData] = []
var blacksmith_weapon_wares: Array[ItemData] = []

var estate_pedestals_unlocked: int = 4
var estate_trophy_slots: Array = [null, null, null, null, null, null]

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
	_generate_blacksmith_wares()
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
	
	chest_container = Node2D.new()
	chest_container.z_index = 4
	board_container.add_child(chest_container)
	
	reticle_container = Node2D.new()
	reticle_container.z_index = 5
	board_container.add_child(reticle_container)
	
	fog_container = Node2D.new()
	fog_container.z_index = 8
	board_container.add_child(fog_container)
	
	door_container = Node2D.new()
	door_container.z_index = 9 # Closed doors render crisply on top of fog so they are fully visible!
	board_container.add_child(door_container)
	
	unit_container = Node2D.new()
	unit_container.z_index = 10 # Units render on top of doors and fog
	board_container.add_child(unit_container)
	
	lighting_container = Node2D.new()
	lighting_container.z_index = 12
	board_container.add_child(lighting_container)
	
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

	move_indicator_2 = Sprite2D.new()
	move_indicator_2.texture = load("res://assets/ui/indicator_move.svg")
	move_indicator_2.centered = true
	move_indicator_2.modulate = Color(1.0, 0.85, 0.25, 0.95)
	move_indicator_2.scale = Vector2(1.15, 1.15)
	move_indicator_2.visible = false
	reticle_container.add_child(move_indicator_2)
	
	attack_indicator = Sprite2D.new()
	attack_indicator.texture = load("res://assets/ui/indicator_attack.svg")
	attack_indicator.centered = true
	attack_indicator.visible = false
	target_overlay_container.add_child(attack_indicator)

	attack_indicator_2 = Sprite2D.new()
	attack_indicator_2.texture = load("res://assets/ui/indicator_attack.svg")
	attack_indicator_2.centered = true
	attack_indicator_2.modulate = Color(1.0, 0.45, 0.2, 0.95)
	attack_indicator_2.scale = Vector2(1.15, 1.15)
	attack_indicator_2.visible = false
	target_overlay_container.add_child(attack_indicator_2)

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
	room_torches.clear()
	var tex_sconce = load("res://assets/sprites/torch_sconce.svg")
	var tex_glow = load("res://assets/sprites/light_glow.svg")

	var sconce_positions = dungeon_data.get("torches", [])

	for entry in sconce_positions:
		var pos = entry["pos"] if (entry is Dictionary and entry.has("pos")) else entry
		var r_id = entry.get("room_id", -1) if (entry is Dictionary) else -1
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

		if r_id > 0:
			# Unbreached room torches start hidden so they don't glow in pitch-black fog
			sconce_spr.visible = false
			glow.visible = false
			if not room_torches.has(r_id):
				room_torches[r_id] = []
			room_torches[r_id].append({"sconce": sconce_spr, "glow": glow})

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

func _create_doors() -> void:
	doors.clear()
	var paired_door_textures = {
		"horizontal": {
			"left": {
				"closed": load("res://assets/sprites/door_horiz_left_closed.svg"),
				"open": load("res://assets/sprites/door_horiz_left_open.svg")
			},
			"right": {
				"closed": load("res://assets/sprites/door_horiz_right_closed.svg"),
				"open": load("res://assets/sprites/door_horiz_right_open.svg")
			}
		},
		"vertical": {
			"top": {
				"closed": load("res://assets/sprites/door_vert_top_closed.svg"),
				"open": load("res://assets/sprites/door_vert_top_open.svg")
			},
			"bottom": {
				"closed": load("res://assets/sprites/door_vert_bottom_closed.svg"),
				"open": load("res://assets/sprites/door_vert_bottom_open.svg")
			}
		}
	}

	for cfg in dungeon_data.get("doors", []):
		var orient = cfg.get("orientation", "horizontal")
		var part = cfg.get("part", "left")
		var sprite = Sprite2D.new()
		sprite.texture = paired_door_textures.get(orient, {}).get(part, {}).get("closed", paired_door_textures["horizontal"]["left"]["closed"])
		sprite.position = grid_to_world(cfg["pos"])
		door_container.add_child(sprite)
		doors.append({
			"pos": cfg["pos"],
			"room_id": cfg["room_id"],
			"orientation": orient,
			"part": part,
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
	inventory_items.clear()
	
	# Hero (Starts in Entrance Room)
	var spawn_pos = dungeon_data.get("player_spawn", Vector2i(6, 30))
	player = CombatUnit.new()
	unit_container.add_child(player)
	var start_sword_die = DieData.create_default_d6_sword()
	player.setup("Knight", true, BASE_HP, load("res://assets/sprites/hero.svg"), spawn_pos, start_sword_die)
	player.position = grid_to_world(player.grid_pos)
	player.died.connect(_on_player_died)
	player.hp_changed.connect(func(_u, new_hp, m_hp):
		if is_instance_valid(exp_hp_bar):
			exp_hp_bar.max_value = m_hp
			exp_hp_bar.value = new_hp
			exp_hp_label.text = "❤️ %d / %d" % [new_hp, m_hp]
	)
	
	# Initial Hero Equipment: Pure starter 6-sided die weapon (No other gear - slow-burn progression!)
	equipped_gear = {
		"helmet": null,
		"necklace": null,
		"chestplate": null,
		"hand_1": ItemData.create_starter_sword(),
		"hand_2": null,
		"gloves": null,
		"pants": null,
		"boots": null,
		"ring_1": null,
		"ring_2": null
	}
	inventory_items.clear()
	_recalculate_gear_stats()
	
	# Legacy backpack sync
	backpack_weapons.append(start_sword_die.duplicate_die())
	
	# Populate procedural enemies
	for e in dungeon_data.get("enemies", []):
		var en = _create_enemy(e["name"], e["hp"], e["tex"], e["pos"], e["room_id"], e.get("type", "grunt"))
		if e.has("facing"):
			en.facing_dir = e["facing"]
		all_enemies.append(en)
	
	for enemy in all_enemies:
		enemy.visible = false # Hidden in the fog until room is breached!
		enemy.is_active_in_combat = false

func _create_enemy(p_name: String, hp: int, tex_path: String, pos: Vector2i, p_room_id: int, p_type: String = "grunt") -> CombatUnit:
	var enemy = CombatUnit.new()
	unit_container.add_child(enemy)
	enemy.setup(p_name, false, hp, load(tex_path), pos, DieData.create_default_d6_sword(), p_type)
	match p_type:
		"grunt":
			enemy.stat_dex = 12 if "Goblin" in p_name else 8
		"charger":
			enemy.stat_dex = 11
		"shieldbearer":
			enemy.stat_dex = 7
		"pyromancer":
			enemy.stat_dex = 9
		"brawler":
			enemy.stat_dex = 6
		_:
			enemy.stat_dex = 9
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
	hero_title.add_theme_font_size_override("font_size", 13)
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
	exp_hp_bar.custom_minimum_size = Vector2(85, 8)
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
	exp_title.add_theme_font_size_override("font_size", 14)
	exp_title.add_theme_color_override("font_color", Color(0.3, 0.85, 0.55))
	obj_vbox.add_child(exp_title)

	var total_hostile = maxi(1, dungeon_rooms.size() - 1)
	exp_chambers_label = Label.new()
	exp_chambers_label.text = "Chambers: 0 / %d  •  [WASD] Move  •  Breach doors to battle" % total_hostile
	exp_chambers_label.add_theme_font_size_override("font_size", 11)
	exp_chambers_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	obj_vbox.add_child(exp_chambers_label)

	# Right: Action Buttons & Currency
	var right_btn_hbox = HBoxContainer.new()
	right_btn_hbox.add_theme_constant_override("separation", 8)
	right_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	exp_hbox.add_child(right_btn_hbox)

	exp_gold_label = Label.new()
	exp_gold_label.text = "🪙 100 Gold"
	exp_gold_label.add_theme_font_size_override("font_size", 12)
	exp_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	right_btn_hbox.add_child(exp_gold_label)

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
	combat_hud.offset_top = 8
	combat_hud.offset_bottom = 114
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.08, 0.10, 0.15, 0.96)
	c_style.border_color = Color(0.22, 0.74, 0.97)
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(8)
	c_style.content_margin_left = 14
	c_style.content_margin_right = 14
	c_style.content_margin_top = 5
	c_style.content_margin_bottom = 5
	combat_hud.add_theme_stylebox_override("panel", c_style)
	combat_hud.visible = false
	hud_root.add_child(combat_hud)
	
	var combat_vbox = VBoxContainer.new()
	combat_vbox.add_theme_constant_override("separation", 3)
	combat_hud.add_child(combat_vbox)

	var combat_main_hbox = HBoxContainer.new()
	combat_main_hbox.add_theme_constant_override("separation", 16)
	combat_vbox.add_child(combat_main_hbox)
	
	# Big Pulse Roll Showcase Panel
	var roll_card = PanelContainer.new()
	roll_card.custom_minimum_size = Vector2(210, 64)
	var rc_style = StyleBoxFlat.new()
	rc_style.bg_color = Color(0.06, 0.08, 0.13, 0.98)
	rc_style.border_color = Color(0.98, 0.82, 0.2, 0.9)
	rc_style.set_border_width_all(2)
	rc_style.set_corner_radius_all(8)
	rc_style.content_margin_left = 8
	rc_style.content_margin_right = 10
	rc_style.content_margin_top = 4
	rc_style.content_margin_bottom = 4
	roll_card.add_theme_stylebox_override("panel", rc_style)
	combat_main_hbox.add_child(roll_card)

	var rc_hbox = HBoxContainer.new()
	rc_hbox.add_theme_constant_override("separation", 10)
	rc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_card.add_child(rc_hbox)

	# 54x54 Hero Die Icon with tooltip and click to open bag
	player_die_icon = TextureRect.new()
	player_die_icon.custom_minimum_size = Vector2(54, 54)
	player_die_icon.pivot_offset = Vector2(27, 27)
	player_die_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_die_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_die_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	player_die_icon.tooltip_text = "Your Active Pulse Roll! Click to inspect Dice Bag (B)"
	player_die_icon.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_backpack()
	)
	rc_hbox.add_child(player_die_icon)

	var die_vbox = VBoxContainer.new()
	die_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rc_hbox.add_child(die_vbox)

	player_die_title = Label.new()
	player_die_title.text = "⚔️ 4 DMG"
	player_die_title.add_theme_font_size_override("font_size", 19)
	player_die_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	die_vbox.add_child(player_die_title)

	player_die_desc = Label.new()
	player_die_desc.text = "SLASH • [L-Click]"
	player_die_desc.add_theme_font_size_override("font_size", 11)
	player_die_desc.add_theme_color_override("font_color", Color(0.38, 0.78, 0.95))
	die_vbox.add_child(player_die_desc)
	
	# Center: Pulse Timer & Phase
	var pulse_center_vbox = VBoxContainer.new()
	pulse_center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse_center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pulse_center_vbox.add_theme_constant_override("separation", 3)
	combat_main_hbox.add_child(pulse_center_vbox)
	
	var pulse_head_hbox = HBoxContainer.new()
	pulse_center_vbox.add_child(pulse_head_hbox)
	
	phase_title = Label.new()
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_font_size_override("font_size", 15)
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	pulse_head_hbox.add_child(phase_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse_head_hbox.add_child(spacer)
	
	timer_label = Label.new()
	timer_label.text = "3.0s"
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color(0.98, 0.75, 0.18))
	pulse_head_hbox.add_child(timer_label)
	
	timer_bar = ProgressBar.new()
	timer_bar.min_value = 0.0
	timer_bar.max_value = PLANNING_TIME
	timer_bar.value = PLANNING_TIME
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 6)
	var timer_fill = StyleBoxFlat.new()
	timer_fill.bg_color = Color(0.2, 0.8, 0.4)
	timer_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	pulse_center_vbox.add_child(timer_bar)
	
	var stance_hbox = HBoxContainer.new()
	stance_hbox.add_theme_constant_override("separation", 6)
	pulse_center_vbox.add_child(stance_hbox)

	stance_btn_1 = Button.new()
	stance_btn_1.text = "[1] 👟 Advance (Move ➔ Hit)"
	stance_btn_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stance_btn_1.custom_minimum_size = Vector2(0, 22)
	stance_btn_1.add_theme_font_size_override("font_size", 10)
	stance_btn_1.pressed.connect(func(): _set_action_order("move_first"))
	stance_hbox.add_child(stance_btn_1)

	stance_btn_2 = Button.new()
	stance_btn_2.text = "[2] ⚔️ Hit & Run (Hit ➔ Move)"
	stance_btn_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stance_btn_2.custom_minimum_size = Vector2(0, 22)
	stance_btn_2.add_theme_font_size_override("font_size", 10)
	stance_btn_2.pressed.connect(func(): _set_action_order("attack_first"))
	stance_hbox.add_child(stance_btn_2)
	
	# Right: Action Buttons Grouped into 2 Clean Rows
	var action_vbox = VBoxContainer.new()
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_vbox.add_theme_constant_override("separation", 3)
	combat_main_hbox.add_child(action_vbox)
	
	var btn_row_1 = HBoxContainer.new()
	btn_row_1.add_theme_constant_override("separation", 6)
	action_vbox.add_child(btn_row_1)
	
	commit_button = Button.new()
	commit_button.text = "⚡ COMMIT (SPACE)"
	commit_button.add_theme_font_size_override("font_size", 11)
	commit_button.pressed.connect(_on_commit_pressed)
	btn_row_1.add_child(commit_button)
	
	var bag_btn = Button.new()
	bag_btn.text = "🎒 Bag (B)"
	bag_btn.add_theme_font_size_override("font_size", 11)
	bag_btn.pressed.connect(_toggle_backpack)
	btn_row_1.add_child(bag_btn)
	
	telegraph_button = Button.new()
	telegraph_button.text = "👁️ Telegraphs: ON"
	telegraph_button.add_theme_font_size_override("font_size", 11)
	telegraph_button.pressed.connect(_on_toggle_telegraphs)
	btn_row_1.add_child(telegraph_button)

	var btn_row_2 = HBoxContainer.new()
	btn_row_2.add_theme_constant_override("separation", 6)
	action_vbox.add_child(btn_row_2)

	var c_audio_btn = Button.new()
	c_audio_btn.text = "🔊 Sound (V)"
	c_audio_btn.add_theme_font_size_override("font_size", 11)
	c_audio_btn.pressed.connect(_toggle_audio_settings)
	btn_row_2.add_child(c_audio_btn)

	combat_fs_btn = Button.new()
	combat_fs_btn.text = "⛶ Fullscreen" if not cur_fs else "⛶ Windowed"
	combat_fs_btn.add_theme_font_size_override("font_size", 11)
	combat_fs_btn.pressed.connect(toggle_fullscreen)
	btn_row_2.add_child(combat_fs_btn)
	
	restart_button = Button.new()
	restart_button.text = "🔄 Restart (R)"
	restart_button.add_theme_font_size_override("font_size", 11)
	restart_button.pressed.connect(_on_restart_pressed)
	btn_row_2.add_child(restart_button)

	# Bottom Status Sub-Row
	var status_hbox = HBoxContainer.new()
	combat_vbox.add_child(status_hbox)

	last_action_label = Label.new()
	last_action_label.text = "⚔️ Strike: None [L-Click]   •   🦶 Move: Hold [R-Click / WASD]"
	last_action_label.add_theme_font_size_override("font_size", 11)
	last_action_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	last_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(last_action_label)

	enemy_intel_label = Label.new()
	enemy_intel_label.text = "Monsters engaged"
	enemy_intel_label.add_theme_font_size_override("font_size", 11)
	enemy_intel_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	status_hbox.add_child(enemy_intel_label)
	
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
	backpack_modal.visible = false
	hud_root.add_child(backpack_modal)

	backpack_modal.anchor_left = 0.5
	backpack_modal.anchor_right = 0.5
	backpack_modal.anchor_top = 0.5
	backpack_modal.anchor_bottom = 0.5
	backpack_modal.offset_left = -520
	backpack_modal.offset_right = 520
	backpack_modal.offset_top = -285
	backpack_modal.offset_bottom = 285
	backpack_modal.custom_minimum_size = Vector2(1040, 570)
	backpack_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	backpack_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	b_style.border_color = Color(0.92, 0.65, 0.15)
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(10)
	b_style.content_margin_left = 18
	b_style.content_margin_right = 18
	b_style.content_margin_top = 12
	b_style.content_margin_bottom = 12
	backpack_modal.add_theme_stylebox_override("panel", b_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	backpack_modal.add_child(main_vbox)
	
	# Top Modal Header Row
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)
	
	var title = Label.new()
	title.text = "🏰 STRONGHOLD"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	header_hbox.add_child(title)
	
	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 6)
	header_hbox.add_child(nav_hbox)

	var hero_tab_btn = Button.new()
	hero_tab_btn.text = "🎒 Hero & Armory"
	hero_tab_btn.pressed.connect(func(): _switch_backpack_view("hero"))
	nav_hbox.add_child(hero_tab_btn)
	view_tab_buttons["hero"] = hero_tab_btn

	var smith_tab_btn = Button.new()
	smith_tab_btn.text = "🔨 Town Blacksmith"
	smith_tab_btn.pressed.connect(func(): _switch_backpack_view("blacksmith"))
	nav_hbox.add_child(smith_tab_btn)
	view_tab_buttons["blacksmith"] = smith_tab_btn

	var custom_tab_btn = Button.new()
	custom_tab_btn.text = "🎨 Character Creator"
	custom_tab_btn.pressed.connect(func(): _switch_backpack_view("custom"))
	nav_hbox.add_child(custom_tab_btn)
	view_tab_buttons["custom"] = custom_tab_btn

	var estate_tab_btn = Button.new()
	estate_tab_btn.text = "🏛️ Estate Manor"
	estate_tab_btn.pressed.connect(func(): _switch_backpack_view("estate"))
	nav_hbox.add_child(estate_tab_btn)
	view_tab_buttons["estate"] = estate_tab_btn
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)

	char_gold_label = Label.new()
	char_gold_label.text = "🪙 100 Gold"
	char_gold_label.add_theme_font_size_override("font_size", 13)
	char_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	header_hbox.add_child(char_gold_label)
	
	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(_toggle_backpack)
	header_hbox.add_child(close_btn)
	
	# Body: 2 Main Columns for Hero View
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)
	hero_view_container = body_hbox
	
	# =========================================================
	# LEFT PANE: PAPER DOLL & ATTRIBUTES (Width ~450px)
	# =========================================================
	var left_pane = PanelContainer.new()
	left_pane.custom_minimum_size = Vector2(425, 0)
	var lp_style = StyleBoxFlat.new()
	lp_style.bg_color = Color(0.09, 0.11, 0.17, 0.90)
	lp_style.border_color = Color(0.25, 0.35, 0.50)
	lp_style.set_border_width_all(1)
	lp_style.set_corner_radius_all(8)
	lp_style.content_margin_left = 12
	lp_style.content_margin_right = 12
	lp_style.content_margin_top = 10
	lp_style.content_margin_bottom = 10
	left_pane.add_theme_stylebox_override("panel", lp_style)
	body_hbox.add_child(left_pane)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_pane.add_child(left_vbox)
	
	# Profile Header
	var prof_hbox = HBoxContainer.new()
	prof_hbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(prof_hbox)
	
	var hero_portrait = TextureRect.new()
	hero_portrait.texture = load("res://assets/sprites/hero.svg")
	hero_portrait.custom_minimum_size = Vector2(42, 42)
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prof_hbox.add_child(hero_portrait)
	
	var prof_txt = VBoxContainer.new()
	prof_hbox.add_child(prof_txt)
	
	char_title_label = Label.new()
	char_title_label.text = "⚔️ SIR ROWAN - ABYSS PALADIN"
	char_title_label.add_theme_font_size_override("font_size", 15)
	char_title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	prof_txt.add_child(char_title_label)
	
	var prof_sub = Label.new()
	prof_sub.text = "Equippable Slots (Click equipped item to unequip)"
	prof_sub.add_theme_font_size_override("font_size", 11)
	prof_sub.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	prof_txt.add_child(prof_sub)
	
	# Level & EXP Progression Bar
	var level_panel = PanelContainer.new()
	var lvl_p_style = StyleBoxFlat.new()
	lvl_p_style.bg_color = Color(0.06, 0.09, 0.14, 0.95)
	lvl_p_style.border_color = Color(0.98, 0.82, 0.2)
	lvl_p_style.set_border_width_all(1)
	lvl_p_style.set_corner_radius_all(6)
	lvl_p_style.content_margin_left = 10
	lvl_p_style.content_margin_right = 10
	lvl_p_style.content_margin_top = 6
	lvl_p_style.content_margin_bottom = 6
	level_panel.add_theme_stylebox_override("panel", lvl_p_style)
	left_vbox.add_child(level_panel)

	var level_vbox = VBoxContainer.new()
	level_vbox.add_theme_constant_override("separation", 3)
	level_panel.add_child(level_vbox)

	var level_head_hbox = HBoxContainer.new()
	char_level_label = Label.new()
	char_level_label.text = "⭐ LEVEL 1 PALADIN"
	char_level_label.add_theme_font_size_override("font_size", 12)
	char_level_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	level_head_hbox.add_child(char_level_label)

	var lvl_spacer = Control.new()
	lvl_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_head_hbox.add_child(lvl_spacer)

	char_exp_label = Label.new()
	char_exp_label.text = "0 / 100 EXP"
	char_exp_label.add_theme_font_size_override("font_size", 10)
	char_exp_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	level_head_hbox.add_child(char_exp_label)
	level_vbox.add_child(level_head_hbox)

	char_exp_bar = ProgressBar.new()
	char_exp_bar.custom_minimum_size = Vector2(0, 8)
	char_exp_bar.show_percentage = false
	var exp_bg = StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.12, 0.15, 0.22)
	exp_bg.set_corner_radius_all(4)
	var exp_fill = StyleBoxFlat.new()
	exp_fill.bg_color = Color(0.2, 0.75, 0.95)
	exp_fill.set_corner_radius_all(4)
	char_exp_bar.add_theme_stylebox_override("background", exp_bg)
	char_exp_bar.add_theme_stylebox_override("fill", exp_fill)
	level_vbox.add_child(char_exp_bar)

	# Total Attributes & Core Stats Panel
	var stats_panel = PanelContainer.new()
	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sp_style.border_color = Color(0.2, 0.28, 0.4)
	sp_style.set_border_width_all(1)
	sp_style.set_corner_radius_all(6)
	sp_style.content_margin_left = 10
	sp_style.content_margin_right = 10
	sp_style.content_margin_top = 6
	sp_style.content_margin_bottom = 6
	stats_panel.add_theme_stylebox_override("panel", sp_style)
	left_vbox.add_child(stats_panel)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_vbox)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 16)
	stats_vbox.add_child(stats_hbox)
	
	char_hp_label = Label.new()
	char_hp_label.text = "❤️ HP: 35"
	char_hp_label.add_theme_font_size_override("font_size", 12)
	char_hp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
	stats_hbox.add_child(char_hp_label)
	
	char_armor_label = Label.new()
	char_armor_label.text = "🛡️ ARMOR: 0"
	char_armor_label.add_theme_font_size_override("font_size", 12)
	char_armor_label.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	stats_hbox.add_child(char_armor_label)
	
	char_dmg_label = Label.new()
	char_dmg_label.text = "⚔️ BONUS DMG: +0"
	char_dmg_label.add_theme_font_size_override("font_size", 12)
	char_dmg_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.2))
	stats_hbox.add_child(char_dmg_label)

	# Row 2: Core Attributes (STR, DEX, INT)
	var attrs_hbox = HBoxContainer.new()
	attrs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	attrs_hbox.add_theme_constant_override("separation", 14)
	stats_vbox.add_child(attrs_hbox)

	char_str_label = Label.new()
	char_str_label.text = "💪 STR: 10"
	char_str_label.add_theme_font_size_override("font_size", 11)
	char_str_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35))
	attrs_hbox.add_child(char_str_label)

	char_dex_label = Label.new()
	char_dex_label.text = "🏃 DEX: 10"
	char_dex_label.add_theme_font_size_override("font_size", 11)
	char_dex_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.55))
	attrs_hbox.add_child(char_dex_label)

	char_int_label = Label.new()
	char_int_label.text = "🧠 INT: 10"
	char_int_label.add_theme_font_size_override("font_size", 11)
	char_int_label.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	attrs_hbox.add_child(char_int_label)

	# Stat Points Allocation Row (Appears when unspent_stat_points > 0)
	char_stat_points_container = HBoxContainer.new()
	char_stat_points_container.alignment = BoxContainer.ALIGNMENT_CENTER
	char_stat_points_container.add_theme_constant_override("separation", 6)
	stats_vbox.add_child(char_stat_points_container)
	
	# Paper Doll Scroll Container (10 Slots Layout)
	var pd_scroll = ScrollContainer.new()
	pd_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pd_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(pd_scroll)
	
	char_paper_doll_container = VBoxContainer.new()
	char_paper_doll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_paper_doll_container.add_theme_constant_override("separation", 6)
	pd_scroll.add_child(char_paper_doll_container)
	
	# =========================================================
	# RIGHT PANE: COMBAT DIE RACK & INVENTORY STASH
	# =========================================================
	var right_pane = VBoxContainer.new()
	right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pane.add_theme_constant_override("separation", 8)
	body_hbox.add_child(right_pane)
	
	# Section 1: Active Equipped Weapon & Physical Dice Rack
	var active_sec_panel = PanelContainer.new()
	var act_style = StyleBoxFlat.new()
	act_style.bg_color = Color(0.10, 0.13, 0.19, 0.85)
	act_style.border_color = Color(0.2, 0.7, 0.95)
	act_style.set_border_width_all(1)
	act_style.set_corner_radius_all(6)
	act_style.content_margin_left = 12
	act_style.content_margin_right = 12
	act_style.content_margin_top = 6
	act_style.content_margin_bottom = 8
	active_sec_panel.add_theme_stylebox_override("panel", act_style)
	right_pane.add_child(active_sec_panel)
	
	var act_vbox = VBoxContainer.new()
	act_vbox.add_theme_constant_override("separation", 6)
	active_sec_panel.add_child(act_vbox)
	
	var act_header_hbox = HBoxContainer.new()
	act_vbox.add_child(act_header_hbox)
	
	equipped_weapon_title = Label.new()
	equipped_weapon_title.text = "⚔️ MAIN HAND: RUSTY D6 SWORD"
	equipped_weapon_title.add_theme_font_size_override("font_size", 14)
	equipped_weapon_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.98))
	act_header_hbox.add_child(equipped_weapon_title)
	
	var eq_spacer = Control.new()
	eq_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_header_hbox.add_child(eq_spacer)
	
	equipped_weapon_stats = Label.new()
	equipped_weapon_stats.text = "Mean DMG: 4.0 | Faces: 6"
	equipped_weapon_stats.add_theme_font_size_override("font_size", 12)
	equipped_weapon_stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	act_header_hbox.add_child(equipped_weapon_stats)
	
	# The 6-Face Visual Rack
	dice_rack_container = HBoxContainer.new()
	dice_rack_container.add_theme_constant_override("separation", 6)
	act_vbox.add_child(dice_rack_container)

	# Active Weapon Chassis Trait Banner
	active_weapon_trait_label = Label.new()
	active_weapon_trait_label.text = "⚡ CHASSIS TRAIT: Standard (No trait)"
	active_weapon_trait_label.add_theme_font_size_override("font_size", 11)
	active_weapon_trait_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	act_vbox.add_child(active_weapon_trait_label)
	
	# Section 2: Stash & Armory Filter Tabs
	var stash_header_hbox = HBoxContainer.new()
	stash_header_hbox.add_theme_constant_override("separation", 6)
	right_pane.add_child(stash_header_hbox)
	
	var stash_lbl = Label.new()
	stash_lbl.text = "📦 STASH:"
	stash_lbl.add_theme_font_size_override("font_size", 13)
	stash_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	stash_header_hbox.add_child(stash_lbl)
	
	filter_tab_buttons.clear()
	var tabs = ["All", "Faces", "Weapons", "Off-Hand", "Armor", "Jewelry", "Trophies"]
	for tab_name in tabs:
		var tab_btn = Button.new()
		tab_btn.text = tab_name
		tab_btn.pressed.connect(func():
			selected_inventory_tab = tab_name
			_update_tab_button_styles()
			_render_backpack_inventory_cards()
		)
		stash_header_hbox.add_child(tab_btn)
		filter_tab_buttons[tab_name] = tab_btn
		
	var stash_spacer = Control.new()
	stash_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_header_hbox.add_child(stash_spacer)
	
	var click_hint = Label.new()
	click_hint.text = "[Socket Faces or Equip Items]"
	click_hint.add_theme_font_size_override("font_size", 11)
	click_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	stash_header_hbox.add_child(click_hint)
	
	# Socket Selection Prompt Bar (Appears when Socketing a loose face)
	socket_prompt_bar = PanelContainer.new()
	var sock_style = StyleBoxFlat.new()
	sock_style.bg_color = Color(0.10, 0.14, 0.22, 0.98)
	sock_style.border_color = Color(0.98, 0.82, 0.2)
	sock_style.set_border_width_all(2)
	sock_style.set_corner_radius_all(6)
	sock_style.content_margin_left = 10
	sock_style.content_margin_right = 10
	sock_style.content_margin_top = 6
	sock_style.content_margin_bottom = 6
	socket_prompt_bar.add_theme_stylebox_override("panel", sock_style)
	socket_prompt_bar.visible = false
	right_pane.add_child(socket_prompt_bar)

	# Stash Cards & Diablo Grid Area
	var stash_body_hbox = HBoxContainer.new()
	stash_body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_body_hbox.add_theme_constant_override("separation", 12)
	right_pane.add_child(stash_body_hbox)

	inventory_scroll = ScrollContainer.new()
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.custom_minimum_size = Vector2(300, 190)
	stash_body_hbox.add_child(inventory_scroll)
	
	inventory_stash_container = GridContainer.new()
	inventory_stash_container.columns = 6
	inventory_stash_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_stash_container.add_theme_constant_override("h_separation", 6)
	inventory_stash_container.add_theme_constant_override("v_separation", 6)
	inventory_scroll.add_child(inventory_stash_container)

	# Diablo-style Detailed Inspector Tooltip Panel
	item_tooltip_panel = PanelContainer.new()
	item_tooltip_panel.custom_minimum_size = Vector2(240, 190)
	item_tooltip_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tt_style = StyleBoxFlat.new()
	tt_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	tt_style.border_color = Color(0.98, 0.82, 0.2)
	tt_style.set_border_width_all(1.5)
	tt_style.set_corner_radius_all(6)
	tt_style.content_margin_left = 10
	tt_style.content_margin_right = 10
	tt_style.content_margin_top = 8
	tt_style.content_margin_bottom = 8
	item_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	stash_body_hbox.add_child(item_tooltip_panel)

	var tt_vbox = VBoxContainer.new()
	tt_vbox.add_theme_constant_override("separation", 4)
	item_tooltip_panel.add_child(tt_vbox)

	item_tooltip_title = Label.new()
	item_tooltip_title.text = "ITEM INSPECTOR"
	item_tooltip_title.add_theme_font_size_override("font_size", 12)
	item_tooltip_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	tt_vbox.add_child(item_tooltip_title)

	item_tooltip_type = Label.new()
	item_tooltip_type.text = "Hover an item to inspect"
	item_tooltip_type.add_theme_font_size_override("font_size", 10)
	item_tooltip_type.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	tt_vbox.add_child(item_tooltip_type)

	var tt_sep1 = HSeparator.new()
	tt_vbox.add_child(tt_sep1)

	item_tooltip_stats = Label.new()
	item_tooltip_stats.text = ""
	item_tooltip_stats.add_theme_font_size_override("font_size", 10)
	item_tooltip_stats.add_theme_color_override("font_color", Color(0.3, 0.9, 0.45))
	tt_vbox.add_child(item_tooltip_stats)

	item_tooltip_desc = Label.new()
	item_tooltip_desc.text = "Move your mouse over grid squares to view attributes, socket dice, or equip items."
	item_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_tooltip_desc.add_theme_font_size_override("font_size", 10)
	item_tooltip_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	item_tooltip_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tt_vbox.add_child(item_tooltip_desc)

	var tt_sep2 = HSeparator.new()
	tt_vbox.add_child(tt_sep2)

	var tt_bottom_hbox = HBoxContainer.new()
	tt_vbox.add_child(tt_bottom_hbox)

	item_tooltip_value = Label.new()
	item_tooltip_value.text = ""
	item_tooltip_value.add_theme_font_size_override("font_size", 10)
	item_tooltip_value.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	tt_bottom_hbox.add_child(item_tooltip_value)

	var b_spacer = Control.new()
	b_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tt_bottom_hbox.add_child(b_spacer)

	item_tooltip_actions = Label.new()
	item_tooltip_actions.text = ""
	item_tooltip_actions.add_theme_font_size_override("font_size", 9)
	item_tooltip_actions.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	tt_bottom_hbox.add_child(item_tooltip_actions)
	
	# Legacy container references
	backpack_items_container = VBoxContainer.new()
	backpack_items_container.visible = false
	main_vbox.add_child(backpack_items_container)
	relics_container = HBoxContainer.new()
	relics_container.visible = false
	main_vbox.add_child(relics_container)

	blacksmith_view_container = VBoxContainer.new()
	blacksmith_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blacksmith_view_container.visible = false
	main_vbox.add_child(blacksmith_view_container)

	char_custom_view_container = VBoxContainer.new()
	char_custom_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	char_custom_view_container.visible = false
	main_vbox.add_child(char_custom_view_container)
	_setup_character_customization_view()
	
	estate_view_container = VBoxContainer.new()
	estate_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	estate_view_container.visible = false
	main_vbox.add_child(estate_view_container)

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

func play_gold_sfx() -> void:
	if sfx_loot_pickup:
		play_sfx(sfx_loot_pickup, randf_range(1.35, 1.48), 2.5)

func play_smith_hammer_sfx() -> void:
	if sfx_hammer_slam:
		play_sfx(sfx_hammer_slam, randf_range(1.10, 1.22), 3.0)

func get_estate_gold_mult() -> float:
	var mult = 1.0
	for t in estate_trophy_slots:
		if t is ItemData and t.estate_perk_id == "gold_find":
			mult += 0.25
	return mult

func get_estate_armor_bonus() -> int:
	var b = 0
	for t in estate_trophy_slots:
		if t is ItemData and t.estate_perk_id == "estate_armor":
			b += 2
	return b

func get_estate_crit_bonus() -> float:
	var b = 0.0
	for t in estate_trophy_slots:
		if t is ItemData and t.estate_perk_id == "estate_crit":
			b += 0.05
	return b

func get_estate_hp_bonus() -> int:
	var b = 0
	for t in estate_trophy_slots:
		if t is ItemData and t.estate_perk_id == "estate_hp":
			b += 15
	return b

func get_estate_dmg_bonus() -> int:
	var b = 0
	for t in estate_trophy_slots:
		if t is ItemData and t.estate_perk_id == "estate_dmg":
			b += 2
	return b

func _update_gold_ui() -> void:
	if not player:
		return
	if is_instance_valid(char_gold_label):
		char_gold_label.text = "🪙 %d Gold" % player.gold
	if is_instance_valid(exp_gold_label):
		exp_gold_label.text = "🪙 %d Gold" % player.gold

func _generate_blacksmith_wares() -> void:
	blacksmith_face_wares.clear()
	blacksmith_weapon_wares.clear()
	
	for i in range(3):
		var face = DieData.generate_random_face(2 + i)
		var it = ItemData.create_face_item(face)
		it.gold_value = 35 + i * 25
		blacksmith_face_wares.append(it)
		
	for i in range(2):
		var wp = ItemData.generate_random_weapon(2 + i)
		wp.gold_value = 110 + i * 40
		blacksmith_weapon_wares.append(wp)

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
		_update_gold_ui()
		_switch_backpack_view(current_backpack_view)

func _render_backpack_ui() -> void:
	if not player:
		return
	_update_gold_ui()
		
	# 1. Update Hero stats & Attributes
	if is_instance_valid(char_level_label):
		char_level_label.text = "⭐ LEVEL %d PALADIN" % player.level
	if is_instance_valid(char_exp_bar):
		char_exp_bar.max_value = player.exp_to_level
		char_exp_bar.value = player.current_exp
	if is_instance_valid(char_exp_label):
		char_exp_label.text = "%d / %d EXP" % [player.current_exp, player.exp_to_level]

	char_hp_label.text = "❤️ HP: %d / %d" % [player.current_hp, player.max_hp]
	char_armor_label.text = "🛡️ ARMOR: %d" % player.armor
	char_dmg_label.text = "⚔️ BONUS DMG: +%d" % player.dmg_bonus

	if is_instance_valid(char_str_label):
		var str_txt = "💪 STR: %d" % player.get_total_str()
		if player.bonus_str > 0:
			str_txt += " (%d+%d)" % [player.stat_str, player.bonus_str]
		char_str_label.text = str_txt

	if is_instance_valid(char_dex_label):
		var tot_crit = (player.get_crit_chance() + get_estate_crit_bonus()) * 100.0
		var dex_txt = "🏃 DEX: %d (Crit: %.1f%%)" % [player.get_total_dex(), tot_crit]
		if player.bonus_dex > 0:
			dex_txt = "🏃 DEX: %d (%d+%d) • Crit: %.1f%%" % [player.get_total_dex(), player.stat_dex, player.bonus_dex, tot_crit]
		char_dex_label.text = dex_txt

	if is_instance_valid(char_int_label):
		var int_txt = "🧠 INT: %d" % player.get_total_int()
		if player.bonus_int > 0:
			int_txt += " (%d+%d)" % [player.stat_int, player.bonus_int]
		char_int_label.text = int_txt

	# Render Stat Point Allocation Buttons if unspent points available
	if is_instance_valid(char_stat_points_container):
		for c in char_stat_points_container.get_children():
			char_stat_points_container.remove_child(c)
			c.queue_free()

		if player.unspent_stat_points > 0:
			var pt_lbl = Label.new()
			pt_lbl.text = "⭐ %d Point%s:" % [player.unspent_stat_points, "s" if player.unspent_stat_points > 1 else ""]
			pt_lbl.add_theme_font_size_override("font_size", 10)
			pt_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
			char_stat_points_container.add_child(pt_lbl)

			var str_btn = Button.new()
			str_btn.text = "+ STR"
			str_btn.add_theme_font_size_override("font_size", 10)
			str_btn.pressed.connect(func():
				if player.unspent_stat_points > 0:
					player.stat_str += 1
					player.unspent_stat_points -= 1
					_recalculate_equipped_stats()
					_render_backpack_ui()
			)
			char_stat_points_container.add_child(str_btn)

			var dex_btn = Button.new()
			dex_btn.text = "+ DEX"
			dex_btn.add_theme_font_size_override("font_size", 10)
			dex_btn.pressed.connect(func():
				if player.unspent_stat_points > 0:
					player.stat_dex += 1
					player.unspent_stat_points -= 1
					_recalculate_equipped_stats()
					_render_backpack_ui()
			)
			char_stat_points_container.add_child(dex_btn)

			var int_btn = Button.new()
			int_btn.text = "+ INT"
			int_btn.add_theme_font_size_override("font_size", 10)
			int_btn.pressed.connect(func():
				if player.unspent_stat_points > 0:
					player.stat_int += 1
					player.unspent_stat_points -= 1
					_recalculate_equipped_stats()
					_render_backpack_ui()
			)
			char_stat_points_container.add_child(int_btn)
	
	# 2. Render Paper Doll (10 Slots Layout)
	_render_paper_doll_slots()
	
	# 3. Render Active Weapon Dice Rack
	_render_active_weapon_dice_rack()
	
	# 4. Render Stash Cards
	_update_tab_button_styles()
	_render_backpack_inventory_cards()

func _render_paper_doll_slots() -> void:
	for child in char_paper_doll_container.get_children():
		char_paper_doll_container.remove_child(child)
		child.queue_free()
		
	# Row 1: Helmet & Necklace
	var r1 = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	r1.add_child(_create_slot_card("helmet"))
	r1.add_child(_create_slot_card("necklace"))
	char_paper_doll_container.add_child(r1)
	
	# Row 2: Hand 1 (Main Hand) & Chestplate & Hand 2 (Off Hand)
	var r2 = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	r2.add_child(_create_slot_card("hand_1"))
	r2.add_child(_create_slot_card("chestplate"))
	r2.add_child(_create_slot_card("hand_2"))
	char_paper_doll_container.add_child(r2)
	
	# Row 3: Gloves & Pants
	var r3 = HBoxContainer.new()
	r3.add_theme_constant_override("separation", 8)
	r3.add_child(_create_slot_card("gloves"))
	r3.add_child(_create_slot_card("pants"))
	char_paper_doll_container.add_child(r3)
	
	# Row 4: Ring 1 & Ring 2
	var r4 = HBoxContainer.new()
	r4.add_theme_constant_override("separation", 8)
	r4.add_child(_create_slot_card("ring_1"))
	r4.add_child(_create_slot_card("ring_2"))
	char_paper_doll_container.add_child(r4)
	
	# Row 5: Boots
	var r5 = HBoxContainer.new()
	r5.add_theme_constant_override("separation", 8)
	r5.add_child(_create_slot_card("boots"))
	char_paper_doll_container.add_child(r5)

func _create_slot_card(slot_name: String) -> Control:
	var item: ItemData = equipped_gear.get(slot_name, null)
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	var is_hand_2_blocked = (slot_name == "hand_2" and main_w != null and main_w.hands == 2)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var c_style = StyleBoxFlat.new()
	c_style.set_corner_radius_all(6)
	c_style.content_margin_left = 6
	c_style.content_margin_right = 6
	c_style.content_margin_top = 4
	c_style.content_margin_bottom = 4
	
	if is_hand_2_blocked:
		c_style.bg_color = Color(0.24, 0.08, 0.08, 0.90)
		c_style.border_color = Color(0.92, 0.28, 0.28)
		c_style.set_border_width_all(1)
	elif item != null:
		c_style.bg_color = Color(0.11, 0.15, 0.22, 0.90)
		c_style.border_color = Color(0.35, 0.82, 0.50)
		c_style.set_border_width_all(1)
	else:
		c_style.bg_color = Color(0.06, 0.08, 0.12, 0.80)
		c_style.border_color = Color(0.20, 0.25, 0.35)
		c_style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", c_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if is_hand_2_blocked:
		icon.texture = load("res://assets/items/slot_hand_2.svg")
		icon.modulate = Color(1.0, 0.35, 0.35, 0.8)
	elif item != null:
		icon.texture = load(item.icon_path)
		icon.modulate = Color.WHITE
	else:
		icon.texture = load(ItemData.get_slot_silhouette(slot_name))
		icon.modulate = Color(1.0, 1.0, 1.0, 0.45)
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = ItemData.get_slot_title(slot_name).to_upper()
	title_lbl.add_theme_font_size_override("font_size", 9)
	title_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.95))
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(title_lbl)
	
	var name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_hand_2_blocked:
		name_lbl.text = "🔒 2H BLOCKED"
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	elif item != null:
		name_lbl.text = item.name
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	else:
		name_lbl.text = "Empty Slot"
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	vbox.add_child(name_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_hand_2_blocked:
		sub_lbl.text = "Two-Handed Lock"
		sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	elif item != null:
		sub_lbl.text = item.get_stat_summary()
		sub_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
	else:
		sub_lbl.text = "Click to equip"
		sub_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	vbox.add_child(sub_lbl)
	
	if item != null:
		var unequip_btn = Button.new()
		unequip_btn.text = "✕"
		unequip_btn.tooltip_text = "Unequip %s to stash" % item.name
		unequip_btn.pressed.connect(func(): _unequip_item_from_slot(slot_name))
		hbox.add_child(unequip_btn)
		
	return card

func _render_active_weapon_dice_rack() -> void:
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	var weapon_name = main_w.name if main_w != null else (player.die.name if player.die else "Unarmed")
	var hand_tag = ("2-HANDED" if (main_w and main_w.hands == 2) else "1-HANDED") if main_w != null else "1-HANDED"
	
	equipped_weapon_title.text = "⚔️ MAIN HAND: %s (%s)" % [weapon_name.to_upper(), hand_tag]
	if is_instance_valid(active_weapon_trait_label):
		if main_w != null and main_w.trait_name != "":
			active_weapon_trait_label.text = "⚡ CHASSIS TRAIT: %s (%s)" % [main_w.trait_name, main_w.trait_desc]
			active_weapon_trait_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
		else:
			active_weapon_trait_label.text = "⚡ CHASSIS TRAIT: Standard Adventurer Frame (No innate traits)"
			active_weapon_trait_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))

	if player and player.die:
		equipped_weapon_stats.text = "Faces: %d  |  Avg DMG: %.1f  |  Loaded Face: %s (%d DMG)" % [
			player.die.faces.size(),
			player.die.get_average_damage(),
			player.loaded_face.get("title", "NONE"),
			player.loaded_face.get("damage", 0)
		]
	
	for child in dice_rack_container.get_children():
		dice_rack_container.remove_child(child)
		child.queue_free()
		
	if not player or not player.die:
		return
		
	for i in range(player.die.faces.size()):
		var face = player.die.faces[i]
		var is_loaded = (face.get("title") == player.loaded_face.get("title") and face.get("damage") == player.loaded_face.get("damage") and face.get("roll") == player.loaded_face.get("roll"))
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 118)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var c_style = StyleBoxFlat.new()
		c_style.set_corner_radius_all(6)
		c_style.content_margin_left = 4
		c_style.content_margin_right = 4
		c_style.content_margin_top = 4
		c_style.content_margin_bottom = 4
		
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
		cvbox.add_theme_constant_override("separation", 2)
		card.add_child(cvbox)
		
		var roll_lbl = Label.new()
		roll_lbl.text = "FACE %d" % face.get("roll", i + 1)
		roll_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roll_lbl.add_theme_font_size_override("font_size", 10)
		roll_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2) if is_loaded else Color(0.38, 0.74, 0.97))
		cvbox.add_child(roll_lbl)
		
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(face.get("icon", "res://assets/ui/die_face_1.svg"))
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cvbox.add_child(icon_rect)
		
		var t_lbl = Label.new()
		t_lbl.text = face.get("title", "")
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 10)
		t_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		cvbox.add_child(t_lbl)
		
		var d_lbl = Label.new()
		var dmg = face.get("damage", 0)
		d_lbl.text = "%d DMG" % dmg if dmg > 0 else "0 DMG"
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4) if dmg > 0 else Color(0.6, 0.6, 0.6))
		cvbox.add_child(d_lbl)
		
		var ext_btn = Button.new()
		ext_btn.text = "Extract (25g)"
		ext_btn.add_theme_font_size_override("font_size", 9)
		ext_btn.tooltip_text = "Pay Town Blacksmith 25g to extract this face into Stash"
		var face_slot_i = i
		ext_btn.pressed.connect(func(): _extract_face_from_active_weapon(face_slot_i))
		cvbox.add_child(ext_btn)
		
		if is_loaded:
			var act_tag = Label.new()
			act_tag.text = "▶ READY"
			act_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			act_tag.add_theme_font_size_override("font_size", 9)
			act_tag.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
			cvbox.add_child(act_tag)

func _update_tab_button_styles() -> void:
	for tab_name in filter_tab_buttons.keys():
		var btn: Button = filter_tab_buttons[tab_name]
		if tab_name == selected_inventory_tab:
			btn.modulate = Color(1.2, 1.1, 0.4)
		else:
			btn.modulate = Color(0.85, 0.85, 0.9)

func _render_backpack_inventory_cards() -> void:
	for child in inventory_stash_container.get_children():
		inventory_stash_container.remove_child(child)
		child.queue_free()
		
	var filtered_items: Array[ItemData] = []
	for it in inventory_items:
		match selected_inventory_tab:
			"All":
				filtered_items.append(it)
			"Faces":
				if it.item_type == "face":
					filtered_items.append(it)
			"Weapons":
				if it.item_type == "weapon":
					filtered_items.append(it)
			"Off-Hand":
				if it.slot == "hand_2" or it.item_type in ["shield", "tome"]:
					filtered_items.append(it)
			"Armor":
				if it.item_type == "armor":
					filtered_items.append(it)
			"Jewelry":
				if it.item_type == "jewelry":
					filtered_items.append(it)
			"Trophies":
				if it.item_type == "trophy":
					filtered_items.append(it)
					
	if filtered_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items in category.\nSlay monsters & loot chests!"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		inventory_stash_container.add_child(empty_lbl)
		_show_item_tooltip(null)
		return
		
	# Reset tooltip to first item or selected item
	if selected_stash_item != null and filtered_items.has(selected_stash_item):
		_show_item_tooltip(selected_stash_item)
	else:
		_show_item_tooltip(filtered_items[0])

	for it in filtered_items:
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(50, 50)
		slot_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var b_style = StyleBoxFlat.new()
		b_style.set_corner_radius_all(6)
		b_style.content_margin_left = 4
		b_style.content_margin_right = 4
		b_style.content_margin_top = 4
		b_style.content_margin_bottom = 4

		if it == selected_stash_item:
			b_style.bg_color = Color(0.24, 0.19, 0.08, 0.95)
			b_style.border_color = Color(0.98, 0.82, 0.2)
			b_style.set_border_width_all(2)
		elif it.item_type == "face":
			b_style.bg_color = Color(0.12, 0.10, 0.20, 0.95)
			b_style.border_color = Color(0.98, 0.82, 0.2)
			b_style.set_border_width_all(1.5)
		elif it.item_type == "trophy":
			b_style.bg_color = Color(0.16, 0.08, 0.20, 0.90)
			b_style.border_color = Color(0.75, 0.35, 0.95)
			b_style.set_border_width_all(1)
		else:
			b_style.bg_color = Color(0.08, 0.10, 0.15, 0.85)
			b_style.border_color = Color(0.25, 0.35, 0.50)
			b_style.set_border_width_all(1)

		slot_btn.add_theme_stylebox_override("normal", b_style)
		slot_btn.add_theme_stylebox_override("hover", b_style)
		slot_btn.add_theme_stylebox_override("pressed", b_style)

		# Inner Icon - centered and properly fitted
		var icon = TextureRect.new()
		icon.texture = load(it.icon_path)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(icon)

		# Small bottom-right tag
		if it.hands == 2:
			var tag_lbl = Label.new()
			tag_lbl.text = "2H"
			tag_lbl.add_theme_font_size_override("font_size", 9)
			tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			tag_lbl.position = Vector2(28, 30)
			slot_btn.add_child(tag_lbl)
		elif it.item_type == "face":
			var dmg_val = it.face_data.get("damage", 1)
			var tag_panel = PanelContainer.new()
			var tp_style = StyleBoxFlat.new()
			tp_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
			tp_style.border_color = Color(0.98, 0.82, 0.2)
			tp_style.set_border_width_all(1)
			tp_style.set_corner_radius_all(3)
			tp_style.content_margin_left = 3
			tp_style.content_margin_right = 3
			tp_style.content_margin_top = 0
			tp_style.content_margin_bottom = 0
			tag_panel.add_theme_stylebox_override("panel", tp_style)
			tag_panel.position = Vector2(22, 28)
			tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var tag_lbl = Label.new()
			tag_lbl.text = "%d" % dmg_val
			tag_lbl.add_theme_font_size_override("font_size", 9)
			tag_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
			tag_panel.add_child(tag_lbl)
			slot_btn.add_child(tag_panel)

		var cur_item = it
		slot_btn.mouse_entered.connect(func():
			_show_item_tooltip(cur_item)
		)
		slot_btn.pressed.connect(func():
			selected_stash_item = cur_item
			_on_inventory_item_clicked(cur_item)
		)

		inventory_stash_container.add_child(slot_btn)

func _show_item_tooltip(item: ItemData) -> void:
	if not item_tooltip_panel:
		return
	if item == null:
		item_tooltip_title.text = "EMPTY SLOT"
		item_tooltip_type.text = "No item selected"
		item_tooltip_stats.text = ""
		item_tooltip_desc.text = "Hover over any item square in your grid stash to inspect its power."
		item_tooltip_value.text = ""
		item_tooltip_actions.text = ""
		return

	var tag = ""
	if item.hands == 2: tag = " (2-Handed)"
	elif item.hands == 1 and item.item_type == "weapon": tag = " (1-Handed)"
	elif item.item_type == "face": tag = " (Die Face)"
	elif item.item_type == "trophy": tag = " (Estate Trophy)"

	item_tooltip_title.text = item.name + tag
	if item.item_type == "face":
		item_tooltip_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.3))
	elif item.item_type == "trophy":
		item_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.65, 0.98))
	else:
		item_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))

	item_tooltip_type.text = "Slot: %s  •  Type: %s" % [ItemData.get_slot_title(item.slot), item.item_type.capitalize()]
	
	var stat_summary = item.get_stat_summary()
	if item.item_type == "weapon" and item.trait_name != "":
		stat_summary += "  •  Trait: " + item.trait_name
	item_tooltip_stats.text = stat_summary if stat_summary != "" else "No base stat requirements"

	var detailed_desc = item.desc
	if item.trait_desc != "":
		detailed_desc += "\nTrait: " + item.trait_desc
	if item.estate_perk_desc != "":
		detailed_desc += "\nEstate Perk: " + item.estate_perk_desc
	item_tooltip_desc.text = detailed_desc

	var s_val = item.get_sell_value()
	item_tooltip_value.text = "💰 Value: %d Gold" % s_val

	if item.item_type == "face":
		item_tooltip_actions.text = "[L-Click: Socket into Active Weapon]"
	elif item.item_type == "trophy":
		item_tooltip_actions.text = "[L-Click: Go to Manor to Mount]"
	else:
		item_tooltip_actions.text = "[L-Click: Equip to %s]" % ItemData.get_slot_title(item.slot)

func _on_inventory_item_clicked(item: ItemData) -> void:
	if item.item_type == "face":
		_prompt_socket_face(item)
	elif item.item_type == "trophy":
		_switch_backpack_view("estate")
	else:
		_equip_item_from_inventory(item)
		_show_item_tooltip(item)

func _prompt_socket_face(face_item: ItemData) -> void:
	if not socket_prompt_bar:
		return
	for c in socket_prompt_bar.get_children():
		socket_prompt_bar.remove_child(c)
		c.queue_free()
	
	socket_prompt_bar.visible = true
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	socket_prompt_bar.add_child(vbox)

	var head_hbox = HBoxContainer.new()
	var prompt_title = Label.new()
	prompt_title.text = "🔧 Choose which slot to overwrite with [%s] (Extracted face goes to stash):" % face_item.name
	prompt_title.add_theme_font_size_override("font_size", 12)
	prompt_title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.2))
	prompt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hbox.add_child(prompt_title)

	var cancel_btn = Button.new()
	cancel_btn.text = "✖ Cancel"
	cancel_btn.pressed.connect(func(): socket_prompt_bar.visible = false)
	head_hbox.add_child(cancel_btn)
	vbox.add_child(head_hbox)

	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(slots_hbox)

	if player and player.die and not player.die.faces.is_empty():
		for idx in range(mini(6, player.die.faces.size())):
			var cur_f = player.die.faces[idx]
			var s_btn = Button.new()
			s_btn.custom_minimum_size = Vector2(100, 38)
			s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var d_val = cur_f.get("damage", 1)
			var f_title = cur_f.get("title", "STRIKE")
			s_btn.text = "Slot %d\n%s (%d)" % [idx + 1, f_title, d_val]
			s_btn.pressed.connect(func(): _socket_face_into_slot(face_item, idx))
			slots_hbox.add_child(s_btn)

func _socket_face_into_slot(face_item: ItemData, slot_idx: int) -> void:
	if not player or not player.die or slot_idx < 0 or slot_idx >= player.die.faces.size():
		return
	var old_face: Dictionary = player.die.faces[slot_idx]
	var old_item = ItemData.create_face_item(old_face)
	inventory_items.append(old_item)

	var new_face: Dictionary = face_item.face_data.duplicate(true)
	new_face["roll"] = slot_idx + 1
	player.die.faces[slot_idx] = new_face

	inventory_items.erase(face_item)
	socket_prompt_bar.visible = false

	play_backpack_equip_sfx()
	play_dice_tumble_sfx()

	_log("[color=#22c55e]🔧 Socketed [b]%s[/b] into Slot %d! Extracted old face [b]%s[/b] into your Stash.[/color]" % [new_face.get("title", ""), slot_idx + 1, old_face.get("title", "")])
	_show_floating_text(player.position, "SOCKETED: Slot %d -> %s" % [slot_idx + 1, new_face.get("title", "")], Color(0.98, 0.82, 0.2))

	_sync_equipped_weapon_to_backpack()
	_render_backpack_ui()
	_update_hud_display()

func _equip_item_from_inventory(item: ItemData, target_slot: String = "") -> void:
	play_backpack_equip_sfx()
	var dest_slot = target_slot if target_slot != "" else item.slot
	
	# Hand 1 & Hand 2 (1H vs 2H mechanics)
	if dest_slot == "hand_1":
		if item.hands == 2:
			# 2-Handed weapon: occupies Hand 1 and frees Hand 2 back to inventory
			if equipped_gear["hand_2"] != null:
				var off_item: ItemData = equipped_gear["hand_2"]
				inventory_items.append(off_item)
				equipped_gear["hand_2"] = null
				_log("[color=#f59e0b]Equipped 2-Handed %s. Off-hand %s returned to stash.[/color]" % [item.name, off_item.name])
		# Swap current hand_1 item back to inventory
		if equipped_gear["hand_1"] != null:
			inventory_items.append(equipped_gear["hand_1"])
		equipped_gear["hand_1"] = item
		inventory_items.erase(item)
		_log("[color=#22c55e]Equipped %s in Main Hand![/color]" % item.name)

	elif dest_slot == "hand_2":
		# Off-Hand item (Shield, Tome, Parry Dagger)
		var main_w: ItemData = equipped_gear.get("hand_1", null)
		if main_w != null and main_w.hands == 2:
			# If holding a 2H weapon, return it to stash so player can wield offhand
			inventory_items.append(main_w)
			equipped_gear["hand_1"] = null
			_log("[color=#f59e0b]Unequipped 2-Handed %s to ready off-hand %s![/color]" % [main_w.name, item.name])
		if equipped_gear["hand_2"] != null:
			inventory_items.append(equipped_gear["hand_2"])
		equipped_gear["hand_2"] = item
		inventory_items.erase(item)
		_log("[color=#22c55e]Equipped %s in Off-Hand![/color]" % item.name)

	elif dest_slot in ["ring_1", "ring_2"]:
		var actual_slot = dest_slot
		if equipped_gear["ring_1"] == null:
			actual_slot = "ring_1"
		elif equipped_gear["ring_2"] == null:
			actual_slot = "ring_2"
		if equipped_gear[actual_slot] != null:
			inventory_items.append(equipped_gear[actual_slot])
		equipped_gear[actual_slot] = item
		inventory_items.erase(item)
		_log("[color=#22c55e]Equipped %s in %s![/color]" % [item.name, ItemData.get_slot_title(actual_slot)])

	else:
		# Standard armor / jewelry slot (helmet, necklace, chestplate, gloves, pants, boots)
		if equipped_gear[dest_slot] != null:
			inventory_items.append(equipped_gear[dest_slot])
		equipped_gear[dest_slot] = item
		inventory_items.erase(item)
		_log("[color=#22c55e]Equipped %s in %s slot![/color]" % [item.name, ItemData.get_slot_title(dest_slot)])

	_recalculate_gear_stats()
	_render_backpack_ui()

func _unequip_item_from_slot(slot_name: String) -> void:
	if not equipped_gear.has(slot_name) or equipped_gear[slot_name] == null:
		return
	play_backpack_equip_sfx()
	var it: ItemData = equipped_gear[slot_name]
	equipped_gear[slot_name] = null
	inventory_items.append(it)
	_log("[color=#94a3b8]Unequipped %s to stash.[/color]" % it.name)
	_recalculate_gear_stats()
	_render_backpack_ui()

func _recalculate_gear_stats() -> void:
	if not player or not is_instance_valid(player):
		return
	var gear_hp = 0
	var total_armor = 0
	var total_dmg = 0
	var total_str = 0
	var total_dex = 0
	var total_int = 0
	
	for slot_name in equipped_gear.keys():
		var it: ItemData = equipped_gear[slot_name]
		if it != null:
			gear_hp += it.hp_bonus
			total_armor += it.armor_bonus
			total_dmg += it.dmg_bonus
			total_str += it.str_bonus
			total_dex += it.dex_bonus
			total_int += it.int_bonus

	player.bonus_str = total_str
	player.bonus_dex = total_dex
	player.bonus_int = total_int

	var str_hp = maxi(0, player.get_total_str() - 10) * 5
	var old_max = player.max_hp
	var new_max = BASE_HP + (player.level - 1) * 5 + gear_hp + str_hp + get_estate_hp_bonus()
	var hp_delta = new_max - old_max
	
	player.max_hp = new_max
	if hp_delta > 0:
		player.current_hp = mini(player.max_hp, player.current_hp + hp_delta)
	else:
		player.current_hp = mini(player.max_hp, player.current_hp)
	
	player.armor = total_armor + get_estate_armor_bonus()
	player.dmg_bonus = total_dmg + player.get_stat_dmg_bonus() + get_estate_dmg_bonus()
	
	# Update active weapon in hand_1
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	if main_w != null and main_w.die != null:
		player.die = main_w.die.duplicate_die()
	else:
		player.die = DieData.create_default_d6_sword()
		
	if player.hp_bar:
		player.hp_bar.max_value = player.max_hp
		player.hp_bar.value = player.current_hp
	if exp_hp_bar:
		exp_hp_bar.max_value = player.max_hp
		exp_hp_bar.value = player.current_hp
		exp_hp_label.text = "❤️ %d / %d" % [player.current_hp, player.max_hp]
	if char_hp_label:
		char_hp_label.text = "❤️ HP: %d / %d" % [player.current_hp, player.max_hp]
	if char_armor_label:
		char_armor_label.text = "🛡️ ARMOR: %d" % player.armor
	if char_dmg_label:
		char_dmg_label.text = "⚔️ BONUS DMG: +%d" % player.dmg_bonus

	_update_hero_visual_gear()

func _update_hero_visual_gear() -> void:
	if not player or not is_instance_valid(player) or not player.hero_visual:
		return
	player.hero_visual.equipped_helmet = equipped_gear.get("helmet", null)
	player.hero_visual.equipped_chest = equipped_gear.get("chestplate", null)
	player.hero_visual.equipped_pants = equipped_gear.get("pants", null)
	player.hero_visual.equipped_boots = equipped_gear.get("boots", null)
	player.hero_visual.equipped_weapon = equipped_gear.get("hand_1", null)
	player.hero_visual.equipped_offhand = equipped_gear.get("hand_2", null)
	player.hero_visual.update_appearance()

func _recalculate_equipped_stats() -> void:
	_recalculate_gear_stats()

func _switch_backpack_view(view_name: String) -> void:
	current_backpack_view = view_name
	if is_instance_valid(hero_view_container):
		hero_view_container.visible = (view_name == "hero")
	if is_instance_valid(blacksmith_view_container):
		blacksmith_view_container.visible = (view_name == "blacksmith")
	if is_instance_valid(char_custom_view_container):
		char_custom_view_container.visible = (view_name == "custom")
	if is_instance_valid(estate_view_container):
		estate_view_container.visible = (view_name == "estate")

	for k in view_tab_buttons.keys():
		var btn: Button = view_tab_buttons[k]
		if is_instance_valid(btn):
			if k == view_name:
				btn.modulate = Color(1.2, 1.1, 0.3)
			else:
				btn.modulate = Color(0.8, 0.85, 0.9)

	match view_name:
		"hero":
			_render_backpack_ui()
		"blacksmith":
			_render_blacksmith_ui()
		"custom":
			_render_character_customization_ui()
		"estate":
			_render_estate_ui()

func _setup_character_customization_view() -> void:
	for c in char_custom_view_container.get_children():
		char_custom_view_container.remove_child(c)
		c.queue_free()

	var custom_panel = PanelContainer.new()
	var cp_style = StyleBoxFlat.new()
	cp_style.bg_color = Color(0.08, 0.10, 0.16, 0.95)
	cp_style.border_color = Color(0.98, 0.82, 0.2)
	cp_style.set_border_width_all(1)
	cp_style.set_corner_radius_all(8)
	cp_style.content_margin_left = 16
	cp_style.content_margin_right = 16
	cp_style.content_margin_top = 14
	cp_style.content_margin_bottom = 14
	custom_panel.add_theme_stylebox_override("panel", cp_style)
	char_custom_view_container.add_child(custom_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	custom_panel.add_child(hbox)

	# Left Column: Interactive Hero Live Preview (Enlarged)
	var preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(260, 360)
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color(0.04, 0.06, 0.10, 0.95)
	pp_style.border_color = Color(0.25, 0.35, 0.50)
	pp_style.set_border_width_all(1)
	pp_style.set_corner_radius_all(6)
	preview_panel.add_theme_stylebox_override("panel", pp_style)
	hbox.add_child(preview_panel)

	var pvbox = VBoxContainer.new()
	pvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pvbox.add_theme_constant_override("separation", 12)
	preview_panel.add_child(pvbox)

	var prev_title = Label.new()
	prev_title.text = "HERO MIRROR"
	prev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_title.add_theme_font_size_override("font_size", 13)
	prev_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	pvbox.add_child(prev_title)

	var prev_center = Control.new()
	prev_center.custom_minimum_size = Vector2(160, 200)
	pvbox.add_child(prev_center)

	custom_preview_visual = HeroVisual.new()
	custom_preview_visual.position = Vector2(80, 100)
	custom_preview_visual.scale = Vector2(2.6, 2.6)
	prev_center.add_child(custom_preview_visual)

	var prev_hint = Label.new()
	prev_hint.text = "Appearance instantly updates in the dungeon!"
	prev_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_hint.add_theme_font_size_override("font_size", 10)
	prev_hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
	pvbox.add_child(prev_hint)

	# Right Column: Controls for Gender, Faces, Hair, Cloak
	var controls_vbox = VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(controls_vbox)

	var head_lbl = Label.new()
	head_lbl.text = "🎨 CHARACTER CREATOR & BARBER"
	head_lbl.add_theme_font_size_override("font_size", 16)
	head_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	controls_vbox.add_child(head_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "Customize your champion's gender, battle-worn portrait face, hairstyles, and cloak style."
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	controls_vbox.add_child(sub_lbl)

	var sep = HSeparator.new()
	controls_vbox.add_child(sep)

	# 1. Gender Selection
	var gender_box = HBoxContainer.new()
	gender_box.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(gender_box)

	var g_lbl = Label.new()
	g_lbl.text = "Body Type / Gender:"
	g_lbl.custom_minimum_size = Vector2(140, 0)
	g_lbl.add_theme_font_size_override("font_size", 12)
	gender_box.add_child(g_lbl)

	var m_btn = Button.new()
	m_btn.text = "♂ Male Champion"
	m_btn.pressed.connect(func(): _set_character_gender("male"))
	gender_box.add_child(m_btn)

	var f_btn = Button.new()
	f_btn.text = "♀ Female Champion"
	f_btn.pressed.connect(func(): _set_character_gender("female"))
	gender_box.add_child(f_btn)

	# 2. Face Selection
	var face_box = HBoxContainer.new()
	face_box.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(face_box)

	var f_lbl = Label.new()
	f_lbl.text = "Portrait Face:"
	f_lbl.custom_minimum_size = Vector2(140, 0)
	f_lbl.add_theme_font_size_override("font_size", 12)
	face_box.add_child(f_lbl)

	for face_idx in [1, 2, 3]:
		var f_opt_btn = Button.new()
		f_opt_btn.text = "Face %d" % face_idx
		f_opt_btn.pressed.connect(func(): _set_character_face(face_idx))
		face_box.add_child(f_opt_btn)

	# 3. Hairstyle Selection
	var hair_box = HBoxContainer.new()
	hair_box.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(hair_box)

	var h_lbl = Label.new()
	h_lbl.text = "Hairstyle & Color:"
	h_lbl.custom_minimum_size = Vector2(140, 0)
	h_lbl.add_theme_font_size_override("font_size", 12)
	hair_box.add_child(h_lbl)

	var hair_opts = [
		{"id": "short_brown", "title": "Trimmed Brown"},
		{"id": "spiky_blonde", "title": "Spiky Blonde"},
		{"id": "long_black", "title": "Raven Locks"},
		{"id": "braid_red", "title": "Crimson Braid"},
		{"id": "none", "title": "Bald / Shaved"}
	]
	for h_opt in hair_opts:
		var h_btn = Button.new()
		h_btn.text = h_opt["title"]
		var h_id = h_opt["id"]
		h_btn.pressed.connect(func(): _set_character_hair(h_id))
		hair_box.add_child(h_btn)

	# 4. Cloak Selection
	var cloak_box = HBoxContainer.new()
	cloak_box.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(cloak_box)

	var clk_lbl = Label.new()
	clk_lbl.text = "Hero Cloak:"
	clk_lbl.custom_minimum_size = Vector2(140, 0)
	clk_lbl.add_theme_font_size_override("font_size", 12)
	cloak_box.add_child(clk_lbl)

	var cloak_opts = [
		{"id": "cloak_blue", "title": "Royal Blue"},
		{"id": "cloak_red", "title": "Crimson Velvet"},
		{"id": "none", "title": "No Cloak"}
	]
	for c_opt in cloak_opts:
		var c_btn = Button.new()
		c_btn.text = c_opt["title"]
		var c_id = c_opt["id"]
		c_btn.pressed.connect(func(): _set_character_cloak(c_id))
		cloak_box.add_child(c_btn)

	_sync_customization_preview()

func _set_character_gender(new_gender: String) -> void:
	custom_gender = new_gender
	if player and player.hero_visual:
		player.hero_visual.gender = custom_gender
	_sync_customization_preview()
	_update_hero_visual_gear()

func _set_character_face(new_face_id: int) -> void:
	custom_face = new_face_id
	if player and player.hero_visual:
		player.hero_visual.face_id = custom_face
	_sync_customization_preview()
	_update_hero_visual_gear()

func _set_character_hair(new_hair_id: String) -> void:
	custom_hair = new_hair_id
	if player and player.hero_visual:
		player.hero_visual.hair_id = custom_hair
	_sync_customization_preview()
	_update_hero_visual_gear()

func _set_character_cloak(new_cloak_id: String) -> void:
	custom_cloak = new_cloak_id
	if player and player.hero_visual:
		player.hero_visual.cloak_id = custom_cloak
	_sync_customization_preview()
	_update_hero_visual_gear()

func _sync_customization_preview() -> void:
	if not custom_preview_visual:
		return
	custom_preview_visual.gender = custom_gender
	custom_preview_visual.face_id = custom_face
	custom_preview_visual.hair_id = custom_hair
	custom_preview_visual.cloak_id = custom_cloak
	custom_preview_visual.equipped_helmet = equipped_gear.get("helmet", null)
	custom_preview_visual.equipped_chest = equipped_gear.get("chestplate", null)
	custom_preview_visual.equipped_pants = equipped_gear.get("pants", null)
	custom_preview_visual.equipped_boots = equipped_gear.get("boots", null)
	custom_preview_visual.equipped_weapon = equipped_gear.get("hand_1", null)
	custom_preview_visual.equipped_offhand = equipped_gear.get("hand_2", null)
	custom_preview_visual.update_appearance()

func _render_character_customization_ui() -> void:
	_sync_customization_preview()

func _extract_face_from_active_weapon(slot_idx: int) -> void:
	if not player or not player.die or slot_idx < 0 or slot_idx >= player.die.faces.size():
		return
	if not player.can_afford(25):
		_show_floating_text(player.position, "NOT ENOUGH GOLD (Need 25g)", Color(0.95, 0.4, 0.4))
		_log("[color=#ef4444]❌ Cannot extract face: you need 25 Gold (Current: %d)![/color]" % player.gold)
		return

	player.spend_gold(25)
	var face: Dictionary = player.die.faces[slot_idx]
	var loose_item = ItemData.create_face_item(face)
	inventory_items.append(loose_item)

	var blank_face: Dictionary = {
		"roll": slot_idx + 1,
		"damage": 1,
		"title": "BASIC STRIKE",
		"icon": "res://assets/ui/die_face_1.svg",
		"effect": ""
	}
	player.die.faces[slot_idx] = blank_face

	play_smith_hammer_sfx()
	_update_gold_ui()
	_sync_equipped_weapon_to_backpack()
	_log("[color=#22c55e]🔨 Blacksmith extracted [b]%s[/b] from Slot %d into your stash for 25g! (Remaining: %d Gold)[/color]" % [loose_item.name, slot_idx + 1, player.gold])
	_show_floating_text(player.position, "EXTRACTED: %s (-25g)" % loose_item.name, Color(0.38, 0.74, 0.97))
	
	if current_backpack_view == "hero":
		_render_backpack_ui()
	elif current_backpack_view == "blacksmith":
		_render_blacksmith_ui()
	_update_hud_display()

func _sell_inventory_item(item: ItemData) -> void:
	if not player:
		return
	var val = item.get_sell_value()
	inventory_items.erase(item)
	player.add_gold(val)
	play_gold_sfx()
	_log("[color=#eab308]💰 Sold [b]%s[/b] to Merchant for %d Gold (Total: %d Gold)![/color]" % [item.name, val, player.gold])
	_show_floating_text(player.position, "+%d Gold 🪙" % val, Color(1.0, 0.84, 0.0))
	_update_gold_ui()
	if current_backpack_view == "hero":
		_render_backpack_inventory_cards()
	elif current_backpack_view == "blacksmith":
		_render_blacksmith_ui()

func _render_blacksmith_ui() -> void:
	if not blacksmith_view_container or not player:
		return
	for c in blacksmith_view_container.get_children():
		blacksmith_view_container.remove_child(c)
		c.queue_free()

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	blacksmith_view_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# 1. Header Banner
	var head_panel = PanelContainer.new()
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	hp_style.border_color = Color(0.92, 0.55, 0.20)
	hp_style.set_border_width_all(1)
	hp_style.set_corner_radius_all(6)
	hp_style.content_margin_left = 12
	hp_style.content_margin_right = 12
	hp_style.content_margin_top = 8
	hp_style.content_margin_bottom = 8
	head_panel.add_theme_stylebox_override("panel", hp_style)
	vbox.add_child(head_panel)

	var hvbox = VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 4)
	head_panel.add_child(hvbox)

	var stitle = Label.new()
	stitle.text = "🔨 MASTER SMITH GARRICK'S FORGE & REFORGING ANVIL"
	stitle.add_theme_font_size_override("font_size", 16)
	stitle.add_theme_color_override("font_color", Color(0.98, 0.72, 0.22))
	hvbox.add_child(stitle)

	var sdesc = Label.new()
	sdesc.text = "Extract socketed faces safely into your inventory (25g), reforge weapon chassis traits (75g), hone blade edges (+1 DMG for 50g), or acquire forged stock!"
	sdesc.add_theme_font_size_override("font_size", 11)
	sdesc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	hvbox.add_child(sdesc)

	# 2. Active Weapon Station
	var forge_panel = PanelContainer.new()
	var fp_style = StyleBoxFlat.new()
	fp_style.bg_color = Color(0.08, 0.10, 0.15, 0.95)
	fp_style.border_color = Color(0.3, 0.45, 0.65)
	fp_style.set_border_width_all(1)
	fp_style.set_corner_radius_all(8)
	fp_style.content_margin_left = 14
	fp_style.content_margin_right = 14
	fp_style.content_margin_top = 10
	fp_style.content_margin_bottom = 10
	forge_panel.add_theme_stylebox_override("panel", fp_style)
	vbox.add_child(forge_panel)

	var fvbox = VBoxContainer.new()
	fvbox.add_theme_constant_override("separation", 10)
	forge_panel.add_child(fvbox)

	var cur_w: ItemData = equipped_gear.get("hand_1", null)
	var w_name = cur_w.name if cur_w else "Iron Starter Sword"
	var t_title = cur_w.trait_name if (cur_w and cur_w.trait_name != "") else "None (Unforged)"
	var t_desc = cur_w.trait_desc if (cur_w and cur_w.trait_desc != "") else "Visit Garrick to temper a chassis trait onto this base."

	var w_head_hbox = HBoxContainer.new()
	w_head_hbox.add_theme_constant_override("separation", 12)
	fvbox.add_child(w_head_hbox)

	var w_icon = TextureRect.new()
	w_icon.texture = load(cur_w.icon_path if cur_w else "res://assets/items/item_sword_starter.svg")
	w_icon.custom_minimum_size = Vector2(40, 40)
	w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w_head_hbox.add_child(w_icon)

	var w_info_vbox = VBoxContainer.new()
	w_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_head_hbox.add_child(w_info_vbox)

	var w_title_lbl = Label.new()
	w_title_lbl.text = "⚔️ Active Weapon: %s  |  Trait: %s" % [w_name, t_title]
	w_title_lbl.add_theme_font_size_override("font_size", 14)
	w_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	w_info_vbox.add_child(w_title_lbl)

	var w_desc_lbl = Label.new()
	w_desc_lbl.text = "Trait Effect: %s" % t_desc
	w_desc_lbl.add_theme_font_size_override("font_size", 11)
	w_desc_lbl.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
	w_info_vbox.add_child(w_desc_lbl)

	var forge_btn_hbox = HBoxContainer.new()
	forge_btn_hbox.add_theme_constant_override("separation", 8)
	w_head_hbox.add_child(forge_btn_hbox)

	var temper_btn = Button.new()
	temper_btn.text = "🔥 Temper Trait (75g)"
	temper_btn.tooltip_text = "Pay Garrick 75g to reforge or infuse a new passive trait onto your active weapon!"
	temper_btn.pressed.connect(_temper_active_weapon_trait)
	forge_btn_hbox.add_child(temper_btn)

	var hone_btn = Button.new()
	hone_btn.text = "⚔️ Hone Edge (+1 DMG) (50g)"
	hone_btn.tooltip_text = "Pay Garrick 50g to permanently sharpen this weapon (+1 flat damage bonus)!"
	hone_btn.pressed.connect(_hone_active_weapon)
	forge_btn_hbox.add_child(hone_btn)

	# 6 Sockets Extraction Rack
	var sock_lbl = Label.new()
	sock_lbl.text = "🔧 Weapon Sockets & Extraction Service (Click 'Extract' to unsocket any face into Stash for 25g):"
	sock_lbl.add_theme_font_size_override("font_size", 12)
	sock_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
	fvbox.add_child(sock_lbl)

	var sock_hbox = HBoxContainer.new()
	sock_hbox.add_theme_constant_override("separation", 8)
	fvbox.add_child(sock_hbox)

	if player and player.die:
		for i in range(mini(6, player.die.faces.size())):
			var face = player.die.faces[i]
			var scard = PanelContainer.new()
			scard.custom_minimum_size = Vector2(130, 110)
			scard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sc_style = StyleBoxFlat.new()
			sc_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
			sc_style.border_color = Color(0.25, 0.35, 0.5)
			sc_style.set_border_width_all(1)
			sc_style.set_corner_radius_all(6)
			sc_style.content_margin_left = 6
			sc_style.content_margin_right = 6
			sc_style.content_margin_top = 4
			sc_style.content_margin_bottom = 4
			scard.add_theme_stylebox_override("panel", sc_style)
			sock_hbox.add_child(scard)

			var scvbox = VBoxContainer.new()
			scvbox.alignment = BoxContainer.ALIGNMENT_CENTER
			scvbox.add_theme_constant_override("separation", 2)
			scard.add_child(scvbox)

			var s_num = Label.new()
			s_num.text = "SLOT %d" % (i + 1)
			s_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_num.add_theme_font_size_override("font_size", 10)
			s_num.add_theme_color_override("font_color", Color(0.38, 0.74, 0.97))
			scvbox.add_child(s_num)

			var s_icon = TextureRect.new()
			s_icon.texture = load(face.get("icon", "res://assets/ui/die_face_1.svg"))
			s_icon.custom_minimum_size = Vector2(28, 28)
			s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			scvbox.add_child(s_icon)

			var s_title = Label.new()
			s_title.text = face.get("title", "STRIKE")
			s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_title.add_theme_font_size_override("font_size", 10)
			s_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
			scvbox.add_child(s_title)

			var s_dmg = Label.new()
			s_dmg.text = "%d DMG" % face.get("damage", 1)
			s_dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_dmg.add_theme_font_size_override("font_size", 10)
			s_dmg.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
			scvbox.add_child(s_dmg)

			var ext_btn = Button.new()
			ext_btn.text = "Extract (25g)"
			ext_btn.add_theme_font_size_override("font_size", 9)
			var cur_slot_idx = i
			ext_btn.pressed.connect(func(): _extract_face_from_active_weapon(cur_slot_idx))
			scvbox.add_child(ext_btn)

	# 3. Blacksmith Store (Crafted Faces & Weapons)
	var store_head_hbox = HBoxContainer.new()
	vbox.add_child(store_head_hbox)

	var store_lbl = Label.new()
	store_lbl.text = "🛒 GARRICK'S FORGED INVENTORY"
	store_lbl.add_theme_font_size_override("font_size", 13)
	store_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.2))
	store_head_hbox.add_child(store_lbl)

	var s_spacer = Control.new()
	s_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_head_hbox.add_child(s_spacer)

	var restock_btn = Button.new()
	restock_btn.text = "🔄 Restock Stock (15g)"
	restock_btn.pressed.connect(func():
		if player and player.can_afford(15):
			player.spend_gold(15)
			play_smith_hammer_sfx()
			_generate_blacksmith_wares()
			_update_gold_ui()
			_render_blacksmith_ui()
			_log("[color=#eab308]🔄 Garrick refreshed his smithing wares for 15g![/color]")
		else:
			_show_floating_text(player.position, "NOT ENOUGH GOLD", Color(0.95, 0.4, 0.4))
	)
	store_head_hbox.add_child(restock_btn)

	var wares_hbox = HBoxContainer.new()
	wares_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(wares_hbox)

	for face_item in blacksmith_face_wares:
		var wcard = PanelContainer.new()
		wcard.custom_minimum_size = Vector2(150, 80)
		wcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var wc_style = StyleBoxFlat.new()
		wc_style.bg_color = Color(0.08, 0.10, 0.15, 0.9)
		wc_style.border_color = Color(0.98, 0.82, 0.2)
		wc_style.set_border_width_all(1)
		wc_style.set_corner_radius_all(6)
		wc_style.content_margin_left = 6
		wc_style.content_margin_right = 6
		wc_style.content_margin_top = 4
		wc_style.content_margin_bottom = 4
		wcard.add_theme_stylebox_override("panel", wc_style)
		wares_hbox.add_child(wcard)

		var wcvbox = VBoxContainer.new()
		wcvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		wcard.add_child(wcvbox)

		var w_name_l = Label.new()
		w_name_l.text = face_item.name
		w_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_name_l.add_theme_font_size_override("font_size", 11)
		w_name_l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		wcvbox.add_child(w_name_l)

		var eff_str = ("(" + face_item.face_data.get("effect", "") + ")") if face_item.face_data.get("effect", "") != "" else ""
		var w_stat_l = Label.new()
		w_stat_l.text = "%d DMG %s" % [face_item.dmg_bonus, eff_str]
		w_stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_stat_l.add_theme_font_size_override("font_size", 10)
		w_stat_l.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		wcvbox.add_child(w_stat_l)

		var buy_btn = Button.new()
		buy_btn.text = "Buy (%dg)" % face_item.gold_value
		var f_ref = face_item
		buy_btn.pressed.connect(func():
			if player and player.can_afford(f_ref.gold_value):
				player.spend_gold(f_ref.gold_value)
				blacksmith_face_wares.erase(f_ref)
				inventory_items.append(f_ref)
				play_gold_sfx()
				_log("[color=#22c55e]🛒 Purchased [b]%s[/b] for %d Gold![/color]" % [f_ref.name, f_ref.gold_value])
				_show_floating_text(player.position, "BOUGHT: %s" % f_ref.name, Color(0.38, 0.74, 0.97))
				_update_gold_ui()
				_render_blacksmith_ui()
			else:
				_show_floating_text(player.position, "NOT ENOUGH GOLD", Color(0.95, 0.4, 0.4))
		)
		wcvbox.add_child(buy_btn)

	for wp_item in blacksmith_weapon_wares:
		var wcard = PanelContainer.new()
		wcard.custom_minimum_size = Vector2(170, 80)
		wcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var wc_style = StyleBoxFlat.new()
		wc_style.bg_color = Color(0.08, 0.10, 0.15, 0.9)
		wc_style.border_color = Color(0.38, 0.74, 0.97)
		wc_style.set_border_width_all(1)
		wc_style.set_corner_radius_all(6)
		wc_style.content_margin_left = 6
		wc_style.content_margin_right = 6
		wc_style.content_margin_top = 4
		wc_style.content_margin_bottom = 4
		wcard.add_theme_stylebox_override("panel", wc_style)
		wares_hbox.add_child(wcard)

		var wcvbox = VBoxContainer.new()
		wcvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		wcard.add_child(wcvbox)

		var w_name_l = Label.new()
		w_name_l.text = wp_item.name
		w_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_name_l.add_theme_font_size_override("font_size", 11)
		w_name_l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		wcvbox.add_child(w_name_l)

		var w_stat_l = Label.new()
		w_stat_l.text = "Trait: %s" % wp_item.trait_name
		w_stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_stat_l.add_theme_font_size_override("font_size", 10)
		w_stat_l.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
		wcvbox.add_child(w_stat_l)

		var buy_btn = Button.new()
		buy_btn.text = "Buy (%dg)" % wp_item.gold_value
		var w_ref = wp_item
		buy_btn.pressed.connect(func():
			if player and player.can_afford(w_ref.gold_value):
				player.spend_gold(w_ref.gold_value)
				blacksmith_weapon_wares.erase(w_ref)
				inventory_items.append(w_ref)
				play_gold_sfx()
				_log("[color=#22c55e]🛒 Purchased [b]%s[/b] for %d Gold![/color]" % [w_ref.name, w_ref.gold_value])
				_show_floating_text(player.position, "BOUGHT: %s" % w_ref.name, Color(0.38, 0.74, 0.97))
				_update_gold_ui()
				_render_blacksmith_ui()
			else:
				_show_floating_text(player.position, "NOT ENOUGH GOLD", Color(0.95, 0.4, 0.4))
		)
		wcvbox.add_child(buy_btn)

func _temper_active_weapon_trait() -> void:
	if not player:
		return
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	if not main_w:
		_show_floating_text(player.position, "NO WEAPON EQUIPPED", Color(0.95, 0.4, 0.4))
		return
	if not player.can_afford(75):
		_show_floating_text(player.position, "NEED 75 GOLD", Color(0.95, 0.4, 0.4))
		_log("[color=#ef4444]❌ Cannot temper weapon: you need 75 Gold![/color]")
		return

	player.spend_gold(75)
	var available = ItemData.get_available_chassis_traits()
	var pick = available.pick_random()
	for _attempt in range(5):
		if pick["id"] != main_w.trait_id:
			break
		pick = available.pick_random()

	main_w.trait_id = pick["id"]
	main_w.trait_name = pick["name"]
	main_w.trait_desc = pick["desc"]

	play_smith_hammer_sfx()
	_update_gold_ui()
	_recalculate_equipped_stats()
	_log("[color=#22c55e]🔥 Garrick tempered [b]%s[/b] with new Trait: [b]%s[/b] (%s) for 75g![/color]" % [main_w.name, main_w.trait_name, main_w.trait_desc])
	_show_floating_text(player.position, "TEMPERED: %s" % main_w.trait_name, Color(0.98, 0.85, 0.2))
	_render_blacksmith_ui()

func _hone_active_weapon() -> void:
	if not player:
		return
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	if not main_w:
		_show_floating_text(player.position, "NO WEAPON EQUIPPED", Color(0.95, 0.4, 0.4))
		return
	if not player.can_afford(50):
		_show_floating_text(player.position, "NEED 50 GOLD", Color(0.95, 0.4, 0.4))
		_log("[color=#ef4444]❌ Cannot hone weapon: you need 50 Gold![/color]")
		return

	player.spend_gold(50)
	main_w.dmg_bonus += 1
	play_smith_hammer_sfx()
	_update_gold_ui()
	_recalculate_equipped_stats()
	_log("[color=#22c55e]⚔️ Garrick honed the edge of [b]%s[/b]! (+1 Bonus DMG, Total: +%d) for 50g![/color]" % [main_w.name, main_w.dmg_bonus])
	_show_floating_text(player.position, "+1 WEAPON DMG!", Color(0.2, 0.9, 0.4))
	_render_blacksmith_ui()

func _render_estate_ui() -> void:
	if not estate_view_container or not player:
		return
	for c in estate_view_container.get_children():
		estate_view_container.remove_child(c)
		c.queue_free()

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	estate_view_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# 1. Manor Header
	var m_head = PanelContainer.new()
	var mh_style = StyleBoxFlat.new()
	mh_style.bg_color = Color(0.08, 0.07, 0.14, 0.95)
	mh_style.border_color = Color(0.8, 0.6, 0.95)
	mh_style.set_border_width_all(1)
	mh_style.set_corner_radius_all(8)
	mh_style.content_margin_left = 14
	mh_style.content_margin_right = 14
	mh_style.content_margin_top = 8
	mh_style.content_margin_bottom = 8
	m_head.add_theme_stylebox_override("panel", mh_style)
	vbox.add_child(m_head)

	var mhvbox = VBoxContainer.new()
	mhvbox.add_theme_constant_override("separation", 4)
	m_head.add_child(mhvbox)

	var m_title = Label.new()
	m_title.text = "🏛️ RAVENLOFT MANOR - ESTATE TROPHY GALLERY"
	m_title.add_theme_font_size_override("font_size", 16)
	m_title.add_theme_color_override("font_color", Color(0.88, 0.75, 1.0))
	mhvbox.add_child(m_title)

	var m_desc = Label.new()
	m_desc.text = "Mount rare trophies recovered from the dungeon onto marble pedestals in your manor hall. Every mounted collectible activates passive Estate Perks for your hero!"
	m_desc.add_theme_font_size_override("font_size", 11)
	m_desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	mhvbox.add_child(m_desc)

	# 2. Active Perks Banner
	var perks_panel = PanelContainer.new()
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	pp_style.border_color = Color(0.35, 0.75, 0.95)
	pp_style.set_border_width_all(1)
	pp_style.set_corner_radius_all(6)
	pp_style.content_margin_left = 12
	pp_style.content_margin_right = 12
	pp_style.content_margin_top = 6
	pp_style.content_margin_bottom = 6
	perks_panel.add_theme_stylebox_override("panel", pp_style)
	vbox.add_child(perks_panel)

	var p_vbox = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 3)
	perks_panel.add_child(p_vbox)

	var p_title = Label.new()
	p_title.text = "✨ ACTIVE ESTATE PERKS"
	p_title.add_theme_font_size_override("font_size", 12)
	p_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
	p_vbox.add_child(p_title)

	var active_parts: Array[String] = []
	if get_estate_gold_mult() > 1.0:
		active_parts.append("🪙 Gold Find: +%.0f%%" % ((get_estate_gold_mult() - 1.0) * 100.0))
	if get_estate_armor_bonus() > 0:
		active_parts.append("🛡️ Armor: +%d" % get_estate_armor_bonus())
	if get_estate_crit_bonus() > 0.0:
		active_parts.append("⚡ Crit Chance: +%.0f%%" % (get_estate_crit_bonus() * 100.0))
	if get_estate_hp_bonus() > 0:
		active_parts.append("❤️ Max HP: +%d" % get_estate_hp_bonus())
	if get_estate_dmg_bonus() > 0:
		active_parts.append("⚔️ Flat DMG: +%d" % get_estate_dmg_bonus())

	var p_text = " • ".join(active_parts) if not active_parts.is_empty() else "No trophies currently placed. Mount trophies from your stash to activate estate perks!"
	var p_lbl = Label.new()
	p_lbl.text = p_text
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_lbl.add_theme_color_override("font_color", Color(0.38, 0.85, 0.55) if not active_parts.is_empty() else Color(0.65, 0.70, 0.80))
	p_vbox.add_child(p_lbl)

	# 3. Pedestals Grid (6 slots)
	var ped_grid = GridContainer.new()
	ped_grid.columns = 3
	ped_grid.add_theme_constant_override("h_separation", 14)
	ped_grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(ped_grid)

	for i in range(6):
		var p_card = PanelContainer.new()
		p_card.custom_minimum_size = Vector2(280, 130)
		p_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pc_style = StyleBoxFlat.new()
		pc_style.set_corner_radius_all(8)
		pc_style.set_border_width_all(1)
		pc_style.content_margin_left = 10
		pc_style.content_margin_right = 10
		pc_style.content_margin_top = 8
		pc_style.content_margin_bottom = 8

		var is_unlocked = (i < estate_pedestals_unlocked)
		var trophy: ItemData = estate_trophy_slots[i] if (i < estate_trophy_slots.size()) else null

		if not is_unlocked:
			pc_style.bg_color = Color(0.04, 0.05, 0.08, 0.8)
			pc_style.border_color = Color(0.2, 0.25, 0.35)
		elif trophy != null:
			pc_style.bg_color = Color(0.12, 0.10, 0.20, 0.95)
			pc_style.border_color = Color(0.92, 0.72, 0.25)
		else:
			pc_style.bg_color = Color(0.06, 0.08, 0.13, 0.9)
			pc_style.border_color = Color(0.3, 0.45, 0.6)
		p_card.add_theme_stylebox_override("panel", pc_style)
		ped_grid.add_child(p_card)

		var pcvbox = VBoxContainer.new()
		pcvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		pcvbox.add_theme_constant_override("separation", 4)
		p_card.add_child(pcvbox)

		if not is_unlocked:
			var unlock_cost = 150 if i == 4 else 300
			var lock_lbl = Label.new()
			lock_lbl.text = "🔒 PEDESTAL %d (LOCKED)" % (i + 1)
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_font_size_override("font_size", 12)
			lock_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
			pcvbox.add_child(lock_lbl)

			var lock_sub = Label.new()
			lock_sub.text = "Expand your estate gallery"
			lock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_sub.add_theme_font_size_override("font_size", 10)
			lock_sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
			pcvbox.add_child(lock_sub)

			var unlock_btn = Button.new()
			unlock_btn.text = "🔓 Unlock Pedestal (%dg)" % unlock_cost
			var cur_cost = unlock_cost
			unlock_btn.pressed.connect(func():
				if player and player.can_afford(cur_cost):
					player.spend_gold(cur_cost)
					estate_pedestals_unlocked += 1
					play_smith_hammer_sfx()
					_update_gold_ui()
					_log("[color=#22c55e]🏛️ Expanded Estate Gallery! Pedestal %d unlocked for %dg![/color]" % [estate_pedestals_unlocked, cur_cost])
					_show_floating_text(player.position, "PEDESTAL UNLOCKED!", Color(0.88, 0.75, 1.0))
					_render_estate_ui()
				else:
					_show_floating_text(player.position, "NOT ENOUGH GOLD", Color(0.95, 0.4, 0.4))
			)
			pcvbox.add_child(unlock_btn)
		elif trophy != null:
			var t_head_hbox = HBoxContainer.new()
			t_head_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			t_head_hbox.add_theme_constant_override("separation", 8)
			pcvbox.add_child(t_head_hbox)

			var t_icon = TextureRect.new()
			t_icon.texture = load(trophy.icon_path)
			t_icon.custom_minimum_size = Vector2(32, 32)
			t_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t_head_hbox.add_child(t_icon)

			var t_name_l = Label.new()
			t_name_l.text = trophy.name
			t_name_l.add_theme_font_size_override("font_size", 12)
			t_name_l.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
			t_head_hbox.add_child(t_name_l)

			var t_perk_l = Label.new()
			t_perk_l.text = "Perk: %s" % trophy.estate_perk_desc
			t_perk_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t_perk_l.add_theme_font_size_override("font_size", 10)
			t_perk_l.add_theme_color_override("font_color", Color(0.38, 0.85, 0.55))
			pcvbox.add_child(t_perk_l)

			var ret_btn = Button.new()
			ret_btn.text = "📦 Retrieve to Stash"
			var ped_idx = i
			ret_btn.pressed.connect(func():
				inventory_items.append(estate_trophy_slots[ped_idx])
				estate_trophy_slots[ped_idx] = null
				play_backpack_equip_sfx()
				_recalculate_equipped_stats()
				_log("[color=#38bdf8]📦 Retrieved [b]%s[/b] to your Stash.[/color]" % trophy.name)
				_render_estate_ui()
			)
			pcvbox.add_child(ret_btn)
		else:
			var empty_l = Label.new()
			empty_l.text = "PEDESTAL %d (EMPTY)" % (i + 1)
			empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_l.add_theme_font_size_override("font_size", 12)
			empty_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
			pcvbox.add_child(empty_l)

			var place_btn = Button.new()
			place_btn.text = "+ Mount Trophy"
			var ped_idx = i
			place_btn.pressed.connect(func(): _prompt_mount_trophy(ped_idx))
			pcvbox.add_child(place_btn)

func _prompt_mount_trophy(pedestal_idx: int) -> void:
	var trophies_in_stash: Array[ItemData] = []
	for it in inventory_items:
		if it.item_type == "trophy":
			trophies_in_stash.append(it)
	if trophies_in_stash.is_empty():
		_show_floating_text(player.position, "NO TROPHIES IN STASH", Color(0.95, 0.4, 0.4))
		_log("[color=#94a3b8]🏛️ No estate trophies found in stash. Slay bosses and open dungeon chests to uncover rare collectibles![/color]")
		return

	var chosen = trophies_in_stash[0]
	inventory_items.erase(chosen)
	estate_trophy_slots[pedestal_idx] = chosen
	play_gold_sfx()
	_recalculate_equipped_stats()
	_log("[color=#22c55e]🏛️ Mounted [b]%s[/b] onto Pedestal %d! Active Perk: [b]%s[/b][/color]" % [chosen.name, pedestal_idx + 1, chosen.estate_perk_desc])
	_show_floating_text(player.position, "MOUNTED: %s" % chosen.name, Color(0.88, 0.75, 1.0))
	_render_estate_ui()

func _equip_weapon_from_backpack(weapon: DieData) -> void:
	# Legacy adapter: find or create item and equip to hand_1
	var item: ItemData = null
	for it in inventory_items:
		if it.die and it.die.name == weapon.name:
			item = it
			break
	if item == null:
		item = ItemData.new()
		item.id = weapon.name.to_lower().replace(" ", "_")
		item.name = weapon.name
		item.slot = "hand_1"
		item.hands = 2 if weapon.name.contains("Warhammer") or weapon.name.contains("Executioner") else 1
		item.item_type = "weapon"
		item.icon_path = weapon.icon_path
		item.die = weapon.duplicate_die()
	_equip_item_from_inventory(item, "hand_1")
	_render_backpack_ui()
	_animate_hud_die_tumbler()
	_animate_overhead_hero_roll()
	_log("[color=#38bdf8]⚔️ Swapped equipped weapon to [b]%s[/b]! Loaded face: %s[/color]" % [player.die.name, player.loaded_face.get("title", "")])
	_show_floating_text(player.position, "EQUIPPED: %s" % player.die.name, Color(0.3, 0.8, 0.95))

func _add_weapon_to_backpack(weapon: DieData) -> void:
	for it in inventory_items:
		if it.die and it.die.name == weapon.name:
			return
	for w in backpack_weapons:
		if w.name == weapon.name:
			return
	backpack_weapons.append(weapon.duplicate_die())
	var item = ItemData.new()
	item.id = weapon.name.to_lower().replace(" ", "_")
	item.name = weapon.name
	item.slot = "hand_1"
	item.hands = 2 if weapon.name.contains("Warhammer") or weapon.name.contains("Executioner") else 1
	item.item_type = "weapon"
	item.icon_path = weapon.icon_path
	item.die = weapon.duplicate_die()
	inventory_items.append(item)
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
			if player.sprite is Sprite2D: player.sprite.flip_h = true
			elif player.sprite.has_method("set_flip_h"): player.sprite.set_flip_h(true)
		elif move_vec.x > 0.1 and player.sprite:
			if player.sprite is Sprite2D: player.sprite.flip_h = false
			elif player.sprite.has_method("set_flip_h"): player.sprite.set_flip_h(false)
			
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
				break

	# Check if player stepped into any unbreached hostile chamber (front, back, or side)
	for r in dungeon_rooms:
		var r_id = r["id"]
		if r_id > 0 and not breached_rooms.has(r_id):
			if r["rect"].has_point(player.grid_pos):
				_breach_chamber(r_id, player.grid_pos, false)
				break
				
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
			# Strict interior floor rectangle (strictly excluding perimeter walls and doors)
			var inner_rect = Rect2i(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, rect.size.y - 2)
			var diff = r["center"] - door_pos
			var step_dir = Vector2i.ZERO
			if abs(diff.x) > abs(diff.y):
				step_dir = Vector2i(1 if diff.x > 0 else -1, 0)
			else:
				step_dir = Vector2i(0, 1 if diff.y > 0 else -1)
			
			var candidate_2 = door_pos + step_dir * 2
			if inner_rect.has_point(candidate_2) and grid[candidate_2.y][candidate_2.x] == 0:
				return candidate_2
			var candidate_1 = door_pos + step_dir
			if inner_rect.has_point(candidate_1) and grid[candidate_1.y][candidate_1.x] == 0:
				return candidate_1
			return r["center"]
	return door_pos

func _open_door(door: Dictionary) -> void:
	_breach_chamber(door["room_id"], door["pos"], true)

func _breach_chamber(r_id: int, breach_origin: Vector2i, should_stride: bool = false) -> void:
	if r_id <= 0 or breached_rooms.has(r_id):
		return
	breached_rooms.append(r_id)
	current_combat_room_id = r_id
	play_door_creak_sfx()
	
	var total_hostile = maxi(1, dungeon_rooms.size() - 1)
	if is_instance_valid(exp_chambers_label):
		exp_chambers_label.text = "Chambers Breached: %d / %d  |  Move with [WASD]" % [breached_rooms.size(), total_hostile]
	
	var paired_open_textures = {
		"horizontal": {
			"left": load("res://assets/sprites/door_horiz_left_open.svg"),
			"right": load("res://assets/sprites/door_horiz_right_open.svg")
		},
		"vertical": {
			"top": load("res://assets/sprites/door_vert_top_open.svg"),
			"bottom": load("res://assets/sprites/door_vert_bottom_open.svg")
		}
	}

	# Open all door tiles associated with this room (supports double doors on all entrances)
	for d in doors:
		if d["room_id"] == r_id and not d["is_open"]:
			d["is_open"] = true
			var orient = d.get("orientation", "horizontal")
			var part = d.get("part", "left")
			d["sprite"].texture = paired_open_textures.get(orient, {}).get(part, paired_open_textures["horizontal"]["left"])
			grid[d["pos"].y][d["pos"].x] = 0
			_spawn_dust_puff(d["sprite"].position)
			var d_tween = create_tween()
			d_tween.tween_property(d["sprite"], "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			d_tween.tween_property(d["sprite"], "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	_log("[color=#f59e0b]🚪 Chamber %d breached! Fog fades away![/color]" % r_id)
	
	# Hero strides cleanly 2 tiles inside the room past the doorway chokepoint so they never get trapped on the door!
	if player:
		var breach_tile = _get_room_breach_entrance_tile(r_id, breach_origin)
		player.grid_pos = breach_tile
		var stride_tween = create_tween()
		stride_tween.tween_property(player, "position", grid_to_world(breach_tile), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade Fog of War
	if fog_overlays.has(r_id):
		var fog = fog_overlays[r_id]
		var tween = create_tween()
		tween.tween_property(fog, "modulate:a", 0.0, 0.4)
		tween.tween_callback(fog.queue_free)
		fog_overlays.erase(r_id)
		
	# Light up and fade in sconces inside this chamber
	if room_torches.has(r_id):
		for t_obj in room_torches[r_id]:
			t_obj["sconce"].visible = true
			t_obj["glow"].visible = true
			t_obj["glow"].modulate.a = 0.0
			var t_tween = create_tween()
			t_tween.tween_property(t_obj["glow"], "modulate:a", 0.70, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Find and activate living monsters in this room
	var engaged_monsters: Array[CombatUnit] = []
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0 and enemy.room_id == r_id:
			enemy.visible = true
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
	
	var reward_type = chest.get("reward", "face_drop")
	if reward_type == "dungeon_crown":
		_add_relic("Crown of the Dungeon Master", "👑 Legendary victory relic! All chambers purged.")
		_log("[color=#22c55e][b]👑 RELIC OF VICTORY: You claimed the Dungeon Crown! All chambers conquered![/b][/color]")
	else:
		# Gold Cache from Chest
		var base_gold = randi_range(35, 75)
		var final_gold = int(float(base_gold) * get_estate_gold_mult())
		if player:
			player.add_gold(final_gold)
			play_gold_sfx()
			_show_floating_text(grid_to_world(chest["pos"]) + Vector2(0, -28), "+%d Gold 🪙" % final_gold, Color(1.0, 0.84, 0.0))
			_log("[color=#eab308]💰 Chest contained [b]%d Gold[/b] (Total: %d Gold)![/color]" % [final_gold, player.gold])
			_update_gold_ui()

		var r_loot = randf()
		if r_loot < 0.25:
			# Rare Weapon Chassis Drop with Unique Trait
			var weapon_item = ItemData.generate_random_weapon(current_combat_room_id)
			inventory_items.append(weapon_item)
			_log("[color=#38bdf8]⚔️ WEAPON DROP: Found [b]%s[/b]! Chassis Trait: [b]%s[/b] (%s). Equip via Backpack [B].[/color]" % [weapon_item.name, weapon_item.trait_name, weapon_item.trait_desc])
			_show_floating_text(grid_to_world(chest["pos"]), "⚔️ %s" % weapon_item.name, Color(0.38, 0.74, 0.97))
		elif r_loot < 0.40:
			# Rare Estate Collectible Trophy with Perk for Manor!
			var trophies = [
				{"id": "trophy_goblin_idol", "name": "Golden Goblin Idol", "desc": "Gilded idol of greed recovered from goblin depths"},
				{"id": "trophy_gargoyle", "name": "Gargoyle Stone Sconce", "desc": "Heavy carved stone bust from cathedral rafters"},
				{"id": "trophy_dragon_seal", "name": "Dragon King's Seal", "desc": "Wax signet imbued with draconic precision"},
				{"id": "trophy_chalice", "name": "Ancient King's Chalice", "desc": "Ceremonial cup said to prolong mortal vitality"},
				{"id": "trophy_obsidian_relic", "name": "Cursed Obsidian Relic", "desc": "Jagged volcanic shard humming with destructive malice"}
			]
			var t_cfg = trophies.pick_random()
			var trophy_item = ItemData.create_estate_trophy(t_cfg["id"], t_cfg["name"], t_cfg["desc"])
			inventory_items.append(trophy_item)
			_log("[color=#eab308]🏛️ ESTATE TROPHY: Claimed [b]%s[/b]! Mount in your Manor [B] to activate: %s![/color]" % [trophy_item.name, trophy_item.estate_perk_desc])
			_show_floating_text(grid_to_world(chest["pos"]), "🏛️ %s" % trophy_item.name, Color(0.98, 0.82, 0.2))
		else:
			# Procedural Die Face Loot Drop
			var drop_face = DieData.generate_random_face(current_combat_room_id)
			var face_item = ItemData.create_face_item(drop_face)
			inventory_items.append(face_item)
			_log("[color=#facc15]💎 LOOT DROP: Acquired Die Face [b]%s[/b] (%s)! Press [B] to socket it.[/color]" % [face_item.name, drop_face.get("desc", "")])
			_show_floating_text(grid_to_world(chest["pos"]), "+ FACE: %s" % drop_face.get("title", "Die Face"), Color(0.98, 0.85, 0.2))
		
		_sync_equipped_weapon_to_backpack()
		_render_backpack_inventory_cards()
		_update_hud_display()

func get_room_rect(r_id: int) -> Rect2i:
	for r in dungeon_rooms:
		if r.get("id", -1) == r_id:
			return r.get("rect", Rect2i())
	return Rect2i()

func _lock_combat_chamber_doors(r_id: int) -> void:
	var paired_closed_textures = {
		"horizontal": {
			"left": load("res://assets/sprites/door_horiz_left_closed.svg"),
			"right": load("res://assets/sprites/door_horiz_right_closed.svg")
		},
		"vertical": {
			"top": load("res://assets/sprites/door_vert_top_closed.svg"),
			"bottom": load("res://assets/sprites/door_vert_bottom_closed.svg")
		}
	}
	var locked_count = 0
	for d in doors:
		if d.get("room_id", -1) == r_id:
			d["is_open"] = false
			var orient = d.get("orientation", "horizontal")
			var part = d.get("part", "left")
			if is_instance_valid(d["sprite"]):
				d["sprite"].texture = paired_closed_textures.get(orient, {}).get(part, paired_closed_textures["horizontal"]["left"])
				var d_tween = create_tween()
				d_tween.tween_property(d["sprite"], "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				d_tween.tween_property(d["sprite"], "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			grid[d["pos"].y][d["pos"].x] = 2 # Closed door blocks passage and line of sight
			_spawn_dust_puff(grid_to_world(d["pos"]))
			_show_floating_text(grid_to_world(d["pos"]), "PORTCULLIS LOCKED!", Color(0.95, 0.25, 0.25))
			locked_count += 1
	if locked_count > 0:
		play_door_creak_sfx()
		_log("[color=#ef4444][b]🔒 PORTCULLIS ENGAGED! Chamber doors slammed shut. Conquer all foes to unseal![/b][/color]")

func _unlock_combat_chamber_doors(r_id: int) -> void:
	var paired_open_textures = {
		"horizontal": {
			"left": load("res://assets/sprites/door_horiz_left_open.svg"),
			"right": load("res://assets/sprites/door_horiz_right_open.svg")
		},
		"vertical": {
			"top": load("res://assets/sprites/door_vert_top_open.svg"),
			"bottom": load("res://assets/sprites/door_vert_bottom_open.svg")
		}
	}
	var opened_count = 0
	for d in doors:
		if d.get("room_id", -1) == r_id:
			d["is_open"] = true
			var orient = d.get("orientation", "horizontal")
			var part = d.get("part", "left")
			if is_instance_valid(d["sprite"]):
				d["sprite"].texture = paired_open_textures.get(orient, {}).get(part, paired_open_textures["horizontal"]["left"])
				var d_tween = create_tween()
				d_tween.tween_property(d["sprite"], "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				d_tween.tween_property(d["sprite"], "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			grid[d["pos"].y][d["pos"].x] = 0 # Floor walkable
			_spawn_dust_puff(grid_to_world(d["pos"]))
			_show_floating_text(grid_to_world(d["pos"]), "PORTCULLIS OPENED!", Color(0.2, 0.9, 0.4))
			opened_count += 1
	if opened_count > 0:
		play_door_creak_sfx()
		_log("[color=#22c55e][b]🔓 PORTCULLIS RAISED! Chamber unlocked. Passage restored.[/b][/color]")

func _start_combat_countdown(engaged_monsters: Array[CombatUnit]) -> void:
	current_mode = GameMode.COMBAT_COUNTDOWN
	active_combat_enemies = engaged_monsters
	_lock_combat_chamber_doors(current_combat_room_id)
	
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
			elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				_set_action_order("move_first")
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				_set_action_order("attack_first")
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
	# If player previously queued 2 attacks, moving removes the second attack
	if player_attack_target_2 != Vector2i(-1, -1):
		player_attack_target_2 = Vector2i(-1, -1)
		if is_instance_valid(attack_indicator_2):
			attack_indicator_2.visible = false
		_log("[color=#38bdf8]Strike 2 removed. Planning 1 Strike + 1 Move.[/color]")

	if player_move_target == Vector2i(-1, -1):
		var target1 = player.grid_pos + dir
		if not is_valid_grid_pos(target1) or grid[target1.y][target1.x] != 0:
			_log("[color=#ef4444]Cannot move into wall![/color]")
			return
		player_move_target = target1
		move_indicator.position = grid_to_world(target1)
		move_indicator.visible = true
		play_dice_lock_sfx()
		_log("[color=#38bdf8]Move destination → (%d, %d). Press direction again for Step 2.[/color]" % [target1.x, target1.y])
	elif player_move_target_2 == Vector2i(-1, -1):
		var target2 = player_move_target + dir
		if not is_valid_grid_pos(target2) or grid[target2.y][target2.x] != 0:
			_log("[color=#ef4444]Cannot move into wall![/color]")
			return
		player_move_target_2 = target2
		if is_instance_valid(move_indicator_2):
			move_indicator_2.position = grid_to_world(target2)
			move_indicator_2.visible = true
		# 2 moves clears attack
		player_attack_target = Vector2i(-1, -1)
		player_attack_target_2 = Vector2i(-1, -1)
		attack_indicator.visible = false
		if is_instance_valid(attack_indicator_2): attack_indicator_2.visible = false
		play_dice_lock_sfx()
		_log("[color=#22c55e]⚡ 2-Tile Move Queued → (%d, %d) then (%d, %d)![/color]" % [player_move_target.x, player_move_target.y, target2.x, target2.y])
	else:
		var target1 = player.grid_pos + dir
		if not is_valid_grid_pos(target1) or grid[target1.y][target1.x] != 0:
			_log("[color=#ef4444]Cannot move into wall![/color]")
			return
		player_move_target = target1
		player_move_target_2 = Vector2i(-1, -1)
		move_indicator.position = grid_to_world(target1)
		move_indicator.visible = true
		if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
		play_dice_lock_sfx()
		_log("[color=#38bdf8]Move destination → (%d, %d)[/color]" % [target1.x, target1.y])

	_validate_attack_target_range()
	_update_combat_plan_hud()

func _set_action_order(order: String) -> void:
	if player_action_order == order:
		return
	player_action_order = order
	play_dice_lock_sfx()
	_update_action_order_ui()
	_validate_attack_target_range()
	_update_combat_plan_hud()
	if player_action_order == "move_first":
		_log("[color=#38bdf8]⚡ Stance: [b][1] 👟 MOVE FIRST ➔ ⚔️ STRIKE[/b][/color]")
		_show_floating_text(player.position, "ADVANCE [1]", Color(0.38, 0.74, 0.97))
	elif player_action_order == "attack_first":
		_log("[color=#f59e0b]⚡ Stance: [b][2] ⚔️ STRIKE FIRST ➔ 👟 MOVE[/b][/color]")
		_show_floating_text(player.position, "HIT & RUN [2]", Color(0.98, 0.65, 0.2))

func _toggle_action_order() -> void:
	if player_action_order == "move_first":
		_set_action_order("attack_first")
	else:
		_set_action_order("move_first")

func _update_action_order_ui() -> void:
	var btns = [
		{"btn": stance_btn_1, "id": "move_first", "color": Color(0.22, 0.74, 0.97)},
		{"btn": stance_btn_2, "id": "attack_first", "color": Color(0.98, 0.65, 0.2)}
	]
	for b_cfg in btns:
		var btn: Button = b_cfg["btn"]
		if not is_instance_valid(btn):
			continue
		var is_active = (player_action_order == b_cfg["id"])
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		style.set_border_width_all(2 if is_active else 1)
		if is_active:
			style.bg_color = Color(0.06, 0.12, 0.18, 0.98)
			style.border_color = b_cfg["color"]
			btn.add_theme_color_override("font_color", b_cfg["color"])
		else:
			style.bg_color = Color(0.06, 0.08, 0.12, 0.75)
			style.border_color = Color(0.2, 0.25, 0.35, 0.6)
			btn.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _validate_attack_target_range() -> void:
	if player_attack_target == Vector2i(-1, -1):
		return
	if player_move_target_2 != Vector2i(-1, -1):
		# Two moves queued: no attacks allowed
		player_attack_target = Vector2i(-1, -1)
		player_attack_target_2 = Vector2i(-1, -1)
		attack_indicator.visible = false
		if is_instance_valid(attack_indicator_2): attack_indicator_2.visible = false
		return

	var dist_curr = max(abs(player_attack_target.x - player.grid_pos.x), abs(player_attack_target.y - player.grid_pos.y))
	var dist_move = 999
	if player_action_order == "move_first" and player_move_target != Vector2i(-1, -1):
		dist_move = max(abs(player_attack_target.x - player_move_target.x), abs(player_attack_target.y - player_move_target.y))
	
	var in_range = false
	if player_action_order == "move_first":
		in_range = (dist_move <= 1 or dist_curr <= 1)
	else:
		in_range = (dist_curr <= 1)
		
	if not in_range:
		player_attack_target = Vector2i(-1, -1)
		player_attack_target_2 = Vector2i(-1, -1)
		if is_instance_valid(attack_indicator):
			attack_indicator.visible = false
		if is_instance_valid(attack_indicator_2):
			attack_indicator_2.visible = false
		if attack_reticle_tween and attack_reticle_tween.is_valid():
			attack_reticle_tween.kill()
		_log("[color=#f59e0b]⚠️ Target is now out of range after repositioning. Strike cancelled.[/color]")
		return

	# Validate second attack target if set
	if player_attack_target_2 != Vector2i(-1, -1) and player_attack_target_2 != player_attack_target:
		var dist2_curr = max(abs(player_attack_target_2.x - player.grid_pos.x), abs(player_attack_target_2.y - player.grid_pos.y))
		var dist2_move = 999
		if player_action_order == "move_first" and player_move_target != Vector2i(-1, -1):
			dist2_move = max(abs(player_attack_target_2.x - player_move_target.x), abs(player_attack_target_2.y - player_move_target.y))
		var in_range_2 = (dist2_move <= 1 or dist2_curr <= 1) if player_action_order == "move_first" else (dist2_curr <= 1)
		if not in_range_2:
			player_attack_target_2 = Vector2i(-1, -1)
			if is_instance_valid(attack_indicator_2):
				attack_indicator_2.visible = false
			_log("[color=#f59e0b]⚠️ Strike 2 target out of range. Cancelled Strike 2.[/color]")

func _update_combat_plan_hud() -> void:
	if not is_instance_valid(last_action_label):
		return
	var order_badge = "[1: Move ➔ Hit]"
	if player_move_target_2 != Vector2i(-1, -1):
		order_badge = "[👟 2x Sprint: Move ➔ Move]"
	elif player_attack_target_2 != Vector2i(-1, -1):
		order_badge = "[⚔️ 2x Flurry: Hit ➔ Hit]"
	elif player_action_order == "attack_first":
		order_badge = "[2: Hit ➔ Move]"

	var strike_str = "⚔️ Strike: None"
	if player_attack_target != Vector2i(-1, -1):
		if player_attack_target_2 != Vector2i(-1, -1):
			if player_attack_target_2 == player_attack_target:
				strike_str = "⚔️ Strike: (%d, %d) [2x]" % [player_attack_target.x, player_attack_target.y]
			else:
				strike_str = "⚔️ Strike 1: (%d, %d) • Strike 2: (%d, %d)" % [player_attack_target.x, player_attack_target.y, player_attack_target_2.x, player_attack_target_2.y]
		else:
			strike_str = "⚔️ Strike: (%d, %d)" % [player_attack_target.x, player_attack_target.y]

	var move_str = "🦶 Move: None"
	if player_move_target != Vector2i(-1, -1):
		if player_move_target_2 != Vector2i(-1, -1):
			move_str = "🦶 Step 1: (%d, %d) • Step 2: (%d, %d)" % [player_move_target.x, player_move_target.y, player_move_target_2.x, player_move_target_2.y]
		else:
			move_str = "🦶 Step: (%d, %d)" % [player_move_target.x, player_move_target.y]

	last_action_label.text = "%s   •   %s   •   %s" % [order_badge, strike_str, move_str]

func _handle_combat_left_click(pos: Vector2i) -> void:
	var label = "tile (%d, %d)" % [pos.x, pos.y]
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == pos:
			label = enemy.unit_name
			break
	_toggle_attack_target(pos, label)

func _handle_combat_right_click(pos: Vector2i) -> void:
	if pos == player.grid_pos:
		player_move_target = Vector2i(-1, -1)
		player_move_target_2 = Vector2i(-1, -1)
		move_indicator.visible = false
		if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
		_log("[color=#94a3b8]Holding position.[/color]")
		_validate_attack_target_range()
		_update_combat_plan_hud()
		return

	# If player previously queued 2 attacks, right clicking a move removes the second attack!
	if player_attack_target_2 != Vector2i(-1, -1):
		player_attack_target_2 = Vector2i(-1, -1)
		if is_instance_valid(attack_indicator_2):
			attack_indicator_2.visible = false
		_log("[color=#38bdf8]Strike 2 removed. Planning 1 Strike + 1 Move.[/color]")

	var diff = (pos - player.grid_pos).abs()
	var dist_from_hero = max(diff.x, diff.y)

	# If player hasn't selected Step 1 yet
	if player_move_target == Vector2i(-1, -1):
		if dist_from_hero == 1 and is_valid_grid_pos(pos) and grid[pos.y][pos.x] == 0:
			var is_enemy_tile = false
			for enemy in active_combat_enemies:
				if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == pos:
					is_enemy_tile = true
					break
			if is_enemy_tile:
				_log("[color=#f59e0b]Enemy blocks that tile! Left-Click to attack.[/color]")
			else:
				player_move_target = pos
				move_indicator.position = grid_to_world(pos)
				move_indicator.visible = true
				play_dice_lock_sfx()
				_log("[color=#38bdf8]Move destination → (%d, %d). Click another tile to step twice.[/color]" % [pos.x, pos.y])
		elif dist_from_hero == 2 and is_valid_grid_pos(pos) and grid[pos.y][pos.x] == 0:
			var step_dir = (pos - player.grid_pos).clamp(Vector2i(-1, -1), Vector2i(1, 1))
			var intermediate = player.grid_pos + step_dir
			if is_valid_grid_pos(intermediate) and grid[intermediate.y][intermediate.x] == 0:
				player_move_target = intermediate
				player_move_target_2 = pos
				move_indicator.position = grid_to_world(intermediate)
				move_indicator.visible = true
				if is_instance_valid(move_indicator_2):
					move_indicator_2.position = grid_to_world(pos)
					move_indicator_2.visible = true
				# Choosing 2 moves clears attack
				player_attack_target = Vector2i(-1, -1)
				player_attack_target_2 = Vector2i(-1, -1)
				attack_indicator.visible = false
				if is_instance_valid(attack_indicator_2): attack_indicator_2.visible = false
				play_dice_lock_sfx()
				_log("[color=#22c55e]⚡ 2-Tile SPRINT queued → (%d, %d) then (%d, %d)![/color]" % [intermediate.x, intermediate.y, pos.x, pos.y])
				_show_floating_text(grid_to_world(pos), "SPRINT 2 TILES!", Color(0.3, 0.9, 0.4))
		else:
			_log("[color=#94a3b8]Right-click adjacent floor tile to step (or within 2 spaces to sprint).[/color]")
	else:
		# Player already has Step 1 selected
		if pos == player_move_target:
			if player_move_target_2 != Vector2i(-1, -1):
				player_move_target_2 = Vector2i(-1, -1)
				if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
				_log("[color=#94a3b8]Cancelled Step 2. Keeping Step 1.[/color]")
			else:
				player_move_target = Vector2i(-1, -1)
				move_indicator.visible = false
				_log("[color=#94a3b8]Holding position.[/color]")
		elif pos == player_move_target_2:
			player_move_target_2 = Vector2i(-1, -1)
			if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
			_log("[color=#94a3b8]Cancelled Step 2. Keeping Step 1.[/color]")
		else:
			var dist_from_step1 = max(abs(pos.x - player_move_target.x), abs(pos.y - player_move_target.y))
			if dist_from_step1 == 1 and is_valid_grid_pos(pos) and grid[pos.y][pos.x] == 0:
				player_move_target_2 = pos
				if is_instance_valid(move_indicator_2):
					move_indicator_2.position = grid_to_world(pos)
					move_indicator_2.visible = true
				# Choosing 2 moves clears attack
				player_attack_target = Vector2i(-1, -1)
				player_attack_target_2 = Vector2i(-1, -1)
				attack_indicator.visible = false
				if is_instance_valid(attack_indicator_2): attack_indicator_2.visible = false
				play_dice_lock_sfx()
				_log("[color=#22c55e]⚡ Step 2 queued → (%d, %d). Moving 2 tiles![/color]" % [pos.x, pos.y])
				_show_floating_text(grid_to_world(pos), "STEP 2 LOCKED", Color(0.3, 0.9, 0.4))
			elif dist_from_hero == 1 and is_valid_grid_pos(pos) and grid[pos.y][pos.x] == 0:
				player_move_target = pos
				player_move_target_2 = Vector2i(-1, -1)
				move_indicator.position = grid_to_world(pos)
				move_indicator.visible = true
				if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
				play_dice_lock_sfx()
				_log("[color=#38bdf8]Move destination updated → (%d, %d)[/color]" % [pos.x, pos.y])
			else:
				_log("[color=#94a3b8]Right-click a tile adjacent to Step 1 to add Step 2.[/color]")

	_validate_attack_target_range()
	_update_combat_plan_hud()

func _toggle_attack_target(pos: Vector2i, label: String) -> void:
	# If player previously had 2 moves queued, clicking an attack removes Step 2!
	if player_move_target_2 != Vector2i(-1, -1):
		player_move_target_2 = Vector2i(-1, -1)
		if is_instance_valid(move_indicator_2):
			move_indicator_2.visible = false
		_log("[color=#38bdf8]Step 2 sprint removed. Planning 1 Move + 1 Strike.[/color]")

	# Check range for this tile
	var dist_curr = max(abs(pos.x - player.grid_pos.x), abs(pos.y - player.grid_pos.y))
	var dist_move = 999
	if player_action_order == "move_first" and player_move_target != Vector2i(-1, -1):
		dist_move = max(abs(pos.x - player_move_target.x), abs(pos.y - player_move_target.y))
	
	var in_range = false
	if player_action_order == "move_first":
		in_range = (dist_move <= 1 or dist_curr <= 1)
	else:
		in_range = (dist_curr <= 1)
		
	if not in_range:
		play_attack_whiff_sfx()
		_show_floating_text(grid_to_world(pos), "OUT OF RANGE (1 Tile Melee)", Color(0.95, 0.45, 0.2))
		_log("[color=#ef4444]⚠️ Out of range! Melee strikes reach adjacent squares (1 tile).[/color]")
		return

	# If no attack target yet: set Strike 1
	if player_attack_target == Vector2i(-1, -1):
		player_attack_target = pos
		attack_indicator.position = grid_to_world(pos)
		attack_indicator.visible = true
		attack_indicator.scale = Vector2(1.35, 1.35)
		if attack_reticle_tween and attack_reticle_tween.is_valid():
			attack_reticle_tween.kill()
		attack_reticle_tween = create_tween().set_loops()
		attack_reticle_tween.tween_property(attack_indicator, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		attack_reticle_tween.tween_property(attack_indicator, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		play_dice_lock_sfx()
		_log("[color=#ef4444]⚔️ Strike 1 queued on %s (%d, %d). Click again or another enemy for Strike 2![/color]" % [label, pos.x, pos.y])
	elif player_attack_target_2 == Vector2i(-1, -1):
		# Player ALREADY has Strike 1. Clicking again (same tile or adjacent target) sets Strike 2!
		player_attack_target_2 = pos
		if is_instance_valid(attack_indicator_2):
			if pos == player_attack_target:
				attack_indicator_2.position = grid_to_world(pos) + Vector2(0, -8)
			else:
				attack_indicator_2.position = grid_to_world(pos)
			attack_indicator_2.visible = true
		# Choosing 2 attacks clears any move!
		player_move_target = Vector2i(-1, -1)
		player_move_target_2 = Vector2i(-1, -1)
		move_indicator.visible = false
		if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
		play_dice_lock_sfx()
		if pos == player_attack_target:
			_log("[color=#ef4444]⚔️ Double Strike (2x Hits) queued on %s![/color]" % label)
			_show_floating_text(grid_to_world(pos), "DOUBLE STRIKE!", Color(0.95, 0.3, 0.3))
		else:
			_log("[color=#f59e0b]⚔️ Dual Strikes queued: Strike 1 on (%d, %d), Strike 2 on %s (%d, %d)![/color]" % [player_attack_target.x, player_attack_target.y, label, pos.x, pos.y])
			_show_floating_text(grid_to_world(pos), "STRIKE 2 LOCKED", Color(0.95, 0.5, 0.3))
	else:
		# Player already has Strike 1 and Strike 2
		if pos == player_attack_target_2 or pos == player_attack_target:
			player_attack_target_2 = Vector2i(-1, -1)
			if is_instance_valid(attack_indicator_2):
				attack_indicator_2.visible = false
			_log("[color=#94a3b8]Cancelled Strike 2. Keeping Strike 1.[/color]")
		else:
			player_attack_target_2 = pos
			if is_instance_valid(attack_indicator_2):
				attack_indicator_2.position = grid_to_world(pos)
				attack_indicator_2.visible = true
			play_dice_lock_sfx()
			_log("[color=#f59e0b]Strike 2 retargeted to %s (%d, %d)![/color]" % [label, pos.x, pos.y])

	_validate_attack_target_range()
	_update_combat_plan_hud()

	for enemy in active_combat_enemies:
		if is_instance_valid(enemy):
			var is_tgt = (enemy.grid_pos == player_attack_target or enemy.grid_pos == player_attack_target_2)
			if enemy.has_method("set_targeted"):
				enemy.set_targeted(is_tgt)
				
	_update_combat_plan_hud()

func _start_planning_phase() -> void:
	if effects_container:
		for child in effects_container.get_children():
			effects_container.remove_child(child)
			child.queue_free()

	if player:
		var hero_ticks = player.tick_status_effects()
		for t in hero_ticks:
			if t["type"] == "bleed":
				_show_floating_text(player.position, "-%d HP (BLEED)" % t["damage"], Color(0.9, 0.2, 0.2))
			elif t["type"] == "burn":
				_show_floating_text(player.position, "-%d HP (BURN)" % t["damage"], Color(1.0, 0.5, 0.1))

	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			var e_ticks = enemy.tick_status_effects()
			for t in e_ticks:
				if t["type"] == "bleed":
					_show_floating_text(enemy.position, "-%d HP (BLEED)" % t["damage"], Color(0.9, 0.2, 0.2))
				elif t["type"] == "burn":
					_show_floating_text(enemy.position, "-%d HP (BURN)" % t["damage"], Color(1.0, 0.5, 0.1))

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
	player_move_target_2 = Vector2i(-1, -1)
	player_attack_target = Vector2i(-1, -1)
	player_attack_target_2 = Vector2i(-1, -1)
	move_indicator.visible = false
	if is_instance_valid(move_indicator_2): move_indicator_2.visible = false
	attack_indicator.visible = false
	if is_instance_valid(attack_indicator_2): attack_indicator_2.visible = false
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
	
	_trigger_pulse_roll()
	_plan_enemy_intents()
	_update_hud_display()
	_update_action_order_ui()
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
	var r_rect = get_room_rect(current_combat_room_id)

	for d in directions:
		var n = enemy.grid_pos + d
		if not is_valid_grid_pos(n) or grid[n.y][n.x] != 0:
			continue
		if r_rect.size != Vector2i.ZERO and not r_rect.has_point(n):
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
			enemy.planned_action_1 = "none"
			enemy.planned_action_2 = "none"
			_show_floating_text(enemy.position, "DIZZY!", Color(0.95, 0.85, 0.2))
			continue
			
		var diff = player.grid_pos - enemy.grid_pos
		var abs_diff = diff.abs()
		var dist_chebyshev = max(abs_diff.x, abs_diff.y)
		var has_los = has_line_of_sight(enemy.grid_pos, player.grid_pos)
		
		# 1. GOBLIN CHARGER: Straight line 3-tile rush
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
				var r_rect = get_room_rect(current_combat_room_id)
				for step in range(1, 4):
					var c_tile = enemy.grid_pos + charge_dir * step
					var inside_room = (r_rect.size == Vector2i.ZERO or r_rect.has_point(c_tile))
					if is_valid_grid_pos(c_tile) and grid[c_tile.y][c_tile.x] == 0 and inside_room:
						charge_tiles.append(c_tile)
						if show_telegraphs:
							_spawn_danger_indicator(c_tile)
					else:
						break
				enemy.facing_dir = charge_dir
				var charge_dest = enemy.grid_pos + charge_dir * 3
				enemy.set_dual_intent("enemy_charge", "none", charge_dest, player.grid_pos, charge_tiles, 8)
				continue
			elif dist_chebyshev <= 1:
				# Adjacent! Reposition retreat or strike
				var retreat_step = _find_strafe_step(enemy, true)
				if retreat_step != enemy.grid_pos and is_valid_grid_pos(retreat_step) and grid[retreat_step.y][retreat_step.x] == 0:
					enemy.facing_dir = (retreat_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					var act_1 = "enemy_move" if randf() < 0.5 else "enemy_attack"
					var act_2 = "enemy_attack" if act_1 == "enemy_move" else "enemy_move"
					enemy.set_dual_intent(act_1, act_2, retreat_step, player.grid_pos, [player.grid_pos], 4)
					if show_telegraphs:
						_spawn_enemy_move_indicator(retreat_step)
						_spawn_danger_indicator(player.grid_pos)
					continue
				else:
					var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
					enemy.set_dual_intent("enemy_attack", "enemy_move", next_step, player.grid_pos, [player.grid_pos], 4)
					if show_telegraphs:
						_spawn_danger_indicator(player.grid_pos)
					continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_dual_intent("enemy_move", "enemy_move", next_step, Vector2i(-1,-1), [], 0)
				if show_telegraphs and next_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(next_step)
				continue
				
		# 2. CULTIST PYROMANCER: 3-Tile Cross Flame Blast with Recharge Turn!
		if enemy.unit_type == "pyromancer":
			if enemy.blast_cooldown > 0:
				# Pyromancer is recharging / gathering mana! Cannot blast this turn.
				enemy.blast_cooldown -= 1
				var strafe_step = _find_strafe_step(enemy, true) # Kites/backs off
				enemy.facing_dir = (player.grid_pos - strafe_step).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_dual_intent("enemy_move", "enemy_recharge", strafe_step, Vector2i(-1,-1), [], 0)
				_show_floating_text(enemy.position, "RECHARGING!", Color(0.38, 0.74, 0.97))
				if show_telegraphs and strafe_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(strafe_step)
				continue

			if dist_chebyshev <= 1:
				# Hero in melee range! Smart pyromancer kites/retreats away on Beat 1, then blasts on Beat 2!
				var retreat_step = _find_strafe_step(enemy, true)
				var blast_tiles: Array[Vector2i] = [player.grid_pos]
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var b_tile = player.grid_pos + d
					if is_valid_grid_pos(b_tile) and grid[b_tile.y][b_tile.x] == 0:
						blast_tiles.append(b_tile)
				if retreat_step != enemy.grid_pos:
					enemy.facing_dir = (player.grid_pos - retreat_step).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.blast_cooldown = 1 # Must recharge next turn!
					enemy.set_dual_intent("enemy_move", "enemy_blast", retreat_step, player.grid_pos, blast_tiles, 7)
					if show_telegraphs:
						_spawn_enemy_move_indicator(retreat_step)
						for bt in blast_tiles: _spawn_danger_indicator(bt)
					continue
			
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
				var strafe_step = _find_strafe_step(enemy, false)
				var act_1 = "enemy_blast" if randf() < 0.5 else "enemy_move"
				var act_2 = "enemy_move" if act_1 == "enemy_blast" else "enemy_blast"
				enemy.blast_cooldown = 1 # Must recharge next turn!
				enemy.set_dual_intent(act_1, act_2, strafe_step, player.grid_pos, blast_tiles, 7)
				if show_telegraphs and strafe_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(strafe_step)
				continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_dual_intent("enemy_move", "enemy_move", next_step, Vector2i(-1,-1), [], 0)
				if show_telegraphs and next_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(next_step)
				continue
			
		# 3. ORC BRAWLER: Wide 3-Tile Cleave Sweep + Smart Lateral Strafing
		if enemy.unit_type == "brawler":
			if dist_chebyshev <= 1 and has_los:
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
				var strafe_step = _find_strafe_step(enemy, false)
				var act_1 = "enemy_sweep" if randf() < 0.5 else "enemy_move"
				var act_2 = "enemy_move" if act_1 == "enemy_sweep" else "enemy_sweep"
				enemy.set_dual_intent(act_1, act_2, strafe_step, player.grid_pos, valid_sweep, 6)
				if show_telegraphs and strafe_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(strafe_step)
				continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_dual_intent("enemy_move", "enemy_move", next_step, Vector2i(-1,-1), [], 0)
				if show_telegraphs and next_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(next_step)
				continue
			
		# 4. SKELETON SHIELDBEARER & GRUNTS
		if dist_chebyshev <= 1 and has_los:
			var strafe_step = _find_strafe_step(enemy, false)
			var act_1 = "enemy_attack" if randf() < 0.5 else "enemy_move"
			var act_2 = "enemy_move" if act_1 == "enemy_attack" else "enemy_attack"
			enemy.facing_dir = (player.grid_pos - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
			enemy.set_dual_intent(act_1, act_2, strafe_step, player.grid_pos, [player.grid_pos], 4)
			if show_telegraphs:
				_spawn_danger_indicator(player.grid_pos)
				if strafe_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(strafe_step)
		elif dist_chebyshev == 2 and has_los:
			var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
			enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
			# Beat 1: Advance adjacent, Beat 2: Strike!
			enemy.set_dual_intent("enemy_move", "enemy_attack", next_step, player.grid_pos, [player.grid_pos], 4)
			if show_telegraphs:
				if next_step != enemy.grid_pos:
					_spawn_enemy_move_indicator(next_step)
				_spawn_danger_indicator(player.grid_pos)
		else:
			var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
			if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_dual_intent("enemy_move", "enemy_move", next_step, Vector2i(-1,-1), [], 0)
				if show_telegraphs:
					_spawn_enemy_move_indicator(next_step)
			else:
				enemy.set_dual_intent("none", "none", enemy.grid_pos, Vector2i(-1,-1), [], 0)

func _find_smart_path_step(from_pos: Vector2i, target_pos: Vector2i, current_unit: CombatUnit) -> Vector2i:
	var diff = (target_pos - from_pos).abs()
	if diff.x <= 1 and diff.y <= 1:
		return from_pos

	var queue: Array[Vector2i] = [from_pos]
	var visited: Dictionary = {}
	visited[from_pos] = from_pos
	
	var blocked: Dictionary = {}
	var r_rect = get_room_rect(current_combat_room_id)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var pos_i = Vector2i(x, y)
			if grid[y][x] != 0 or (r_rect.size != Vector2i.ZERO and not r_rect.has_point(pos_i)):
				blocked[pos_i] = true
				
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
		var final_tex_path = p_face.get("icon", "res://assets/ui/die_face_1.svg")
		if ResourceLoader.exists(final_tex_path):
			player_die_icon.texture = load(final_tex_path)
		var dmg = p_face.get("damage", 1) + (player.dmg_bonus if player else 0)
		var title_str = p_face.get("title", "STRIKE")
		player_die_title.text = "⚔️ %d DMG" % dmg
		player_die_desc.text = "%s • [L-Click Strike]" % title_str
		if dmg >= 6:
			player_die_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif dmg >= 4:
			player_die_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.25))
		else:
			player_die_title.add_theme_color_override("font_color", Color(0.38, 0.78, 0.95))
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
			elif enemy.intent_type == "RECHARGE": act = "🔮 Recharging"
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

	# Sub-Beat 1: Simultaneous First Actions
	_log("[b][color=#38bdf8]▶ SUB-BEAT 1: SIMULTANEOUS CLASH[/color][/b]")
	await _resolve_simultaneous_sub_beat(1)

	await get_tree().create_timer(0.12).timeout

	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
		return
	if player.current_hp <= 0:
		_game_over()
		return

	# Sub-Beat 2: Simultaneous Second Actions
	_log("[b][color=#f59e0b]▶ SUB-BEAT 2: SIMULTANEOUS CLASH[/color][/b]")
	await _resolve_simultaneous_sub_beat(2)

	# Hazards, checks, cleanup, end of pulse
	_process_hazard_tiles()
	await get_tree().create_timer(0.20).timeout

	if player.current_hp <= 0:
		_game_over()
		return

	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.clear_intent()

	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
	else:
		_start_planning_phase()

func _resolve_simultaneous_sub_beat(beat_num: int) -> void:
	# 1. Snapshot all starting positions before anyone moves on this sub-beat
	var start_positions: Dictionary = {}
	start_positions[player] = player.grid_pos
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0:
			start_positions[enemy] = enemy.grid_pos

	# 2. Determine who is moving on this beat
	var hero_is_moving = false
	var hero_move_dest = Vector2i(-1, -1)
	if player_move_target_2 != Vector2i(-1, -1):
		# Double moving: Beat 1 is Step 1, Beat 2 is Step 2
		if beat_num == 1:
			if player_move_target != Vector2i(-1, -1) and player_move_target != player.grid_pos:
				hero_is_moving = true
				hero_move_dest = player_move_target
		elif beat_num == 2:
			if player_move_target_2 != Vector2i(-1, -1) and player_move_target_2 != player.grid_pos:
				hero_is_moving = true
				hero_move_dest = player_move_target_2
	elif player_attack_target_2 != Vector2i(-1, -1):
		# Double attacking: hero does not move
		hero_is_moving = false
	else:
		# Standard single move according to stance
		if beat_num == 1 and player_action_order == "move_first":
			if player_move_target != Vector2i(-1, -1) and player_move_target != player.grid_pos:
				hero_is_moving = true
				hero_move_dest = player_move_target
		elif beat_num == 2 and player_action_order == "attack_first":
			if player_move_target != Vector2i(-1, -1) and player_move_target != player.grid_pos:
				hero_is_moving = true
				hero_move_dest = player_move_target

	var enemy_movers: Dictionary = {} # CombatUnit -> Vector2i
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive or enemy.current_hp <= 0:
			continue
		var act = enemy.planned_action_1 if beat_num == 1 else enemy.planned_action_2
		if act in ["enemy_move", "enemy_charge"]:
			var dest = enemy.planned_move_dest
			if dest != Vector2i(-1, -1) and dest != enemy.grid_pos:
				enemy_movers[enemy] = dest

	# 3. Resolve Contested Tiles & Clashes
	# If multiple units contest a tile, the highest DEX wins! Player wins ties.
	var tile_claims: Dictionary = {} # Vector2i -> Array[CombatUnit]
	if hero_is_moving:
		if not tile_claims.has(hero_move_dest):
			tile_claims[hero_move_dest] = []
		tile_claims[hero_move_dest].append(player)
	for enemy in enemy_movers:
		var d = enemy_movers[enemy]
		if not tile_claims.has(d):
			tile_claims[d] = []
		tile_claims[d].append(enemy)

	var successful_movers: Dictionary = {} # CombatUnit -> Vector2i
	var clashed_units: Array[CombatUnit] = []

	for dest in tile_claims:
		var contenders = tile_claims[dest]
		if contenders.size() == 1:
			var unit = contenders[0]
			var blocked_by_static = false
			if unit != player and player.grid_pos == dest and not hero_is_moving:
				blocked_by_static = true
			for other in active_combat_enemies:
				if is_instance_valid(other) and other != unit and other.is_alive and other.grid_pos == dest:
					if not enemy_movers.has(other) or enemy_movers[other] == other.grid_pos:
						blocked_by_static = true
						break
			if blocked_by_static:
				clashed_units.append(unit)
			else:
				successful_movers[unit] = dest
		else:
			# Contested tile clash! Sort by DEX
			contenders.sort_custom(func(a, b):
				var dex_a = a.get_total_dex() if a.has_method("get_total_dex") else 10
				var dex_b = b.get_total_dex() if b.has_method("get_total_dex") else 10
				if dex_a == dex_b and a == player:
					return true
				return dex_a > dex_b
			)
			successful_movers[contenders[0]] = dest
			for i in range(1, contenders.size()):
				clashed_units.append(contenders[i])

	# Animate clashes (bump back)
	for cu in clashed_units:
		_show_floating_text(grid_to_world(cu.grid_pos), "CLASH!", Color(0.95, 0.7, 0.1))
		cu.animate_bump_back(grid_to_world(cu.grid_pos))
		_log("[color=#f59e0b]⚡ %s clashed on movement and stumbled back![/color]" % cu.unit_name)

	# Execute successful movements in parallel
	var any_movement = false
	for sm in successful_movers:
		var dest = successful_movers[sm]
		sm.grid_pos = dest
		sm.animate_move_to(grid_to_world(dest), 0.20)
		any_movement = true

	if hero_is_moving:
		if beat_num == 1:
			player_move_target = Vector2i(-1, -1)
			if is_instance_valid(move_indicator):
				move_indicator.visible = false
		elif beat_num == 2:
			player_move_target_2 = Vector2i(-1, -1)
			player_move_target = Vector2i(-1, -1)
			if is_instance_valid(move_indicator_2):
				move_indicator_2.visible = false
			if is_instance_valid(move_indicator):
				move_indicator.visible = false

	if any_movement or not clashed_units.is_empty():
		await get_tree().create_timer(0.20).timeout

	# -------------------------------------------------------------
	# 4. SIMULTANEOUS ATTACK RESOLUTION
	# -------------------------------------------------------------
	var hero_is_attacking = false
	var hero_attack_tile = Vector2i(-1, -1)
	if player_attack_target_2 != Vector2i(-1, -1):
		# Double attacking: Beat 1 is Strike 1, Beat 2 is Strike 2
		if beat_num == 1:
			if player_attack_target != Vector2i(-1, -1):
				hero_is_attacking = true
				hero_attack_tile = player_attack_target
		elif beat_num == 2:
			if player_attack_target_2 != Vector2i(-1, -1):
				hero_is_attacking = true
				hero_attack_tile = player_attack_target_2
	elif player_move_target_2 != Vector2i(-1, -1):
		# Double moving: hero does not attack
		hero_is_attacking = false
	else:
		# Standard single attack according to stance
		if beat_num == 1 and player_action_order == "attack_first":
			if player_attack_target != Vector2i(-1, -1):
				hero_is_attacking = true
				hero_attack_tile = player_attack_target
		elif beat_num == 2 and player_action_order == "move_first":
			if player_attack_target != Vector2i(-1, -1):
				hero_is_attacking = true
				hero_attack_tile = player_attack_target

	var enemy_attacks: Array[Dictionary] = []
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive or enemy.current_hp <= 0:
			continue
		var act = enemy.planned_action_1 if beat_num == 1 else enemy.planned_action_2
		if act in ["enemy_attack", "enemy_sweep", "enemy_blast", "enemy_charge"]:
			enemy_attacks.append({
				"enemy": enemy,
				"action": act,
				"target_tile": enemy.planned_attack_dest if enemy.planned_attack_dest != Vector2i(-1, -1) else enemy.target_grid_pos,
				"telegraphed": enemy.telegraphed_tiles
			})

	# Animate all swings/thrusts in parallel
	if hero_is_attacking:
		player.animate_attack_thrust(grid_to_world(hero_attack_tile))
	for ea in enemy_attacks:
		ea["enemy"].animate_attack_thrust(grid_to_world(ea["target_tile"]))

	# Resolve Hero Attack Outcome
	if hero_is_attacking:
		await _resolve_hero_strike_simultaneous(hero_attack_tile, start_positions)
		if beat_num == 1:
			player_attack_target = Vector2i(-1, -1)
			if is_instance_valid(attack_indicator):
				attack_indicator.visible = false
		elif beat_num == 2:
			player_attack_target_2 = Vector2i(-1, -1)
			player_attack_target = Vector2i(-1, -1)
			if is_instance_valid(attack_indicator_2):
				attack_indicator_2.visible = false
			if is_instance_valid(attack_indicator):
				attack_indicator.visible = false

	# Resolve Enemy Attacks Outcome
	for ea in enemy_attacks:
		var enemy: CombatUnit = ea["enemy"]
		if not is_instance_valid(enemy) or not enemy.is_alive or enemy.current_hp <= 0:
			continue
		await _resolve_enemy_strike_simultaneous(enemy, ea["action"], ea["target_tile"], ea["telegraphed"], start_positions)

	if hero_is_attacking or not enemy_attacks.is_empty():
		await get_tree().create_timer(0.18).timeout

func _resolve_hero_strike_simultaneous(hero_attack_tile: Vector2i, start_positions: Dictionary) -> void:
	var dist = max(abs(hero_attack_tile.x - player.grid_pos.x), abs(hero_attack_tile.y - player.grid_pos.y))
	if dist > 1:
		play_attack_whiff_sfx()
		_log("[color=#94a3b8]Hero struck empty air! Target is out of range (1 Tile Melee).[/color]")
		_show_floating_text(grid_to_world(hero_attack_tile), "OUT OF RANGE!", Color(0.95, 0.45, 0.2))
		return

	# Identify who started at or moved into hero_attack_tile
	var started_enemy: CombatUnit = null
	for e in start_positions:
		if e != player and start_positions[e] == hero_attack_tile:
			started_enemy = e
			break

	var current_enemy: CombatUnit = null
	for e in active_combat_enemies:
		if is_instance_valid(e) and e.is_alive and e.grid_pos == hero_attack_tile:
			current_enemy = e
			break

	var face = player.loaded_face
	var base_dmg = face.get("damage", 0)
	var dmg = base_dmg + (player.dmg_bonus if base_dmg > 0 else 0)
	var is_knockback = face.get("knockback", false)

	# Active Weapon Chassis Trait check
	var main_w: ItemData = equipped_gear.get("hand_1", null)
	var chassis_trait = main_w.trait_id if main_w != null else ""
	if chassis_trait == "honed_edge" and dmg > 0:
		dmg += 1
	elif chassis_trait == "titans_grip" and dmg >= 5:
		is_knockback = true

	# Case 1: Enemy was on the tile, but stepped away this beat -> DODGED!
	if started_enemy != null and started_enemy != current_enemy:
		play_attack_whiff_sfx()
		_show_floating_text(grid_to_world(hero_attack_tile), "DODGED!", Color(0.4, 0.8, 1.0))
		_log("[color=#94a3b8]%s dodged Hero's strike![/color]" % started_enemy.unit_name)
		await _play_attack_impact_animation(grid_to_world(hero_attack_tile), face, false)
		return

	# Case 2: Enemy stepped INTO the tile this beat -> INTERCEPT! (+2 Bonus DMG!)
	var is_intercept = false
	if current_enemy != null and started_enemy != current_enemy:
		is_intercept = true
		dmg += 2
		_show_floating_text(grid_to_world(hero_attack_tile), "INTERCEPT! +2 DMG", Color(1.0, 0.45, 0.2))
		_log("[color=#f97316]⚡ INTERCEPT! Hero anticipated %s stepping into the tile! (+2 DMG)[/color]" % current_enemy.unit_name)

	# Case 3: Enemy was on tile and stayed there -> DIRECT HIT!
	if current_enemy != null:
		var hit_enemy = current_enemy
		if dmg == 0:
			_log("[color=#94a3b8]Hero rolled MISS! Stumbled.[/color]")
			await _play_attack_impact_animation(hit_enemy.position, face, false)
			_show_floating_text(hit_enemy.position, "MISS!", Color(0.6, 0.6, 0.6))
			return

		var is_crit = false
		if dmg > 0 and (is_intercept or randf() < (player.get_crit_chance() + get_estate_crit_bonus())):
			is_crit = true
			dmg = int(float(dmg) * 1.5) + (2 if not is_intercept else 0)
			_show_floating_text(player.position, "CRITICAL HIT!", Color(1.0, 0.45, 0.2))
			_log("[color=#f97316][b]⚡ CRITICAL HIT! Strike amplified to %d DMG![/b][/color]" % dmg)

		# Shieldbearer Frontal Defense
		var attack_blocked = false
		if hit_enemy.has_shield and not hit_enemy.shield_broken:
			var attack_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
			if hit_enemy.facing_dir == -attack_dir or hit_enemy.facing_dir == Vector2i.ZERO:
				if is_knockback or dmg >= 8:
					hit_enemy.shield_broken = true
					_log("[color=#38bdf8]⚡ Hero's heavy strike SHATTERED %s's shield![/color]" % hit_enemy.unit_name)
					_show_floating_text(hit_enemy.position, "GUARD BROKEN!", Color(0.3, 0.8, 0.95))
				else:
					attack_blocked = true
					_log("[color=#94a3b8]🛡️ %s's tower shield BLOCKED the front strike! (0 DMG)[/color]" % hit_enemy.unit_name)
					_show_floating_text(hit_enemy.position, "BLOCKED BY SHIELD!", Color(0.38, 0.74, 0.97))

		await _play_attack_impact_animation(hit_enemy.position, face, attack_blocked)
		var attack_vec = (hit_enemy.position - player.position).normalized()
		if attack_blocked:
			_spawn_shield_barrier_vfx(hit_enemy.position)
		elif is_knockback or dmg >= 8 or is_crit:
			_spawn_shockwave(hit_enemy.position, Color(0.96, 0.72, 0.2))
		else:
			_spawn_slash_vfx(hit_enemy.position, attack_vec)

		if not attack_blocked:
			var ability = face.get("ability", "none")
			var ability_tier = face.get("ability_tier", 1) + player.get_status_potency_bonus()
			var bypass_armor = (ability == "pierce")
			hit_enemy.take_damage(dmg, attack_vec, bypass_armor)

			if is_crit:
				_log("[color=#f97316]Hero CRITICALLY struck %s for %d damage![/color]" % [hit_enemy.unit_name, dmg])
				_show_floating_text(hit_enemy.position, "-%d CRIT!" % dmg, Color(1.0, 0.4, 0.2))
			elif player.dmg_bonus > 0 and base_dmg > 0:
				_log("[color=#22c55e]Hero struck %s for %d damage! (%d base + %d gear bonus)[/color]" % [hit_enemy.unit_name, dmg, base_dmg, player.dmg_bonus])
				_show_floating_text(hit_enemy.position, "-%d DMG (+%d)" % [dmg, player.dmg_bonus], Color(0.95, 0.85, 0.2))
			else:
				_log("[color=#22c55e]Hero struck %s for %d damage![/color]" % [hit_enemy.unit_name, dmg])
				_show_floating_text(hit_enemy.position, "-%d DMG" % dmg, Color(0.95, 0.85, 0.2))

			# Status Procs & Knockback
			if ability == "slash": hit_enemy.apply_bleed(ability_tier)
			elif ability == "stun": hit_enemy.apply_stun(ability_tier)
			elif ability == "burn": hit_enemy.apply_burn(ability_tier)
			elif ability == "guard": player.guard_armor += (2 + player.get_status_potency_bonus())
			elif ability == "leech":
				var heal = mini(player.max_hp - player.current_hp, 1 + player.get_status_potency_bonus())
				if heal > 0:
					player.current_hp += heal
					if player.hp_bar: player.hp_bar.value = player.current_hp
					_show_floating_text(player.position + Vector2(0, -22), "+%d HP" % heal, Color(0.2, 0.9, 0.3))

			if is_knockback and hit_enemy.is_alive:
				var push_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1, -1), Vector2i(1, 1))
				var pushed_pos = hit_enemy.grid_pos + push_dir
				var r_rect = get_room_rect(current_combat_room_id)
				var is_wall = not is_valid_grid_pos(pushed_pos) or grid[pushed_pos.y][pushed_pos.x] != 0 or (r_rect.size != Vector2i.ZERO and not r_rect.has_point(pushed_pos))
				if is_wall:
					hit_enemy.take_damage(4)
					hit_enemy.set_stunned(true)
					_log("[color=#eab308]💥 WALL SLAM! %s slammed into chamber wall (+4 DMG + STUNNED!)[/color]" % hit_enemy.unit_name)
					_show_floating_text(hit_enemy.position, "WALL SLAM! (STUNNED)", Color(0.98, 0.8, 0.2))
					hit_enemy.animate_bump_back(grid_to_world(hit_enemy.grid_pos))
				else:
					hit_enemy.grid_pos = pushed_pos
					hit_enemy.animate_move_to(grid_to_world(pushed_pos), 0.2)
	else:
		# Empty tile swing
		play_attack_whiff_sfx()
		_log("[color=#94a3b8]Hero struck empty air![/color]")
		_show_floating_text(grid_to_world(hero_attack_tile), "WHIFF!", Color(0.6, 0.7, 0.8))

func _resolve_enemy_strike_simultaneous(enemy: CombatUnit, action: String, target_tile: Vector2i, telegraphed_tiles: Array, start_positions: Dictionary) -> void:
	if action == "enemy_blast":
		play_pyro_flame_sfx()
		_log("[color=#f97316]🔥 %s detonated a Flame Blast![/color]" % enemy.unit_name)
		_spawn_fire_blast_vfx(telegraphed_tiles)
		_shake_camera(5.0, 0.18)
		for b_tile in telegraphed_tiles:
			_spawn_hazard_tile(b_tile)
			if player.grid_pos == b_tile:
				var dmg = 7
				if randf() < (player.get_total_dex() - 10) * 0.015:
					dmg = maxi(1, int(float(dmg) * 0.5))
					_show_floating_text(player.position, "GLANCING DEFLECTION! (-50%)", Color(0.7, 0.85, 1.0))
				var blast_face = {"title": "FLAME BLAST", "damage": dmg, "icon": "res://assets/ui/die_face_fire.svg", "roll": 5}
				await _play_attack_impact_animation(player.position, blast_face, false)
				player.take_damage(dmg, (player.position - grid_to_world(target_tile)).normalized())
				_log("[color=#ef4444]Hero caught in flame blast! (-%d HP)[/color]" % dmg)
				_show_floating_text(player.position, "-%d HP (FIRE)" % dmg, Color(0.95, 0.25, 0.25))
			for other in active_combat_enemies:
				if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == b_tile:
					other.take_damage(7, (other.position - grid_to_world(target_tile)).normalized())
					_show_floating_text(other.position, "-7 HP (FIRE)", Color(0.95, 0.6, 0.1))

	elif action == "enemy_sweep":
		_log("[color=#ef4444]🪓 %s unleashes a WIDE CLEAVE SWEEP![/color]" % enemy.unit_name)
		_spawn_cleave_sweep_vfx(grid_to_world(target_tile), enemy.facing_dir)
		_shake_camera(4.5, 0.16)
		for s_tile in telegraphed_tiles:
			if player.grid_pos == s_tile:
				var dmg = 6
				if randf() < (player.get_total_dex() - 10) * 0.015:
					dmg = maxi(1, int(float(dmg) * 0.5))
					_show_floating_text(player.position, "GLANCING DEFLECTION! (-50%)", Color(0.7, 0.85, 1.0))
				var cleave_face = {"title": "CLEAVE SWEEP", "damage": dmg, "icon": "res://assets/ui/icon_axe.svg", "roll": 5}
				await _play_attack_impact_animation(player.position, cleave_face, false)
				player.take_damage(dmg, (player.position - enemy.position).normalized())
				_log("[color=#ef4444]Hero caught in cleave arc! (-%d HP)[/color]" % dmg)
				_show_floating_text(player.position, "-%d HP" % dmg, Color(0.95, 0.25, 0.25))
			for other in active_combat_enemies:
				if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == s_tile:
					other.take_damage(6, (other.position - enemy.position).normalized())
					_show_floating_text(other.position, "-6 HP", Color(0.95, 0.6, 0.1))

	elif action in ["enemy_attack", "enemy_charge"]:
		var face = enemy.loaded_face if enemy.loaded_face else {"title": "STRIKE", "damage": 4}
		var dmg = face.get("damage", 4) if action != "enemy_charge" else 8
		var e_dir = (grid_to_world(target_tile) - enemy.position).normalized()

		# Check dodge: hero was at target tile at start of beat, but moved away!
		var hero_started_here = (start_positions.get(player, Vector2i(-1,-1)) == target_tile)
		if hero_started_here and player.grid_pos != target_tile:
			_log("[color=#38bdf8]Hero dodged %s's strike by stepping away![/color]" % enemy.unit_name)
			_show_floating_text(player.position, "DODGED!", Color(0.2, 0.8, 0.4))
			play_attack_whiff_sfx()
			return

		if player.grid_pos == target_tile:
			# Dexterity Glancing Blow deflection
			if randf() < (player.get_total_dex() - 10) * 0.015:
				dmg = maxi(1, int(float(dmg) * 0.5))
				_show_floating_text(player.position, "GLANCING DEFLECTION! (-50%)", Color(0.7, 0.85, 1.0))

			_spawn_slash_vfx(player.position, e_dir, Color(0.95, 0.35, 0.35))
			_shake_camera(4.0, 0.15)
			await _play_attack_impact_animation(player.position, face, false)
			var taken = player.take_damage(dmg, e_dir)
			if player.armor > 0 and dmg > taken:
				_log("[color=#ef4444]%s struck Hero for %d damage! (🛡️ %d absorbed by Armor)[/color]" % [enemy.unit_name, taken, dmg - taken])
				_show_floating_text(player.position, "-%d HP (🛡️-%d)" % [taken, dmg - taken], Color(0.95, 0.4, 0.4))
			else:
				_log("[color=#ef4444]%s struck Hero for %d damage![/color]" % [enemy.unit_name, taken])
				_show_floating_text(player.position, "-%d HP" % taken, Color(0.95, 0.25, 0.25))
		else:
			_log("[color=#94a3b8]%s struck empty air! Target was not there.[/color]" % enemy.unit_name)
			_show_floating_text(grid_to_world(target_tile), "WHIFF!", Color(0.6, 0.7, 0.8))

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
	
	_unlock_combat_chamber_doors(current_combat_room_id)
	
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
	# Float cleanly overhead above the target unit so the combat grid and unit remain completely visible!
	var final_impact_pos = target_world_pos + Vector2(0.0, -56.0)
	impact_node.position = final_impact_pos
	impact_node.z_as_relative = false
	impact_node.z_index = 35 # High z-index so it floats above all units and walls
	effects_container.add_child(impact_node)
	
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	
	var dmg = face.get("damage", 0)
	var is_crit = (face.get("roll", 0) == 6 or dmg >= 9)
	var is_miss = (dmg == 0)
	
	if is_blocked:
		p_style.border_color = Color(0.38, 0.74, 0.97)
		p_style.set_border_width_all(2.0)
	elif is_crit:
		p_style.border_color = Color(1.0, 0.4, 0.15)
		p_style.set_border_width_all(2.0)
	elif is_miss:
		p_style.border_color = Color(0.5, 0.55, 0.65)
		p_style.set_border_width_all(1.5)
	else:
		p_style.border_color = Color(0.98, 0.82, 0.2)
		p_style.set_border_width_all(2.0)
		
	panel.add_theme_stylebox_override("panel", p_style)
	impact_node.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	
	var icon = TextureRect.new()
	var icon_path = face.get("icon", "res://assets/ui/die_face_1.svg")
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
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
	title_lbl.add_theme_font_size_override("font_size", 11)
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
	dmg_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(dmg_lbl)
	
	# Center panel over impact_node
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-54, -20)
	
	# Initial pose for slam: scaled small and elevated
	impact_node.scale = Vector2(0.2, 0.2)
	impact_node.position.y -= 15.0
	impact_node.rotation = randf_range(-0.2, 0.2)
	
	var tween = create_tween()
	# Fast punchy pop above target!
	tween.tween_property(impact_node, "scale", Vector2(1.15, 1.15), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact_node, "position:y", final_impact_pos.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact_node, "rotation", 0.0, 0.10)
	
	# Camera shake and dynamic combat sound impact!
	_shake_camera(4.0 if is_crit else (2.0 if is_blocked else 3.0), 0.12)
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
			
	# Hold for readability (snappy 0.18s so it never hangs into planning!)
	await get_tree().create_timer(0.18).timeout
	
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

	# Award EXP based on monster strength
	var exp_gained = 25
	match enemy.unit_type:
		"grunt": exp_gained = 25
		"charger": exp_gained = 35
		"shieldbearer": exp_gained = 45
		"pyromancer": exp_gained = 55
		"brawler": exp_gained = 70
	if "BOSS" in enemy.unit_name.to_upper() or "WARLORD" in enemy.unit_name.to_upper():
		exp_gained = 150

	if player:
		# Award Gold based on monster strength and estate multipliers
		var base_gold = 10
		match enemy.unit_type:
			"grunt": base_gold = randi_range(8, 16)
			"charger": base_gold = randi_range(14, 24)
			"shieldbearer": base_gold = randi_range(18, 30)
			"pyromancer": base_gold = randi_range(22, 34)
			"brawler": base_gold = randi_range(30, 50)
		if "BOSS" in enemy.unit_name.to_upper() or "WARLORD" in enemy.unit_name.to_upper():
			base_gold = randi_range(75, 125)

		var final_gold = int(float(base_gold) * get_estate_gold_mult())
		player.add_gold(final_gold)
		play_gold_sfx()
		_log("[color=#eab308]💰 %s dropped %d Gold (Total: %d Gold)![/color]" % [enemy.unit_name, final_gold, player.gold])
		_show_floating_text(enemy.position + Vector2(0, -42), "+%d Gold 🪙" % final_gold, Color(1.0, 0.84, 0.0))
		_update_gold_ui()

		var leveled_up = player.gain_exp(exp_gained)
		_log("[color=#38bdf8]+%d EXP earned from %s![/color]" % [exp_gained, enemy.unit_name])
		_show_floating_text(enemy.position + Vector2(0, -22), "+%d EXP" % exp_gained, Color(0.38, 0.74, 0.97))
		if leveled_up:
			play_dice_tumble_sfx()
			_show_floating_text(player.position, "LEVEL UP! Lv. %d (+1 Stat Point!)" % player.level, Color(0.98, 0.85, 0.2))
			_log("[color=#facc15][b]🌟 LEVEL UP! You reached Level %d! Unspent Stat Point ready in Backpack [B]![/b][/color]" % player.level)
			_recalculate_equipped_stats()
			if is_backpack_open:
				_render_backpack_ui()

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
