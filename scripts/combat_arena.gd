class_name CombatArena
extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 10
const BOARD_OFFSET: Vector2 = Vector2(48, 40)

enum PulseState { PLANNING, RESOLVING, GAME_OVER }
var current_state: PulseState = PulseState.PLANNING

const PLANNING_TIME: float = 3.0
var pulse_timer: float = PLANNING_TIME
var show_telegraphs: bool = true

# Units
var player: CombatUnit
var enemies: Array[CombatUnit] = []

# Player planned intents
var player_move_target: Vector2i = Vector2i(-1, -1)
var player_attack_target: Vector2i = Vector2i(-1, -1)

# Grid representation
# 0 = floor, 1 = wall
var grid: Array = []

# Node references
var board_container: Node2D
var tile_sprites: Node2D
var reticle_container: Node2D
var unit_container: Node2D
var effects_container: Node2D

# Reticle indicators
var move_indicator: Sprite2D
var attack_indicator: Sprite2D
var danger_indicators: Array[Sprite2D] = []

# UI references
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

# Enemy Die HUD container
var enemy_hud_vbox: VBoxContainer
var log_label: RichTextLabel

func _ready() -> void:
	randomize()
	_setup_grid_data()
	_create_scene_hierarchy()
	_build_board_visuals()
	_spawn_units()
	_setup_hud()
	_start_planning_phase()

func _setup_grid_data() -> void:
	grid.clear()
	for y in range(GRID_HEIGHT):
		var row: Array[int] = []
		for x in range(GRID_WIDTH):
			# Border walls
			if x == 0 or x == GRID_WIDTH - 1 or y == 0 or y == GRID_HEIGHT - 1:
				row.append(1)
			# An inner pillar or two for tactical cover
			elif (x == 4 and y == 4) or (x == 5 and y == 5):
				row.append(1)
			else:
				row.append(0)
		grid.append(row)

func _create_scene_hierarchy() -> void:
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.07, 0.08, 0.11)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	board_container = Node2D.new()
	board_container.position = BOARD_OFFSET
	add_child(board_container)
	
	tile_sprites = Node2D.new()
	board_container.add_child(tile_sprites)
	
	reticle_container = Node2D.new()
	board_container.add_child(reticle_container)
	
	unit_container = Node2D.new()
	board_container.add_child(unit_container)
	
	effects_container = Node2D.new()
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
			var sprite = Sprite2D.new()
			var is_wall = (grid[y][x] == 1)
			sprite.texture = wall_tex if is_wall else floor_tex
			sprite.position = Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			tile_sprites.add_child(sprite)

func _spawn_units() -> void:
	# Hero
	player = CombatUnit.new()
	unit_container.add_child(player)
	player.setup("Knight", true, 25, load("res://assets/sprites/hero.svg"), Vector2i(2, 5), DieData.create_default_d6_sword())
	player.position = grid_to_world(player.grid_pos)
	player.died.connect(_on_player_died)
	
	# Goblin
	var goblin = CombatUnit.new()
	unit_container.add_child(goblin)
	goblin.setup("Goblin Skulker", false, 12, load("res://assets/sprites/monster_goblin.svg"), Vector2i(7, 3), DieData.create_default_d6_sword())
	goblin.position = grid_to_world(goblin.grid_pos)
	goblin.died.connect(_on_enemy_died)
	enemies.append(goblin)
	
	# Skeleton
	var skeleton = CombatUnit.new()
	unit_container.add_child(skeleton)
	skeleton.setup("Skeleton Guard", false, 16, load("res://assets/sprites/monster_skeleton.svg"), Vector2i(7, 6), DieData.create_default_d6_sword())
	skeleton.position = grid_to_world(skeleton.grid_pos)
	skeleton.died.connect(_on_enemy_died)
	enemies.append(skeleton)

func _setup_hud() -> void:
	var hud_root = Control.new()
	hud_root.position = Vector2(720, 30)
	hud_root.size = Vector2(520, 660)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	hud_root.add_child(vbox)
	
	# 1. Pulse Header Card
	var pulse_panel = PanelContainer.new()
	var pulse_style = StyleBoxFlat.new()
	pulse_style.bg_color = Color(0.11, 0.13, 0.18, 0.95)
	pulse_style.set_corner_radius_all(8)
	pulse_style.content_margin_left = 16
	pulse_style.content_margin_right = 16
	pulse_style.content_margin_top = 12
	pulse_style.content_margin_bottom = 12
	pulse_panel.add_theme_stylebox_override("panel", pulse_style)
	vbox.add_child(pulse_panel)
	
	var pulse_vbox = VBoxContainer.new()
	pulse_vbox.add_theme_constant_override("separation", 6)
	pulse_panel.add_child(pulse_vbox)
	
	var header_hbox = HBoxContainer.new()
	pulse_vbox.add_child(header_hbox)
	
	phase_title = Label.new()
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_font_size_override("font_size", 18)
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	header_hbox.add_child(phase_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	timer_label = Label.new()
	timer_label.text = "3.0s"
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.add_theme_color_override("font_color", Color(0.98, 0.75, 0.18))
	header_hbox.add_child(timer_label)
	
	timer_bar = ProgressBar.new()
	timer_bar.min_value = 0.0
	timer_bar.max_value = PLANNING_TIME
	timer_bar.value = PLANNING_TIME
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 10)
	var timer_fill = StyleBoxFlat.new()
	timer_fill.bg_color = Color(0.2, 0.8, 0.4)
	timer_fill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	pulse_vbox.add_child(timer_bar)
	
	# 2. Player Loaded Die Card
	var die_panel = PanelContainer.new()
	var die_style = StyleBoxFlat.new()
	die_style.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	die_style.border_color = Color(0.22, 0.74, 0.97)
	die_style.set_border_width_all(2)
	die_style.set_corner_radius_all(8)
	die_style.content_margin_left = 16
	die_style.content_margin_right = 16
	die_style.content_margin_top = 10
	die_style.content_margin_bottom = 10
	die_panel.add_theme_stylebox_override("panel", die_style)
	vbox.add_child(die_panel)
	
	var die_hbox = HBoxContainer.new()
	die_hbox.add_theme_constant_override("separation", 16)
	die_panel.add_child(die_hbox)
	
	player_die_icon = TextureRect.new()
	player_die_icon.custom_minimum_size = Vector2(64, 64)
	player_die_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_die_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	die_hbox.add_child(player_die_icon)
	
	var die_info_vbox = VBoxContainer.new()
	die_hbox.add_child(die_info_vbox)
	
	var die_header = Label.new()
	die_header.text = "YOUR PRE-LOADED DIE (D6 Sword)"
	die_header.add_theme_font_size_override("font_size", 12)
	die_header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	die_info_vbox.add_child(die_header)
	
	player_die_title = Label.new()
	player_die_title.text = "SLASH (4 Damage)"
	player_die_title.add_theme_font_size_override("font_size", 18)
	player_die_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	die_info_vbox.add_child(player_die_title)
	
	player_die_desc = Label.new()
	player_die_desc.text = "Next attack uses this loaded face!"
	player_die_desc.add_theme_font_size_override("font_size", 13)
	player_die_desc.add_theme_color_override("font_color", Color(0.4, 0.8, 0.6))
	die_info_vbox.add_child(player_die_desc)
	
	# 3. Enemy Intel Section
	var enemy_panel = PanelContainer.new()
	var enemy_style = StyleBoxFlat.new()
	enemy_style.bg_color = Color(0.11, 0.13, 0.18, 0.9)
	enemy_style.set_corner_radius_all(8)
	enemy_style.content_margin_left = 12
	enemy_style.content_margin_right = 12
	enemy_style.content_margin_top = 8
	enemy_style.content_margin_bottom = 8
	enemy_panel.add_theme_stylebox_override("panel", enemy_style)
	vbox.add_child(enemy_panel)
	
	var enemy_main_vbox = VBoxContainer.new()
	enemy_panel.add_child(enemy_main_vbox)
	
	var enemy_sec_title = Label.new()
	enemy_sec_title.text = "ENEMY THREAT INTEL"
	enemy_sec_title.add_theme_font_size_override("font_size", 12)
	enemy_sec_title.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	enemy_main_vbox.add_child(enemy_sec_title)
	
	enemy_hud_vbox = VBoxContainer.new()
	enemy_hud_vbox.add_theme_constant_override("separation", 6)
	enemy_main_vbox.add_child(enemy_hud_vbox)
	
	# 4. Buttons Row
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	commit_button = Button.new()
	commit_button.text = "⚡ COMMIT INTENT (SPACE)"
	commit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_button.custom_minimum_size = Vector2(0, 38)
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
	
	# 5. Combat Log
	var log_panel = PanelContainer.new()
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	log_style.set_corner_radius_all(6)
	log_style.content_margin_left = 12
	log_style.content_margin_right = 12
	log_style.content_margin_top = 8
	log_style.content_margin_bottom = 8
	log_panel.add_theme_stylebox_override("panel", log_style)
	vbox.add_child(log_panel)
	
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, 150)
	log_label.text = "[color=#38bdf8]Pulse Combat initialized.[/color]\n[color=#94a3b8]• Left-click floor to set Move.\n• Left-click enemy to set Attack.\n• Space to Commit early.[/color]\n"
	log_panel.add_child(log_label)

func _process(delta: float) -> void:
	if current_state == PulseState.PLANNING:
		pulse_timer -= delta
		timer_bar.value = max(0.0, pulse_timer)
		timer_label.text = "%.1fs" % max(0.0, pulse_timer)
		
		# Color change on timer
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
	if current_state == PulseState.GAME_OVER:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_on_restart_pressed()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and current_state == PulseState.PLANNING:
			_on_commit_pressed()
		elif event.keycode == KEY_T:
			_on_toggle_telegraphs()
		elif event.keycode == KEY_R:
			_on_restart_pressed()
			
	if current_state == PulseState.PLANNING and event is InputEventMouseButton and event.pressed:
		var local_mouse = board_container.get_local_mouse_position()
		# Only handle clicks inside the board dimensions
		if local_mouse.x >= 0 and local_mouse.x < GRID_WIDTH * TILE_SIZE and local_mouse.y >= 0 and local_mouse.y < GRID_HEIGHT * TILE_SIZE:
			var clicked_grid = world_to_grid(local_mouse)
			if is_valid_grid_pos(clicked_grid):
				if event.button_index == MOUSE_BUTTON_LEFT:
					_handle_grid_left_click(clicked_grid)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_handle_grid_right_click(clicked_grid)

func _handle_grid_left_click(pos: Vector2i) -> void:
	# 1. Check if clicked directly on an enemy
	for enemy in enemies:
		if enemy.grid_pos == pos:
			_toggle_attack_target(pos, enemy.unit_name)
			return

	# 2. If clicked on player's own tile: cancel movement (hold ground)
	if pos == player.grid_pos:
		player_move_target = Vector2i(-1, -1)
		move_indicator.visible = false
		_log("[color=#94a3b8]Holding ground at current position.[/color]")
		return

	# 3. If clicked on an adjacent walkable floor tile: set movement intent
	if grid[pos.y][pos.x] == 0:
		var dist = (pos - player.grid_pos).abs()
		if dist.x <= 1 and dist.y <= 1:
			if player_move_target == pos:
				player_move_target = Vector2i(-1, -1)
				move_indicator.visible = false
				_log("[color=#94a3b8]Cancelled movement.[/color]")
			else:
				player_move_target = pos
				move_indicator.position = grid_to_world(pos)
				move_indicator.visible = true
				_log("[color=#38bdf8]Set move intent → (%d, %d)[/color]" % [pos.x, pos.y])

func _handle_grid_right_click(pos: Vector2i) -> void:
	# Right click targets any tile for attack (predictive strike)
	_toggle_attack_target(pos, "tile (%d, %d)" % [pos.x, pos.y])

func _toggle_attack_target(pos: Vector2i, label: String) -> void:
	if player_attack_target == pos:
		player_attack_target = Vector2i(-1, -1)
		attack_indicator.visible = false
		_log("[color=#94a3b8]Cancelled attack on %s[/color]" % label)
	else:
		player_attack_target = pos
		attack_indicator.position = grid_to_world(pos)
		attack_indicator.visible = true
		_log("[color=#ef4444]Locked attack target → %s[/color]" % label)

func _start_planning_phase() -> void:
	if enemies.is_empty():
		_game_won()
		return
		
	current_state = PulseState.PLANNING
	pulse_timer = PLANNING_TIME
	phase_title.text = "⚡ PULSE: PLANNING (3.0s)"
	phase_title.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	commit_button.disabled = false
	
	# Reset player choices
	player_move_target = Vector2i(-1, -1)
	player_attack_target = Vector2i(-1, -1)
	move_indicator.visible = false
	attack_indicator.visible = false
	
	# Clear danger overlays
	for ind in danger_indicators:
		ind.queue_free()
	danger_indicators.clear()
	
	# Compute Enemy Intents
	_plan_enemy_intents()
	
	# Update HUD displays
	_update_hud_display()

func _plan_enemy_intents() -> void:
	for enemy in enemies:
		var diff = player.grid_pos - enemy.grid_pos
		var dist_manhattan = abs(diff.x) + abs(diff.y)
		var dist_chebyshev = max(abs(diff.x), abs(diff.y))
		
		# If adjacent to player, attack player's tile!
		if dist_chebyshev == 1:
			enemy.set_intent("ATTACK", player.grid_pos)
			if show_telegraphs:
				_spawn_danger_indicator(player.grid_pos)
		else:
			# Move 1 step towards player
			var step_x = 0
			var step_y = 0
			if diff.x != 0:
				step_x = 1 if diff.x > 0 else -1
			if diff.y != 0:
				step_y = 1 if diff.y > 0 else -1
				
			# Prefer horizontal or vertical step if both exist
			var candidate_pos = enemy.grid_pos + Vector2i(step_x, 0)
			if step_x == 0 or grid[candidate_pos.y][candidate_pos.x] != 0 or _is_tile_occupied(candidate_pos):
				candidate_pos = enemy.grid_pos + Vector2i(0, step_y)
				
			if is_valid_grid_pos(candidate_pos) and grid[candidate_pos.y][candidate_pos.x] == 0:
				enemy.set_intent("MOVE", candidate_pos)
			else:
				enemy.set_intent("NONE", enemy.grid_pos)

func _is_tile_occupied(pos: Vector2i) -> bool:
	if player.grid_pos == pos:
		return true
	for enemy in enemies:
		if enemy.grid_pos == pos:
			return true
	return false

func _spawn_danger_indicator(pos: Vector2i) -> void:
	var danger = Sprite2D.new()
	danger.texture = load("res://assets/ui/danger_tile.svg")
	danger.position = grid_to_world(pos)
	reticle_container.add_child(danger)
	danger_indicators.append(danger)

func _update_hud_display() -> void:
	# Player loaded face
	var p_face = player.loaded_face
	if not p_face.is_empty():
		player_die_icon.texture = load(p_face["icon"])
		player_die_title.text = "%s (%d DMG)" % [p_face["title"], p_face["damage"]]
		player_die_desc.text = p_face["desc"]
		
	# Clear & populate enemy cards
	for child in enemy_hud_vbox.get_children():
		child.queue_free()
		
	for enemy in enemies:
		var card = HBoxContainer.new()
		card.add_theme_constant_override("separation", 10)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not enemy.loaded_face.is_empty():
			icon.texture = load(enemy.loaded_face["icon"])
		card.add_child(icon)
		
		var lbl = Label.new()
		var intent_str = "Attacking your tile!" if enemy.intent_type == "ATTACK" else ("Advancing" if enemy.intent_type == "MOVE" else "Waiting")
		lbl.text = "%s (HP %d/%d) → %s [%s]" % [enemy.unit_name, enemy.current_hp, enemy.max_hp, intent_str, enemy.loaded_face.get("title", "")]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7) if enemy.intent_type == "ATTACK" else Color(0.8, 0.8, 0.8))
		card.add_child(lbl)
		
		enemy_hud_vbox.add_child(card)

func _resolve_pulse() -> void:
	current_state = PulseState.RESOLVING
	commit_button.disabled = true
	phase_title.text = "💥 PULSE: RESOLVING ACTION!"
	phase_title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	
	# Determine intended moves
	var planned_player_pos = player_move_target if player_move_target != Vector2i(-1, -1) else player.grid_pos
	
	# STEP 1: MOVEMENT PHASE (0.4s)
	_log("[b]▶ RESOLUTION: Movement Phase[/b]")
	
	# Check for clashes (two units moving to same tile)
	var move_destinations = {}
	move_destinations[player] = planned_player_pos
	
	for enemy in enemies:
		var e_dest = enemy.target_grid_pos if enemy.intent_type == "MOVE" else enemy.grid_pos
		move_destinations[enemy] = e_dest
		
	# Execute moves
	for unit in move_destinations.keys():
		var dest = move_destinations[unit]
		if dest != unit.grid_pos:
			# Check if another unit also moving to dest
			var clash = false
			for other_unit in move_destinations.keys():
				if other_unit != unit and move_destinations[other_unit] == dest:
					clash = true
					break
					
			if clash:
				_log("[color=#f59e0b]⚡ Clash on tile (%d, %d)! Units stumbled back.[/color]" % [dest.x, dest.y])
				_show_floating_text(grid_to_world(dest), "CLASH!", Color(0.95, 0.7, 0.1))
				unit.animate_bump_back(grid_to_world(unit.grid_pos))
			else:
				unit.grid_pos = dest
				unit.animate_move_to(grid_to_world(dest))
				
	await get_tree().create_timer(0.4).timeout
	
	# STEP 2: ATTACK PHASE (0.4s)
	_log("[b]▶ RESOLUTION: Attack Phase[/b]")
	
	# Player Attack
	if player_attack_target != Vector2i(-1, -1):
		player.animate_attack_thrust(grid_to_world(player_attack_target))
		var face = player.loaded_face
		var dmg = face.get("damage", 0)
		var is_crit = face.get("knockback", false)
		
		# Find enemy at target tile
		var hit_enemy: CombatUnit = null
		for enemy in enemies:
			if enemy.grid_pos == player_attack_target:
				hit_enemy = enemy
				break
				
		if hit_enemy:
			if dmg == 0:
				_log("[color=#94a3b8]Hero rolled MISS! Stumbled with rusty blade.[/color]")
				_show_floating_text(hit_enemy.position, "MISS!", Color(0.6, 0.6, 0.6))
			else:
				hit_enemy.take_damage(dmg)
				var crit_tag = " (CRIT + PUSH!)" if is_crit else ""
				_log("[color=#22c55e]Hero struck %s for %d damage!%s[/color]" % [hit_enemy.unit_name, dmg, crit_tag])
				_show_floating_text(hit_enemy.position, "-%d DMG%s" % [dmg, "!" if is_crit else ""], Color(0.95, 0.2, 0.2) if is_crit else Color(0.95, 0.85, 0.2))
				
				if is_crit:
					# Push enemy back 1 tile
					var push_dir = (hit_enemy.grid_pos - player.grid_pos).clamp(Vector2i(-1, -1), Vector2i(1, 1))
					var pushed_pos = hit_enemy.grid_pos + push_dir
					if is_valid_grid_pos(pushed_pos) and grid[pushed_pos.y][pushed_pos.x] == 0:
						hit_enemy.grid_pos = pushed_pos
						hit_enemy.animate_move_to(grid_to_world(pushed_pos), 0.2)
		else:
			_log("[color=#94a3b8]Hero struck empty air! Target dodged away.[/color]")
			_show_floating_text(grid_to_world(player_attack_target), "WHIFF!", Color(0.6, 0.7, 0.8))
			
	# Enemy Attacks
	for enemy in enemies:
		if enemy.intent_type == "ATTACK":
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
				_log("[color=#38bdf8]Hero dodged %s's attack![/color]" % enemy.unit_name)
				_show_floating_text(player.position, "DODGED!", Color(0.2, 0.8, 0.4))
				
	await get_tree().create_timer(0.4).timeout
	
	# STEP 3: DICE RE-ROLL STEP (0.2s)
	player.roll_next_face()
	for enemy in enemies:
		enemy.roll_next_face()
		enemy.clear_intent()
		
	# Clean up dead enemies
	enemies = enemies.filter(func(e): return e.current_hp > 0)
	
	if player.current_hp <= 0:
		_game_over()
	elif enemies.is_empty():
		_game_won()
	else:
		_start_planning_phase()

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
	tween.tween_callback(enemy.queue_free)

func _game_won() -> void:
	current_state = PulseState.GAME_OVER
	phase_title.text = "🏆 VICTORY! ROOM CLEARED"
	phase_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	_log("[color=#22c55e][b]VICTORY! All enemies vanquished. Press R to replay wave.[/b][/color]")

func _game_over() -> void:
	current_state = PulseState.GAME_OVER
	phase_title.text = "💀 DEFEAT! YOU PERISHED"
	phase_title.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	_log("[color=#ef4444][b]DEFEAT! The dungeon claimed your soul. Press R to restart.[/b][/color]")

func _on_commit_pressed() -> void:
	if current_state == PulseState.PLANNING:
		_resolve_pulse()

func _on_toggle_telegraphs() -> void:
	show_telegraphs = !show_telegraphs
	telegraph_button.text = "👁️ Telegraphs: ON" if show_telegraphs else "👁️ Telegraphs: OFF"
	for danger in danger_indicators:
		danger.visible = show_telegraphs
	_log("[color=#94a3b8]Telegraphs %s[/color]" % ("enabled" if show_telegraphs else "disabled (hidden intents)"))

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
