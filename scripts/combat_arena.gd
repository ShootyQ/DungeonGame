class_name CombatArena
extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 11
const BOARD_OFFSET: Vector2 = Vector2(0, 8)

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

# Player planned intents in combat
var player_move_target: Vector2i = Vector2i(-1, -1)
var player_attack_target: Vector2i = Vector2i(-1, -1)

# Grid data: 0 = floor, 1 = wall, 2 = door
var grid: Array = []
var doors: Array[Dictionary] = [] # [{pos, room_id, is_open, sprite}]
var fog_overlays: Dictionary = {} # room_id -> ColorRect
var chests: Array[Dictionary] = [] # [{pos, is_open, sprite}]

# Node references
var board_container: Node2D
var tile_sprites: Node2D
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

# UI references
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
		
	# 1. Hallway Floor (x: 1 to 18, y: 7 to 8)
	for y in range(7, 9):
		for x in range(1, 19):
			grid[y][x] = 0
			
	# 2. Room 1 (West Chamber): Floor x: 2 to 8, y: 2 to 5
	for y in range(2, 6):
		for x in range(2, 9):
			grid[y][x] = 0
			
	# Door 1 at (5, 6)
	grid[6][5] = 2
	
	# 3. Room 2 (East Crypt): Floor x: 12 to 17, y: 2 to 5
	for y in range(2, 6):
		for x in range(12, 18):
			grid[y][x] = 0
			
	# Door 2 at (14, 6)
	grid[6][14] = 2

func _create_scene_hierarchy() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.06, 0.07, 0.09)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	board_container = Node2D.new()
	board_container.position = BOARD_OFFSET
	add_child(board_container)
	
	tile_sprites = Node2D.new()
	tile_sprites.z_index = 0
	board_container.add_child(tile_sprites)
	
	door_container = Node2D.new()
	door_container.z_index = 1
	board_container.add_child(door_container)
	
	chest_container = Node2D.new()
	chest_container.z_index = 2
	board_container.add_child(chest_container)
	
	reticle_container = Node2D.new()
	reticle_container.z_index = 3
	board_container.add_child(reticle_container)
	
	unit_container = Node2D.new()
	unit_container.z_index = 5
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
		{"pos": Vector2i(5, 6), "room_id": 1},
		{"pos": Vector2i(14, 6), "room_id": 2}
	]
	
	var closed_tex = load("res://assets/sprites/door_closed.svg")
	for config in door_configs:
		var pos = config["pos"]
		var sprite = Sprite2D.new()
		sprite.texture = closed_tex
		sprite.position = grid_to_world(pos)
		door_container.add_child(sprite)
		
		doors.append({
			"pos": pos,
			"room_id": config["room_id"],
			"is_open": false,
			"sprite": sprite
		})

func _create_fog_of_war() -> void:
	fog_overlays.clear()
	
	# Room 1 Fog: x: 2 to 8, y: 2 to 5
	var r1_fog = ColorRect.new()
	r1_fog.position = Vector2(2 * TILE_SIZE, 2 * TILE_SIZE)
	r1_fog.size = Vector2(7 * TILE_SIZE, 4 * TILE_SIZE)
	r1_fog.color = Color(0.04, 0.05, 0.07, 0.98)
	r1_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_container.add_child(r1_fog)
	fog_overlays[1] = r1_fog
	
	# Room 2 Fog: x: 12 to 17, y: 2 to 5
	var r2_fog = ColorRect.new()
	r2_fog.position = Vector2(12 * TILE_SIZE, 2 * TILE_SIZE)
	r2_fog.size = Vector2(6 * TILE_SIZE, 4 * TILE_SIZE)
	r2_fog.color = Color(0.04, 0.05, 0.07, 0.98)
	r2_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_container.add_child(r2_fog)
	fog_overlays[2] = r2_fog

func _spawn_units() -> void:
	all_enemies.clear()
	active_combat_enemies.clear()
	
	# Hero (Starts in Hallway)
	player = CombatUnit.new()
	unit_container.add_child(player)
	player.setup("Knight", true, 30, load("res://assets/sprites/hero.svg"), Vector2i(2, 7), DieData.create_default_d6_sword())
	player.position = grid_to_world(player.grid_pos)
	player.died.connect(_on_player_died)
	
	# Room 1 Enemies (2 Monsters: 1 Goblin, 1 Skeleton)
	var gob1 = _create_enemy("Goblin Scout", 14, "res://assets/sprites/monster_goblin.svg", Vector2i(4, 3), 1)
	var skel1 = _create_enemy("Skeleton Warrior", 18, "res://assets/sprites/monster_skeleton.svg", Vector2i(6, 4), 1)
	all_enemies.append_array([gob1, skel1])
	
	# Room 2 Enemies (3 Monsters: Skeleton Guard right in direct line with Door 2 + 2 Goblins flanking)
	var skel2 = _create_enemy("Skeleton Guard", 22, "res://assets/sprites/monster_skeleton.svg", Vector2i(14, 4), 2)
	var gob2 = _create_enemy("Goblin Berserker", 16, "res://assets/sprites/monster_goblin.svg", Vector2i(13, 3), 2)
	var gob3 = _create_enemy("Goblin Sneak", 14, "res://assets/sprites/monster_goblin.svg", Vector2i(16, 3), 2)
	all_enemies.append_array([skel2, gob2, gob3])
	
	# All enemies remain active inside their rooms (completely hidden by the Fog of War overlays above them)
	for enemy in all_enemies:
		enemy.visible = true
		enemy.is_active_in_combat = false

func _create_enemy(p_name: String, hp: int, tex_path: String, pos: Vector2i, p_room_id: int) -> CombatUnit:
	var enemy = CombatUnit.new()
	unit_container.add_child(enemy)
	enemy.setup(p_name, false, hp, load(tex_path), pos, DieData.create_default_d6_sword())
	enemy.position = grid_to_world(pos)
	enemy.room_id = p_room_id
	enemy.died.connect(_on_enemy_died)
	return enemy

func _setup_hud() -> void:
	hud_root = Control.new()
	hud_root.size = Vector2(1280, 720)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	
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
	exp_instr.text = "  |  Move with [W, A, S, D] or Arrows. Walk into closed doors to breach rooms!"
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
	enemy_intel_label.text = "Monsters engaged: 2"
	enemy_intel_label.add_theme_font_size_override("font_size", 11)
	enemy_intel_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	action_vbox.add_child(enemy_intel_label)
	
	# 3. Dramatic Fullscreen Countdown Overlay
	countdown_overlay = Control.new()
	countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.visible = false
	hud_root.add_child(countdown_overlay)
	
	var count_vbox = VBoxContainer.new()
	count_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	count_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	countdown_overlay.add_child(count_vbox)
	
	countdown_subtitle = Label.new()
	countdown_subtitle.text = "⚔️ COMBAT ENGAGED!"
	countdown_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_subtitle.add_theme_font_size_override("font_size", 32)
	countdown_subtitle.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	count_vbox.add_child(countdown_subtitle)
	
	countdown_number = Label.new()
	countdown_number.text = "3"
	countdown_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_number.add_theme_font_size_override("font_size", 64)
	countdown_number.add_theme_color_override("font_color", Color(0.98, 0.85, 0.2))
	count_vbox.add_child(countdown_number)
	
	# 4. Compact Bottom Combat Log
	var log_panel = PanelContainer.new()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	log_panel.offset_left = 20
	log_panel.offset_right = -20
	log_panel.offset_top = -68
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
	log_label.text = "[color=#38bdf8]Dungeon loaded.[/color] [color=#94a3b8]Walk through hallway with WASD and breach doors.[/color]\n"
	log_panel.add_child(log_label)

func _process(delta: float) -> void:
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
		var speed = 190.0
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
						
	# Check proximity to doors
	for door in doors:
		if not door["is_open"]:
			var d_world = grid_to_world(door["pos"])
			if player.position.distance_to(d_world) < 60.0:
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

func _open_door(door: Dictionary) -> void:
	door["is_open"] = true
	door["sprite"].texture = load("res://assets/sprites/door_open.svg")
	grid[door["pos"].y][door["pos"].x] = 0 # Doorway is now walkable floor
	
	var r_id = door["room_id"]
	_log("[color=#f59e0b]🚪 Door breached! Room %d revealed![/color]" % r_id)
	
	# Fade Fog of War
	if fog_overlays.has(r_id):
		var fog = fog_overlays[r_id]
		var tween = create_tween()
		tween.tween_property(fog, "modulate:a", 0.0, 0.5)
		tween.tween_callback(fog.queue_free)
		fog_overlays.erase(r_id)
		
	# Find and activate living monsters in this room
	var engaged_monsters: Array[CombatUnit] = []
	for enemy in all_enemies:
		if enemy.room_id == r_id and is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0:
			enemy.is_active_in_combat = true
			engaged_monsters.append(enemy)
			# Alert indicator
			_show_floating_text(enemy.position, "!", Color(0.95, 0.2, 0.2))
			
	if not engaged_monsters.is_empty():
		_start_combat_countdown(engaged_monsters)

func _open_chest(chest: Dictionary) -> void:
	chest["is_open"] = true
	chest["sprite"].texture = load("res://assets/sprites/chest_open.svg")
	_show_floating_text(grid_to_world(chest["pos"]), "LOOT UNLOCKED!", Color(0.98, 0.85, 0.2))
	
	# Reward: Modify D6 Sword! Add Flaming Rune face
	if player and player.die and not player.die.faces.is_empty():
		var fire_face = {
			"roll": 4,
			"title": "FLAME RUNE",
			"desc": "8 Damage + Burn!",
			"damage": 8,
			"knockback": false,
			"icon": "res://assets/ui/die_face_fire.svg"
		}
		player.die.faces[3] = fire_face # Replace face 4 with Flaming Rune!
		player.loaded_face = fire_face
		_update_hud_display()
		_log("[color=#f97316][b]🔥 TREASURE FOUND: Flame Rune etched into your D6 Sword! (Face 4 replaced with 8 DMG + BURN)[/b][/color]")

func _start_combat_countdown(engaged_monsters: Array[CombatUnit]) -> void:
	current_mode = GameMode.COMBAT_COUNTDOWN
	active_combat_enemies = engaged_monsters
	
	# Smoothly snap player to nearest grid tile
	var snap_target = grid_to_world(world_to_grid(player.position))
	var snap_tween = create_tween()
	snap_tween.tween_property(player, "position", snap_target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	player.grid_pos = world_to_grid(snap_target)
	
	explore_banner.visible = false
	countdown_overlay.visible = true
	
	_log("[color=#ef4444][b]⚔️ COMBAT STARTING IN 3... 2... 1...[/b][/color]")
	
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
	explore_banner.visible = true
	combat_hud.visible = false
	countdown_overlay.visible = false
	
	move_indicator.visible = false
	attack_indicator.visible = false
	for danger in danger_indicators:
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
				
	# Board clicks in combat mode
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
		ind.queue_free()
	danger_indicators.clear()
	
	_plan_enemy_intents()
	_update_hud_display()

func _plan_enemy_intents() -> void:
	for enemy in active_combat_enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
			
		var diff = (player.grid_pos - enemy.grid_pos).abs()
		var dist_chebyshev = max(diff.x, diff.y)
		
		if dist_chebyshev <= 1:
			enemy.set_intent("ATTACK", player.grid_pos)
			if show_telegraphs:
				_spawn_danger_indicator(player.grid_pos)
		else:
			var next_step = _find_smart_path_step(enemy.grid_pos, player.grid_pos, enemy)
			if next_step != enemy.grid_pos and is_valid_grid_pos(next_step) and grid[next_step.y][next_step.x] == 0:
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
				
	for other in active_combat_enemies:
		if is_instance_valid(other) and other != current_unit and other.is_alive and other.current_hp > 0:
			blocked[other.grid_pos] = true
			if other.intent_type == "MOVE":
				blocked[other.target_grid_pos] = true

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
					if d.x != 0 and d.y != 0:
						if grid[curr.y][neighbor.x] != 0 and grid[neighbor.y][curr.x] != 0:
							continue
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
			var act = "⚔️ Attack" if enemy.intent_type == "ATTACK" else "👟 Advance"
			monster_info.append("%s [%s, HP %d]" % [enemy.unit_name, act, enemy.current_hp])
	enemy_intel_label.text = "Threats: " + " | ".join(monster_info)

func _resolve_pulse() -> void:
	pulse_state = PulseState.RESOLVING
	commit_button.disabled = true
	phase_title.text = "💥 PULSE: RESOLVING ACTION!"
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
	
	# STEP 2: ATTACK PHASE (0.35s)
	_log("[b]▶ ATTACK PHASE[/b]")
	if player_attack_target != Vector2i(-1, -1):
		player.animate_attack_thrust(grid_to_world(player_attack_target))
		var face = player.loaded_face
		var dmg = face.get("damage", 0)
		var is_crit = face.get("knockback", false)
		
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
				hit_enemy.take_damage(dmg)
				var crit_tag = " (CRIT + PUSH!)" if is_crit else ""
				_log("[color=#22c55e]Hero struck %s for %d damage!%s[/color]" % [hit_enemy.unit_name, dmg, crit_tag])
				_show_floating_text(hit_enemy.position, "-%d DMG%s" % [dmg, "!" if is_crit else ""], Color(0.95, 0.2, 0.2) if is_crit else Color(0.95, 0.85, 0.2))
				
				if is_crit and hit_enemy.is_alive:
					var push_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1, -1), Vector2i(1, 1))
					var pushed_pos = hit_enemy.grid_pos + push_dir
					if is_valid_grid_pos(pushed_pos) and grid[pushed_pos.y][pushed_pos.x] == 0:
						hit_enemy.grid_pos = pushed_pos
						hit_enemy.animate_move_to(grid_to_world(pushed_pos), 0.2)
		else:
			_log("[color=#94a3b8]Hero struck empty air! Target dodged.[/color]")
			_show_floating_text(grid_to_world(player_attack_target), "WHIFF!", Color(0.6, 0.7, 0.8))
			
	active_combat_enemies = active_combat_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive and e.current_hp > 0)
	if active_combat_enemies.is_empty():
		_on_active_room_cleared()
		return
		
	# Enemy Attacks
	for enemy in active_combat_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.intent_type == "ATTACK":
			enemy.animate_attack_thrust(grid_to_world(enemy.target_grid_pos))
			var face = enemy.loaded_face
			var dmg = face.get("damage", 0)
			
			if player.grid_pos == enemy.target_grid_pos:
				if dmg == 0:
					_log("[color=#94a3b8]%s rolled MISS![/color]" % enemy.unit_name)
					_show_floating_text(player.position, "BLOCKED!", Color(0.3, 0.8, 0.9))
				else:
					player.take_damage(dmg)
					_log("[color=#ef4444]%s hit Hero for %d damage![/color]" % [enemy.unit_name, dmg])
					_show_floating_text(player.position, "-%d HP" % dmg, Color(0.95, 0.25, 0.25))
			else:
				_log("[color=#38bdf8]Hero dodged %s's strike![/color]" % enemy.unit_name)
				_show_floating_text(player.position, "DODGED!", Color(0.2, 0.8, 0.4))
				
	await get_tree().create_timer(0.35).timeout
	
	if player.current_hp <= 0:
		_game_over()
		return
		
	# STEP 3: DICE RE-ROLL STEP
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

func _on_active_room_cleared() -> void:
	var any_remaining = false
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.is_alive and enemy.current_hp > 0:
			any_remaining = true
			break
			
	if not any_remaining:
		# Spawn final reward chest in Room 2!
		_spawn_treasure_chest(Vector2i(15, 3))
		_game_conquered()
	else:
		# Spawn chest in Room 1!
		_spawn_treasure_chest(Vector2i(5, 3))
		_log("[color=#22c55e][b]🏆 ROOM CLEARED! A treasure chest has appeared! Returning to Exploration mode...[/b][/color]")
		_show_floating_text(player.position, "ROOM CLEARED!", Color(0.2, 0.9, 0.4))
		var t = create_tween()
		t.tween_interval(1.0)
		t.tween_callback(_enter_exploration_mode)

func _spawn_treasure_chest(pos: Vector2i) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/chest_closed.svg")
	sprite.position = grid_to_world(pos)
	chest_container.add_child(sprite)
	
	# Spawn bounce animation
	sprite.scale = Vector2(0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	chests.append({
		"pos": pos,
		"is_open": false,
		"sprite": sprite
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
	_log("[color=#22c55e][b]🎉 VICTORY! All rooms purged. The dungeon is conquered! Walk up to the golden chest to claim your relic![/b][/color]")
	# Allow walking to the chest in exploration
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
