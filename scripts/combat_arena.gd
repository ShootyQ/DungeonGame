class_name CombatArena
extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 42
const GRID_HEIGHT: int = 24
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
var door_container: Node2D
var chest_container: Node2D
var reticle_container: Node2D
var unit_container: Node2D
var fog_container: Node2D
var effects_container: Node2D

# Reticle indicators
var move_indicator: Sprite2D
var attack_indicator: Sprite2D
var danger_indicators: Array[Sprite2D] = []

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
var restart_button: Button

# Player Die HUD
var player_die_icon: TextureRect
var player_die_title: Label
var player_die_desc: Label

# Enemy intel label
var enemy_intel_label: Label
var countdown_overlay: Control
var countdown_number: Label
var countdown_subtitle: Label
var log_label: RichTextLabel

func _ready() -> void:
	randomize()
	_setup_dungeon_layout()
	_create_scene_hierarchy()
	_build_board_visuals()
	_create_doors()
	_create_fog_of_war()
	_spawn_units()
	_setup_hud()
	_enter_exploration_mode()

func _setup_dungeon_layout() -> void:
	grid.clear()
	for y in range(GRID_HEIGHT):
		var row: Array[int] = []
		for x in range(GRID_WIDTH):
			row.append(1) # Default to wall
		grid.append(row)
		
	# 1. Main Central Hallway (x: 1 to 28, y: 11 to 12)
	for y in range(11, 13):
		for x in range(1, 29):
			grid[y][x] = 0
			
	# 2. Room 1: Goblin Den (North-West) x: 3 to 9, y: 3 to 9
	for y in range(3, 10):
		for x in range(3, 10):
			grid[y][x] = 0
	grid[10][6] = 2 # Double Door 1
	grid[10][7] = 2
	
	# 3. Room 2: Crypt of the Phalanx (South-West) x: 3 to 9, y: 14 to 20
	for y in range(14, 21):
		for x in range(3, 10):
			grid[y][x] = 0
	grid[13][6] = 2 # Double Door 2
	grid[13][7] = 2
	
	# 4. Room 3: Pyromancer's Sanctum (North-Mid) x: 16 to 23, y: 3 to 9
	for y in range(3, 10):
		for x in range(16, 24):
			grid[y][x] = 0
	grid[10][19] = 2 # Double Door 3
	grid[10][20] = 2
	
	# 5. Room 4: Brawler's Arena (South-Mid) x: 16 to 23, y: 14 to 20
	for y in range(14, 21):
		for x in range(16, 24):
			grid[y][x] = 0
	grid[13][19] = 2 # Double Door 4
	grid[13][20] = 2
	
	# 6. Room 5: Grand Boss Vault (Far East) x: 29 to 39, y: 7 to 16
	for y in range(7, 17):
		for x in range(29, 40):
			grid[y][x] = 0
	grid[11][28] = 2 # Double Door 5
	grid[12][28] = 2

func _create_scene_hierarchy() -> void:
	# Canvas Background
	var bg = ColorRect.new()
	bg.size = Vector2(GRID_WIDTH * TILE_SIZE + 200, GRID_HEIGHT * TILE_SIZE + 200)
	bg.color = Color(0.04, 0.05, 0.07)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Smooth Scrolling Camera
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	
	board_container = Node2D.new()
	board_container.position = BOARD_OFFSET
	add_child(board_container)
	
	tile_sprites = Node2D.new()
	tile_sprites.z_index = 0
	board_container.add_child(tile_sprites)
	
	hazard_container = Node2D.new()
	hazard_container.z_index = 1
	board_container.add_child(hazard_container)
	
	door_container = Node2D.new()
	door_container.z_index = 2
	board_container.add_child(door_container)
	
	chest_container = Node2D.new()
	chest_container.z_index = 3
	board_container.add_child(chest_container)
	
	reticle_container = Node2D.new()
	reticle_container.z_index = 4
	board_container.add_child(reticle_container)
	
	unit_container = Node2D.new()
	unit_container.z_index = 6
	board_container.add_child(unit_container)
	
	fog_container = Node2D.new()
	fog_container.z_index = 10
	board_container.add_child(fog_container)
	
	effects_container = Node2D.new()
	effects_container.z_index = 15
	board_container.add_child(effects_container)
	
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
	reticle_container.add_child(attack_indicator)

func _build_board_visuals() -> void:
	var floor_tex = load("res://assets/sprites/tile_floor.svg")
	var wall_tex = load("res://assets/sprites/tile_wall.svg")
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var tile_type = grid[y][x]
			var sprite = Sprite2D.new()
			sprite.texture = wall_tex if tile_type == 1 else floor_tex
			sprite.position = Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			tile_sprites.add_child(sprite)

func _create_doors() -> void:
	doors.clear()
	var door_configs = [
		{"pos": Vector2i(6, 10), "room_id": 1},
		{"pos": Vector2i(7, 10), "room_id": 1},
		{"pos": Vector2i(6, 13), "room_id": 2},
		{"pos": Vector2i(7, 13), "room_id": 2},
		{"pos": Vector2i(19, 10), "room_id": 3},
		{"pos": Vector2i(20, 10), "room_id": 3},
		{"pos": Vector2i(19, 13), "room_id": 4},
		{"pos": Vector2i(20, 13), "room_id": 4},
		{"pos": Vector2i(28, 11), "room_id": 5},
		{"pos": Vector2i(28, 12), "room_id": 5}
	]
	
	var door_tex = load("res://assets/sprites/door_closed.svg")
	for cfg in door_configs:
		var sprite = Sprite2D.new()
		sprite.texture = door_tex
		sprite.position = grid_to_world(cfg["pos"])
		door_container.add_child(sprite)
		doors.append({
			"pos": cfg["pos"],
			"room_id": cfg["room_id"],
			"is_open": false,
			"sprite": sprite
		})

func _create_fog_of_war() -> void:
	fog_overlays.clear()
	
	var room_bounds = [
		{"id": 1, "x": 3, "y": 3, "w": 7, "h": 7},
		{"id": 2, "x": 3, "y": 14, "w": 7, "h": 7},
		{"id": 3, "x": 16, "y": 3, "w": 8, "h": 7},
		{"id": 4, "x": 16, "y": 14, "w": 8, "h": 7},
		{"id": 5, "x": 29, "y": 7, "w": 11, "h": 10}
	]
	
	for rb in room_bounds:
		var fog = ColorRect.new()
		fog.position = Vector2(rb["x"] * TILE_SIZE, rb["y"] * TILE_SIZE)
		fog.size = Vector2(rb["w"] * TILE_SIZE, rb["h"] * TILE_SIZE)
		fog.color = Color(0.04, 0.05, 0.07, 0.98)
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_container.add_child(fog)
		fog_overlays[rb["id"]] = fog

func _spawn_units() -> void:
	all_enemies.clear()
	active_combat_enemies.clear()
	
	# Hero (Starts in Entrance of Hallway)
	player = CombatUnit.new()
	unit_container.add_child(player)
	player.setup("Knight", true, 35, load("res://assets/sprites/hero.svg"), Vector2i(2, 11), DieData.create_default_d6_sword())
	player.position = grid_to_world(player.grid_pos)
	player.died.connect(_on_player_died)
	
	# ROOM 1: Goblin Den (1 Charger + 2 Grunts)
	var c1 = _create_enemy("Goblin Charger", 16, "res://assets/sprites/monster_charger.svg", Vector2i(6, 5), 1, "charger")
	var g1 = _create_enemy("Goblin Scout", 12, "res://assets/sprites/monster_goblin.svg", Vector2i(4, 7), 1, "grunt")
	var g2 = _create_enemy("Goblin Scout", 12, "res://assets/sprites/monster_goblin.svg", Vector2i(8, 7), 1, "grunt")
	all_enemies.append_array([c1, g1, g2])
	
	# ROOM 2: Crypt of the Phalanx (1 Skeleton Shieldbearer + 2 Skeleton Grunts)
	var s1 = _create_enemy("Skeleton Shieldbearer", 24, "res://assets/sprites/monster_shieldbearer.svg", Vector2i(6, 17), 2, "shieldbearer")
	s1.facing_dir = Vector2i(0, -1) # Facing North toward Door 2!
	var sk1 = _create_enemy("Skeleton Warrior", 16, "res://assets/sprites/monster_skeleton.svg", Vector2i(4, 18), 2, "grunt")
	var sk2 = _create_enemy("Skeleton Warrior", 16, "res://assets/sprites/monster_skeleton.svg", Vector2i(8, 18), 2, "grunt")
	all_enemies.append_array([s1, sk1, sk2])
	
	# ROOM 3: Pyromancer's Sanctum (1 Cultist Pyromancer + 2 Berserkers)
	var p1 = _create_enemy("Cultist Pyromancer", 18, "res://assets/sprites/monster_pyromancer.svg", Vector2i(20, 5), 3, "pyromancer")
	var b1 = _create_enemy("Goblin Berserker", 15, "res://assets/sprites/monster_goblin.svg", Vector2i(18, 7), 3, "grunt")
	var b2 = _create_enemy("Goblin Berserker", 15, "res://assets/sprites/monster_goblin.svg", Vector2i(22, 7), 3, "grunt")
	all_enemies.append_array([p1, b1, b2])
	
	# ROOM 4: Brawler's Arena (1 Orc Brawler + 1 Charger + 1 Skeleton)
	var ob1 = _create_enemy("Orc Brawler", 28, "res://assets/sprites/monster_orcbrawler.svg", Vector2i(20, 17), 4, "brawler")
	ob1.facing_dir = Vector2i(0, -1)
	var c2 = _create_enemy("Goblin Rusher", 16, "res://assets/sprites/monster_charger.svg", Vector2i(18, 18), 4, "charger")
	var sk3 = _create_enemy("Skeleton Guard", 18, "res://assets/sprites/monster_skeleton.svg", Vector2i(22, 18), 4, "grunt")
	all_enemies.append_array([ob1, c2, sk3])
	
	# ROOM 5: Grand Boss Vault (Orc Warlord + Shieldbearer + Pyromancer + Charger)
	var boss = _create_enemy("Orc Warlord", 38, "res://assets/sprites/monster_orcbrawler.svg", Vector2i(35, 11), 5, "brawler")
	var bs1 = _create_enemy("Phalanx Captain", 26, "res://assets/sprites/monster_shieldbearer.svg", Vector2i(32, 10), 5, "shieldbearer")
	bs1.facing_dir = Vector2i(-1, 0) # Facing West toward Entrance
	var bp1 = _create_enemy("Grand Pyromancer", 22, "res://assets/sprites/monster_pyromancer.svg", Vector2i(37, 13), 5, "pyromancer")
	var bc1 = _create_enemy("Elite Charger", 18, "res://assets/sprites/monster_charger.svg", Vector2i(32, 13), 5, "charger")
	all_enemies.append_array([boss, bs1, bp1, bc1])
	
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
	hud_root.size = Vector2(1280, 720)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(hud_root)
	
	# 1. Exploration Banner (Top)
	explore_banner = PanelContainer.new()
	explore_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	explore_banner.offset_left = 20
	explore_banner.offset_right = -20
	explore_banner.offset_top = 14
	explore_banner.offset_bottom = 60
	var exp_style = StyleBoxFlat.new()
	exp_style.bg_color = Color(0.09, 0.12, 0.18, 0.9)
	exp_style.set_corner_radius_all(6)
	exp_style.content_margin_left = 16
	exp_style.content_margin_right = 16
	explore_banner.add_theme_stylebox_override("panel", exp_style)
	hud_root.add_child(explore_banner)
	
	var exp_hbox = HBoxContainer.new()
	explore_banner.add_child(exp_hbox)
	
	var exp_title = Label.new()
	exp_title.text = "🛡️ EXPLORATION MODE"
	exp_title.add_theme_font_size_override("font_size", 16)
	exp_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.5))
	exp_hbox.add_child(exp_title)
	
	var exp_instr = Label.new()
	exp_instr.text = "  |  Move with [WASD]. Explore hallway & breach 5 dungeon rooms! Watch enemy charges and shields."
	exp_instr.add_theme_font_size_override("font_size", 14)
	exp_instr.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	exp_hbox.add_child(exp_instr)
	
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
	
	# Player Loaded Die in Combat
	player_die_icon = TextureRect.new()
	player_die_icon.custom_minimum_size = Vector2(56, 56)
	player_die_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_die_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	
	telegraph_button = Button.new()
	telegraph_button.text = "👁️ Telegraphs: ON"
	telegraph_button.pressed.connect(_on_toggle_telegraphs)
	btn_hbox.add_child(telegraph_button)
	
	restart_button = Button.new()
	restart_button.text = "🔄 Restart (R)"
	restart_button.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(restart_button)
	
	enemy_intel_label = Label.new()
	enemy_intel_label.text = "Monsters engaged"
	enemy_intel_label.add_theme_font_size_override("font_size", 12)
	enemy_intel_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	action_vbox.add_child(enemy_intel_label)
	
	# 3. Fullscreen Dramatic 3-2-1 Countdown Overlay
	countdown_overlay = Control.new()
	countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.visible = false
	hud_root.add_child(countdown_overlay)
	
	var dim_bg = ColorRect.new()
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0.04, 0.05, 0.08, 0.55)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.add_child(dim_bg)
	
	var count_vbox = VBoxContainer.new()
	count_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	count_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	countdown_overlay.add_child(count_vbox)
	
	countdown_subtitle = Label.new()
	countdown_subtitle.text = "⚠️ ENEMY ENGAGED ⚠️"
	countdown_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_subtitle.add_theme_font_size_override("font_size", 24)
	countdown_subtitle.add_theme_color_override("font_color", Color(0.95, 0.35, 0.2))
	count_vbox.add_child(countdown_subtitle)
	
	countdown_number = Label.new()
	countdown_number.text = "3"
	countdown_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_number.add_theme_font_size_override("font_size", 96)
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

func _process(delta: float) -> void:
	# Smooth Camera Follow
	if player and is_instance_valid(player):
		var target_pos = player.position + BOARD_OFFSET
		camera.position = camera.position.lerp(target_pos, delta * 6.0)
		
	if current_mode == GameMode.EXPLORATION:
		_process_exploration_movement(delta)
	elif current_mode == GameMode.COMBAT_PULSE:
		_process_combat_pulse(delta)

func _process_exploration_movement(delta: float) -> void:
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
	if r_id == 1 or r_id == 3: # North rooms
		return Vector2i(door_pos.x, 8)
	elif r_id == 2 or r_id == 4: # South rooms
		return Vector2i(door_pos.x, 15)
	elif r_id == 5: # East Vault
		return Vector2i(31, door_pos.y)
	return door_pos

func _open_door(door: Dictionary) -> void:
	var r_id = door["room_id"]
	current_combat_room_id = r_id
	
	# Open all door tiles associated with this room (supports double doors)
	for d in doors:
		if d["room_id"] == r_id and not d["is_open"]:
			d["is_open"] = true
			d["sprite"].texture = load("res://assets/sprites/door_open.svg")
			grid[d["pos"].y][d["pos"].x] = 0
			
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
	chest["is_open"] = true
	chest["sprite"].texture = load("res://assets/sprites/chest_open.svg")
	_show_floating_text(grid_to_world(chest["pos"]), "LOOT UNLOCKED!", Color(0.98, 0.85, 0.2))
	
	var reward_type = chest.get("reward", "flame_rune")
	if reward_type == "flame_rune":
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
			_update_hud_display()
			_log("[color=#f97316][b]🔥 TREASURE: Flame Rune! (Face 4 upgraded to 8 DMG + Burn Hazard)[/b][/color]")
	elif reward_type == "shield_basher":
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
			_update_hud_display()
			_log("[color=#38bdf8][b]🛡️ TREASURE: Shield Basher! (Face 2 upgraded to 5 DMG + SHIELD BREAK)[/b][/color]")
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
			_update_hud_display()
			_log("[color=#a855f7][b]🔮 TREASURE: Chaos Shockwave! (Face 3 upgraded to 7 DMG + HEAVY PUSH)[/b][/color]")
	elif reward_type == "executioner_edge":
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
			_update_hud_display()
			_log("[color=#eab308][b]⚡ TREASURE: Executioner's Edge! (Face 1 MISS replaced with 10 DMG + WALL SLAM)[/b][/color]")
	elif reward_type == "dungeon_crown":
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
		countdown_number.text = "3"
		countdown_number.scale = Vector2(1.5, 1.5)
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "2"
		countdown_number.scale = Vector2(1.5, 1.5)
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "1"
		countdown_number.scale = Vector2(1.5, 1.5)
		var t = create_tween()
		t.tween_property(countdown_number, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	count_seq.tween_interval(0.65)
	
	count_seq.tween_callback(func():
		countdown_number.text = "BATTLE!"
		countdown_number.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	)
	count_seq.tween_interval(0.4)
	
	count_seq.tween_callback(func():
		countdown_overlay.visible = false
		_start_combat_pulse_mode()
	)

func _start_combat_pulse_mode() -> void:
	current_mode = GameMode.COMBAT_PULSE
	combat_hud.visible = true
	
	player.roll_next_face()
	for enemy in active_combat_enemies:
		enemy.roll_next_face()
		
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

func _input(event: InputEvent) -> void:
	if current_mode == GameMode.GAME_OVER:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_on_restart_pressed()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_on_restart_pressed()
		elif current_mode == GameMode.COMBAT_PULSE and pulse_state == PulseState.PLANNING:
			if event.keycode == KEY_SPACE:
				_on_commit_pressed()
			elif event.keycode == KEY_T:
				_on_toggle_telegraphs()
				
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

func _handle_combat_left_click(pos: Vector2i) -> void:
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.grid_pos == pos:
			_toggle_attack_target(pos, enemy.unit_name)
			return

	if pos == player.grid_pos:
		player_move_target = Vector2i(-1, -1)
		move_indicator.visible = false
		_log("[color=#94a3b8]Holding position.[/color]")
		return

	if grid[pos.y][pos.x] == 0:
		var diff = (pos - player.grid_pos).abs()
		if diff.x <= 1 and diff.y <= 1:
			if player_move_target == pos:
				player_move_target = Vector2i(-1, -1)
				move_indicator.visible = false
				_log("[color=#94a3b8]Cancelled move.[/color]")
			else:
				player_move_target = pos
				move_indicator.position = grid_to_world(pos)
				move_indicator.visible = true
				_log("[color=#38bdf8]Move target → (%d, %d)[/color]" % [pos.x, pos.y])

func _handle_combat_right_click(pos: Vector2i) -> void:
	_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])

func _toggle_attack_target(pos: Vector2i, label: String) -> void:
	if player_attack_target == pos:
		player_attack_target = Vector2i(-1, -1)
		attack_indicator.visible = false
		_log("[color=#94a3b8]Cancelled strike on %s[/color]" % label)
	else:
		player_attack_target = pos
		attack_indicator.position = grid_to_world(pos)
		attack_indicator.visible = true
		_log("[color=#ef4444]Locked strike on %s[/color]" % label)

func _start_planning_phase() -> void:
	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
		return
		
	pulse_state = PulseState.PLANNING
	pulse_timer = PLANNING_TIME
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	commit_button.disabled = false
	
	player_move_target = Vector2i(-1, -1)
	player_attack_target = Vector2i(-1, -1)
	move_indicator.visible = false
	attack_indicator.visible = false
	
	for ind in danger_indicators:
		if is_instance_valid(ind):
			ind.queue_free()
	danger_indicators.clear()
	
	_plan_enemy_intents()
	_update_hud_display()

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
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
					enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", next_step)
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
				
		# 2. CULTIST PYROMANCER: 3-Tile Cross Flame Blast (Requires direct line of sight without walls!)
		if enemy.unit_type == "pyromancer":
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
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
			
		# 3. ORC BRAWLER: Wide 3-Tile Cleave Sweep
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
				enemy.set_intent("SWEEP", player.grid_pos, valid_sweep)
				continue
			else:
				var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
				if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
					enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
					enemy.set_intent("MOVE", next_step)
				else:
					enemy.set_intent("NONE", enemy.grid_pos)
				continue
			
		# 4. SKELETON SHIELDBEARER & GRUNTS
		if dist_chebyshev <= 1 and has_los:
			enemy.facing_dir = (player.grid_pos - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
			enemy.set_intent("ATTACK", player.grid_pos)
			if show_telegraphs:
				_spawn_danger_indicator(player.grid_pos)
		else:
			var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
			if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
				enemy.facing_dir = (next_step - enemy.grid_pos).clamp(Vector2i(-1,-1), Vector2i(1,1))
				enemy.set_intent("MOVE", next_step)
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
	reticle_container.add_child(danger)
	danger_indicators.append(danger)

func _update_hud_display() -> void:
	var p_face = player.loaded_face
	if not p_face.is_empty():
		player_die_icon.texture = load(p_face["icon"])
		player_die_title.text = "%s (%d DMG)" % [p_face["title"], p_face["damage"]]
		player_die_desc.text = p_face["desc"]
		
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
			var charge_path = enemy.telegraphed_tiles
			var stopped = false
			for t_tile in charge_path:
				if stopped: break
				
				# Check if tile has hero
				if player.grid_pos == t_tile:
					enemy.animate_attack_thrust(grid_to_world(t_tile))
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
							
				if not attack_blocked:
					hit_enemy.take_damage(dmg)
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
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			_log("[color=#f97316]🔥 %s detonated a Flame Blast![/color]" % enemy.unit_name)
			for b_tile in enemy.telegraphed_tiles:
				_spawn_hazard_tile(b_tile)
				if player.grid_pos == b_tile:
					player.take_damage(7)
					_log("[color=#ef4444]Hero caught in flame blast! (-7 HP)[/color]")
					_show_floating_text(player.position, "-7 HP (FIRE)", Color(0.95, 0.25, 0.25))
				# Friendly fire on any other monster in blast!
				for other in active_combat_enemies:
					if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == b_tile:
						other.take_damage(7)
						_log("[color=#f97316]Friendly fire! %s caught in blast (-7 HP)[/color]" % other.unit_name)
						_show_floating_text(other.position, "-7 HP (FIRE)", Color(0.95, 0.6, 0.1))
						
		# ORC BRAWLER SWEEP (3-Tile Arc)
		elif enemy.intent_type == "SWEEP":
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			_log("[color=#ef4444]🪓 %s unleashes a WIDE CLEAVE SWEEP![/color]" % enemy.unit_name)
			for s_tile in enemy.telegraphed_tiles:
				if player.grid_pos == s_tile:
					player.take_damage(6)
					_log("[color=#ef4444]Hero caught in cleave arc! (-6 HP)[/color]")
					_show_floating_text(player.position, "-6 HP", Color(0.95, 0.25, 0.25))
				for other in active_combat_enemies:
					if is_instance_valid(other) and other != enemy and other.is_alive and other.grid_pos == s_tile:
						other.take_damage(6)
						_log("[color=#f97316]Friendly fire! %s caught in cleave (-6 HP)[/color]" % other.unit_name)
						_show_floating_text(other.position, "-6 HP", Color(0.95, 0.6, 0.1))
						
		# STANDARD MELEE STRIKE
		elif enemy.intent_type == "ATTACK":
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			var face = enemy.loaded_face
			var dmg = face.get("damage", 4)
			
			if player.grid_pos == enemy.target_grid_pos:
				player.take_damage(dmg)
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
		
	# STEP 6: DICE RE-ROLL & NEXT PULSE
	player.roll_next_face()
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.roll_next_face()
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
	all_enemies = all_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	
	# Spawn chest for the room that was cleared
	if current_combat_room_id == 1:
		_spawn_treasure_chest(Vector2i(6, 4), "flame_rune")
	elif current_combat_room_id == 2:
		_spawn_treasure_chest(Vector2i(6, 19), "shield_basher")
	elif current_combat_room_id == 3:
		_spawn_treasure_chest(Vector2i(20, 4), "chaos_blast")
	elif current_combat_room_id == 4:
		_spawn_treasure_chest(Vector2i(20, 19), "executioner_edge")
	elif current_combat_room_id == 5:
		_spawn_treasure_chest(Vector2i(38, 11), "dungeon_crown")
		
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
	label.position = world_pos + Vector2(-30, -20)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	effects_container.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -32), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func _on_player_died(_unit: CombatUnit) -> void:
	_game_over()

func _on_enemy_died(enemy: CombatUnit) -> void:
	all_enemies.erase(enemy)
	_log("[color=#fbbf24]💀 %s has been slain![/color]" % enemy.unit_name)
	_show_floating_text(enemy.position, "SLAIN!", Color(0.95, 0.8, 0.1))
	var tween = create_tween()
	tween.tween_property(enemy, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
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
