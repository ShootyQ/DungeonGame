class_name DungeonGenerator
extends RefCounted

const GRID_WIDTH: int = 80
const GRID_HEIGHT: int = 60
const TARGET_ROOMS: int = 20
const MIN_ROOM_SIZE: int = 6
const MAX_ROOM_SIZE: int = 9
const ROOM_PADDING: int = 2 # Minimum wall tiles between rooms

# Biome definitions for thematic rooms
const BIOMES = [
	"goblin", "crypt", "pyro", "brawler", 
	"cistern", "shrine", "armory", "goblin", 
	"crypt", "pyro", "brawler", "cistern",
	"shrine", "armory", "goblin", "crypt",
	"pyro", "brawler", "vault"
]

static func generate() -> Dictionary:
	var grid: Array = []
	for y in range(GRID_HEIGHT):
		var row: Array[int] = []
		for x in range(GRID_WIDTH):
			row.append(1) # Default to solid bedrock wall
		grid.append(row)

	var rooms: Array[Dictionary] = []
	
	# 1. Place Room 0 (Player Entrance Chamber) on Western border
	var r0_w = 8
	var r0_h = 7
	var r0_x = 4
	var r0_y = int(GRID_HEIGHT * 0.5) - int(r0_h * 0.5)
	var r0_rect = Rect2i(r0_x, r0_y, r0_w, r0_h)
	rooms.append({
		"id": 0,
		"rect": r0_rect,
		"center": Vector2i(r0_x + int(r0_w * 0.5), r0_y + int(r0_h * 0.5)),
		"biome": "entrance",
		"name": "Entrance Gateway",
		"door_positions": [],
		"doors": []
	})

	# 2. Place Room TARGET_ROOMS-1 (Grand Boss Throne Room) on Eastern border
	var boss_w = 12
	var boss_h = 10
	var boss_x = GRID_WIDTH - boss_w - 5
	var boss_y = int(GRID_HEIGHT * 0.5) - int(boss_h * 0.5)
	var boss_rect = Rect2i(boss_x, boss_y, boss_w, boss_h)
	
	# 3. Randomly place intermediate rooms
	var attempts = 0
	var max_attempts = 1500
	var desired_rooms = TARGET_ROOMS
	
	# Keep boss room reserved
	var reserved_rects = [r0_rect, boss_rect]
	
	while rooms.size() < desired_rooms - 1 and attempts < max_attempts:
		attempts += 1
		var rw = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var rh = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var rx = randi_range(4, GRID_WIDTH - rw - 5)
		var ry = randi_range(4, GRID_HEIGHT - rh - 5)
		var candidate = Rect2i(rx, ry, rw, rh)
		
		# Check overlap with padding
		var overlaps = false
		var padded_candidate = Rect2i(candidate.position - Vector2i(ROOM_PADDING, ROOM_PADDING), candidate.size + Vector2i(ROOM_PADDING * 2, ROOM_PADDING * 2))
		for r in rooms:
			if padded_candidate.intersects(r["rect"]):
				overlaps = true
				break
		if not overlaps:
			if padded_candidate.intersects(boss_rect):
				overlaps = true
				
		if not overlaps:
			var room_idx = rooms.size()
			var biome_type = BIOMES[(room_idx - 1) % BIOMES.size()]
			var room_name = _get_room_name(biome_type, room_idx)
			rooms.append({
				"id": room_idx,
				"rect": candidate,
				"center": Vector2i(rx + int(rw * 0.5), ry + int(rh * 0.5)),
				"biome": biome_type,
				"name": room_name,
				"door_positions": [],
				"doors": []
			})

	# Add the boss room as the final room
	var boss_id = rooms.size()
	rooms.append({
		"id": boss_id,
		"rect": boss_rect,
		"center": Vector2i(boss_x + int(boss_w * 0.5), boss_y + int(boss_h * 0.5)),
		"biome": "boss",
		"name": "Grand Boss Throne Chamber",
		"door_positions": [],
		"doors": []
	})

	# 4. Carve out room floors into grid
	for r in rooms:
		var rect: Rect2i = r["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				grid[y][x] = 0 # Floor

	# 5. Connect rooms using Minimum Spanning Tree (MST) + Extra Loops
	var edges: Array[Dictionary] = [] # [{a: int, b: int, dist: float}]
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var p1: Vector2i = rooms[i]["center"]
			var p2: Vector2i = rooms[j]["center"]
			var d = abs(p1.x - p2.x) + abs(p1.y - p2.y)
			edges.append({"a": i, "b": j, "dist": d})
			
	edges.sort_custom(func(a, b): return a["dist"] < b["dist"])

	# Kruskal's algorithm for MST
	var parent: Array[int] = []
	for i in range(rooms.size()):
		parent.append(i)

	var mst_edges: Array[Dictionary] = []
	var extra_edges: Array[Dictionary] = []

	for edge in edges:
		var root_a = _find_root(parent, edge["a"])
		var root_b = _find_root(parent, edge["b"])
		if root_a != root_b:
			parent[root_a] = root_b
			mst_edges.append(edge)
		else:
			# Candidate for dungeon loops to avoid pure linear paths
			if edge["dist"] < 35.0 and extra_edges.size() < 6:
				extra_edges.append(edge)

	# Combine MST edges + loop edges
	var active_connections = mst_edges + extra_edges

	var doors: Array[Dictionary] = []
	var placed_door_positions: Dictionary = {} # Vector2i -> int (room_id)

	# Carve 2-tile wide corridors between connected room centers
	for conn in active_connections:
		var c1: Vector2i = rooms[conn["a"]]["center"]
		var c2: Vector2i = rooms[conn["b"]]["center"]
		var h_first = (conn["a"] + conn["b"]) % 2 == 0
		_carve_corridor_with_mode(grid, c1, c2, h_first)

	# 6. Re-carve rooms to ensure clean rectangular boundaries after corridor cuts
	for r in rooms:
		var rect: Rect2i = r["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				grid[y][x] = 0

	# 7. Identify doorway connections on ALL 4 sides of each room
	for r in rooms:
		if r["id"] == 0:
			continue # Room 0 (Entrance) has open archways
			
		var rect: Rect2i = r["rect"]
		
		# Top wall (corridor enters from North)
		var y_top = rect.position.y
		if y_top - 1 >= 0:
			for x in range(rect.position.x, rect.end.x):
				if grid[y_top - 1][x] == 0: # Corridor floor outside top wall
					placed_door_positions[Vector2i(x, y_top)] = r["id"]

		# Bottom wall (corridor enters from South)
		var y_bot = rect.end.y - 1
		if y_bot + 1 < GRID_HEIGHT:
			for x in range(rect.position.x, rect.end.x):
				if grid[y_bot + 1][x] == 0: # Corridor floor outside bottom wall
					placed_door_positions[Vector2i(x, y_bot)] = r["id"]

		# Left wall (corridor enters from West)
		var x_left = rect.position.x
		if x_left - 1 >= 0:
			for y in range(rect.position.y, rect.end.y):
				if grid[y][x_left - 1] == 0: # Corridor floor outside left wall
					placed_door_positions[Vector2i(x_left, y)] = r["id"]

		# Right wall (corridor enters from East)
		var x_right = rect.end.x - 1
		if x_right + 1 < GRID_WIDTH:
			for y in range(rect.position.y, rect.end.y):
				if grid[y][x_right + 1] == 0: # Corridor floor outside right wall
					placed_door_positions[Vector2i(x_right, y)] = r["id"]

	# Apply doors to grid
	for pos in placed_door_positions:
		var rid = placed_door_positions[pos]
		grid[pos.y][pos.x] = 2 # Door
		doors.append({
			"pos": pos,
			"room_id": rid
		})
		for r in rooms:
			if r["id"] == rid:
				r["door_positions"].append(pos)
				break

	# Ensure every hostile room has at least one door
	for r in rooms:
		if r["id"] > 0 and r["door_positions"].is_empty():
			var rect: Rect2i = r["rect"]
			var d1 = Vector2i(rect.position.x, rect.position.y + int(rect.size.y * 0.5))
			var d2 = Vector2i(rect.position.x, d1.y + 1)
			grid[d1.y][d1.x] = 2
			grid[d2.y][d2.x] = 2
			r["door_positions"].append_array([d1, d2])
			doors.append({"pos": d1, "room_id": r["id"]})
			doors.append({"pos": d2, "room_id": r["id"]})

	# 8. Decorate rooms with themed special floors, walls, props, chests & monsters
	var special_floors: Dictionary = {}
	var special_walls: Dictionary = {}
	var props: Array[Dictionary] = []
	var torches: Array[Vector2i] = []
	var chests: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []

	# Place corridor torches every few steps
	for y in range(2, GRID_HEIGHT - 2):
		for x in range(2, GRID_WIDTH - 2):
			if grid[y][x] == 0:
				# Check if this is in a corridor (not inside any room)
				var in_room = false
				for r in rooms:
					if r["rect"].has_point(Vector2i(x, y)):
						in_room = true
						break
				if not in_room:
					# Wall north of this corridor floor
					if grid[y - 1][x] == 1 and (x % 6 == 0):
						torches.append(Vector2i(x, y - 1))
					# Puddle or drain in corridor occasionally
					var ch = (x * 37 + y * 19) % 100
					if ch < 5:
						special_floors[Vector2i(x, y)] = "puddle"
					elif ch < 9:
						special_floors[Vector2i(x, y)] = "drain"
					elif ch < 14:
						special_floors[Vector2i(x, y)] = "cracked"
					elif ch < 18:
						special_floors[Vector2i(x, y)] = "rubble"

	# Populate each room based on its biome
	for r in rooms:
		var rect: Rect2i = r["rect"]
		var biome = r["biome"]
		var r_id = r["id"]
		var center: Vector2i = r["center"]

		# Place room perimeter torches & wall alcoves
		torches.append(Vector2i(rect.position.x + 2, rect.position.y))
		torches.append(Vector2i(rect.end.x - 3, rect.position.y))
		if rect.size.y > 7:
			torches.append(Vector2i(rect.position.x + 2, rect.end.y - 1))
			torches.append(Vector2i(rect.end.x - 3, rect.end.y - 1))

		# Wall alcoves & wall chains
		if biome in ["shrine", "crypt", "boss"]:
			special_walls[Vector2i(center.x, rect.position.y)] = "alcove"
		elif biome in ["brawler", "goblin", "vault"]:
			special_walls[Vector2i(center.x, rect.position.y)] = "chains"

		# Pillars
		if rect.size.x >= 8 and rect.size.y >= 8 and biome in ["boss", "crypt", "shrine", "vault"]:
			props.append({"type": "pillar", "pos": Vector2i(rect.position.x + 2, rect.position.y + 2), "offset": Vector2.ZERO})
			props.append({"type": "pillar", "pos": Vector2i(rect.end.x - 3, rect.position.y + 2), "offset": Vector2.ZERO})
			props.append({"type": "pillar", "pos": Vector2i(rect.position.x + 2, rect.end.y - 3), "offset": Vector2.ZERO})
			props.append({"type": "pillar", "pos": Vector2i(rect.end.x - 3, rect.end.y - 3), "offset": Vector2.ZERO})

		# Cobwebs in corners
		props.append({"type": "web", "pos": Vector2i(rect.position.x + 1, rect.position.y + 1), "offset": Vector2(-12, -12)})
		if randf() < 0.5:
			props.append({"type": "web", "pos": Vector2i(rect.end.x - 2, rect.position.y + 1), "offset": Vector2(12, -12)})

		# Crates & barrels
		if biome in ["goblin", "entrance", "armory", "cistern"]:
			props.append({"type": "crates", "pos": Vector2i(rect.end.x - 2, rect.end.y - 2), "offset": Vector2.ZERO})
			if randf() < 0.5:
				props.append({"type": "crates", "pos": Vector2i(rect.position.x + 1, rect.end.y - 2), "offset": Vector2.ZERO})

		# Floor patterns per biome
		match biome:
			"entrance":
				# Safe room: clean stone, entrance supplies
				special_floors[center] = "ornate"
			"goblin":
				for i in range(3):
					var p = _rand_inner_tile(rect)
					special_floors[p] = "bones" if i % 2 == 0 else "rubble"
				# Enemies
				enemies.append({"name": "Goblin Charger", "hp": 16, "tex": "res://assets/sprites/monster_charger.svg", "pos": center, "room_id": r_id, "type": "charger", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Goblin Scout", "hp": 12, "tex": "res://assets/sprites/monster_goblin.svg", "pos": center + Vector2i(-1, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Goblin Scout", "hp": 12, "tex": "res://assets/sprites/monster_goblin.svg", "pos": center + Vector2i(1, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"crypt":
				for i in range(4):
					var p = _rand_inner_tile(rect)
					special_floors[p] = "bones" if i % 2 == 0 else "moss"
				# Enemies
				enemies.append({"name": "Skeleton Shieldbearer", "hp": 24, "tex": "res://assets/sprites/monster_shieldbearer.svg", "pos": center, "room_id": r_id, "type": "shieldbearer", "facing": Vector2i(0, -1)})
				enemies.append({"name": "Skeleton Warrior", "hp": 16, "tex": "res://assets/sprites/monster_skeleton.svg", "pos": center + Vector2i(-2, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Skeleton Warrior", "hp": 16, "tex": "res://assets/sprites/monster_skeleton.svg", "pos": center + Vector2i(2, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"pyro":
				special_floors[center] = "runic"
				special_floors[center + Vector2i(1, 0)] = "sigil"
				special_floors[center + Vector2i(-1, 0)] = "sigil"
				special_floors[center + Vector2i(0, 1)] = "cracked"
				special_floors[center + Vector2i(0, -1)] = "cracked"
				# Enemies
				enemies.append({"name": "Cultist Pyromancer", "hp": 20, "tex": "res://assets/sprites/monster_pyromancer.svg", "pos": center, "room_id": r_id, "type": "pyromancer", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Goblin Berserker", "hp": 15, "tex": "res://assets/sprites/monster_goblin.svg", "pos": center + Vector2i(-2, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Goblin Berserker", "hp": 15, "tex": "res://assets/sprites/monster_goblin.svg", "pos": center + Vector2i(2, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"brawler":
				for i in range(3):
					var p = _rand_inner_tile(rect)
					special_floors[p] = "blood"
				special_floors[center] = "cracked"
				# Enemies
				enemies.append({"name": "Orc Brawler", "hp": 28, "tex": "res://assets/sprites/monster_orcbrawler.svg", "pos": center, "room_id": r_id, "type": "brawler", "facing": Vector2i(0, -1)})
				enemies.append({"name": "Goblin Rusher", "hp": 16, "tex": "res://assets/sprites/monster_charger.svg", "pos": center + Vector2i(-1, 1), "room_id": r_id, "type": "charger", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Skeleton Guard", "hp": 18, "tex": "res://assets/sprites/monster_skeleton.svg", "pos": center + Vector2i(1, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"cistern":
				for i in range(4):
					var p = _rand_inner_tile(rect)
					special_floors[p] = "puddle"
				special_floors[center] = "drain"
				# Enemies
				enemies.append({"name": "Sunken Charger", "hp": 18, "tex": "res://assets/sprites/monster_charger.svg", "pos": center, "room_id": r_id, "type": "charger", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Damp Skeleton", "hp": 16, "tex": "res://assets/sprites/monster_skeleton.svg", "pos": center + Vector2i(-1, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"shrine":
				special_floors[center] = "runic"
				special_floors[center + Vector2i(1, 0)] = "ornate"
				special_floors[center + Vector2i(-1, 0)] = "ornate"
				# Enemies
				enemies.append({"name": "Shrine Guardian", "hp": 26, "tex": "res://assets/sprites/monster_shieldbearer.svg", "pos": center, "room_id": r_id, "type": "shieldbearer", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Acolyte Pyromancer", "hp": 18, "tex": "res://assets/sprites/monster_pyromancer.svg", "pos": center + Vector2i(0, 2), "room_id": r_id, "type": "pyromancer", "facing": Vector2i(0, 1)})
			"armory":
				for i in range(3):
					var p = _rand_inner_tile(rect)
					special_floors[p] = "ornate" if i == 0 else "cracked"
				# Enemies
				enemies.append({"name": "Orc Armorer", "hp": 26, "tex": "res://assets/sprites/monster_orcbrawler.svg", "pos": center, "room_id": r_id, "type": "brawler", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Goblin Sentry", "hp": 14, "tex": "res://assets/sprites/monster_goblin.svg", "pos": center + Vector2i(-1, 1), "room_id": r_id, "type": "grunt", "facing": Vector2i(0, 1)})
			"vault":
				special_floors[center] = "ornate"
				for i in range(3):
					special_floors[_rand_inner_tile(rect)] = "ornate"
				# Enemies
				enemies.append({"name": "Vault Warden", "hp": 30, "tex": "res://assets/sprites/monster_shieldbearer.svg", "pos": center, "room_id": r_id, "type": "shieldbearer", "facing": Vector2i(0, 1)})
				enemies.append({"name": "Vault Pyromancer", "hp": 20, "tex": "res://assets/sprites/monster_pyromancer.svg", "pos": center + Vector2i(1, 2), "room_id": r_id, "type": "pyromancer", "facing": Vector2i(0, 1)})
			"boss":
				# Grand Throne Room
				special_floors[center] = "runic"
				special_floors[center + Vector2i(1, 0)] = "ornate"
				special_floors[center + Vector2i(-1, 0)] = "ornate"
				special_floors[center + Vector2i(0, 1)] = "blood"
				special_floors[center + Vector2i(0, -1)] = "blood"
				special_floors[center + Vector2i(2, 0)] = "sigil"
				special_floors[center + Vector2i(-2, 0)] = "sigil"
				# Boss & Royal Guard
				enemies.append({"name": "Orc Warlord", "hp": 42, "tex": "res://assets/sprites/monster_orcbrawler.svg", "pos": center, "room_id": r_id, "type": "brawler", "facing": Vector2i(-1, 0)})
				enemies.append({"name": "Phalanx Captain", "hp": 28, "tex": "res://assets/sprites/monster_shieldbearer.svg", "pos": center + Vector2i(-3, -1), "room_id": r_id, "type": "shieldbearer", "facing": Vector2i(-1, 0)})
				enemies.append({"name": "Grand Pyromancer", "hp": 24, "tex": "res://assets/sprites/monster_pyromancer.svg", "pos": center + Vector2i(2, 2), "room_id": r_id, "type": "pyromancer", "facing": Vector2i(-1, 0)})
				enemies.append({"name": "Elite Charger", "hp": 20, "tex": "res://assets/sprites/monster_charger.svg", "pos": center + Vector2i(-3, 2), "room_id": r_id, "type": "charger", "facing": Vector2i(-1, 0)})

	var player_spawn = rooms[0]["center"]

	return {
		"grid": grid,
		"rooms": rooms,
		"player_spawn": player_spawn,
		"doors": doors,
		"chests": chests,
		"enemies": enemies,
		"props": props,
		"torches": torches,
		"special_floors": special_floors,
		"special_walls": special_walls
	}

static func _find_root(parent: Array[int], i: int) -> int:
	var root = i
	while root != parent[root]:
		root = parent[root]
	var curr = i
	while curr != root:
		var nxt = parent[curr]
		parent[curr] = root
		curr = nxt
	return root

static func _carve_corridor_with_mode(grid: Array, p1: Vector2i, p2: Vector2i, h_first: bool) -> void:
	if h_first:
		# Horizontal from p1.x to p2.x at p1.y
		_carve_horiz(grid, p1.x, p2.x, p1.y)
		# Vertical from p1.y to p2.y at p2.x
		_carve_vert(grid, p1.y, p2.y, p2.x)
	else:
		# Vertical from p1.y to p2.y at p1.x
		_carve_vert(grid, p1.y, p2.y, p1.x)
		# Horizontal from p1.x to p2.x at p2.y
		_carve_horiz(grid, p1.x, p2.x, p2.y)

static func _find_corridor_exit_tiles(rect: Rect2i, start: Vector2i, target: Vector2i, starts_horiz: bool, _is_first: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if starts_horiz:
		var step_x = 1 if target.x >= start.x else -1
		var x = start.x
		var last_x = start.x
		while rect.has_point(Vector2i(x, start.y)):
			last_x = x
			x += step_x
		var y1 = clampi(start.y, rect.position.y, rect.end.y - 1)
		var y2 = clampi(start.y + 1, rect.position.y, rect.end.y - 1)
		result.append(Vector2i(last_x, y1))
		if y2 != y1:
			result.append(Vector2i(last_x, y2))
	else:
		var step_y = 1 if target.y >= start.y else -1
		var y = start.y
		var last_y = start.y
		while rect.has_point(Vector2i(start.x, y)):
			last_y = y
			y += step_y
		var x1 = clampi(start.x, rect.position.x, rect.end.x - 1)
		var x2 = clampi(start.x + 1, rect.position.x, rect.end.x - 1)
		result.append(Vector2i(x1, last_y))
		if x2 != x1:
			result.append(Vector2i(x2, last_y))
	return result

static func _carve_corridor(grid: Array, p1: Vector2i, p2: Vector2i) -> void:
	# L-shaped corridor: horizontal first then vertical (or vice versa based on coin toss)
	var h_first = randf() < 0.5
	if h_first:
		# Horizontal from p1.x to p2.x at p1.y
		_carve_horiz(grid, p1.x, p2.x, p1.y)
		# Vertical from p1.y to p2.y at p2.x
		_carve_vert(grid, p1.y, p2.y, p2.x)
	else:
		# Vertical from p1.y to p2.y at p1.x
		_carve_vert(grid, p1.y, p2.y, p1.x)
		# Horizontal from p1.x to p2.x at p2.y
		_carve_horiz(grid, p1.x, p2.x, p2.y)

static func _carve_horiz(grid: Array, x1: int, x2: int, y: int) -> void:
	var start_x = mini(x1, x2)
	var end_x = maxi(x1, x2)
	for x in range(start_x, end_x + 1):
		if x >= 1 and x < GRID_WIDTH - 1:
			if y >= 1 and y < GRID_HEIGHT - 2:
				grid[y][x] = 0
				grid[y + 1][x] = 0 # 2-tile wide corridor!

static func _carve_vert(grid: Array, y1: int, y2: int, x: int) -> void:
	var start_y = mini(y1, y2)
	var end_y = maxi(y1, y2)
	for y in range(start_y, end_y + 1):
		if y >= 1 and y < GRID_HEIGHT - 1:
			if x >= 1 and x < GRID_WIDTH - 2:
				grid[y][x] = 0
				grid[y][x + 1] = 0 # 2-tile wide corridor!

static func _rand_inner_tile(rect: Rect2i) -> Vector2i:
	return Vector2i(
		randi_range(rect.position.x + 1, rect.end.x - 2),
		randi_range(rect.position.y + 1, rect.end.y - 2)
	)

static func _get_room_name(biome: String, idx: int) -> String:
	match biome:
		"goblin": return "Goblin Den %d" % idx
		"crypt": return "Crypt of the Phalanx %d" % idx
		"pyro": return "Pyromancer's Sanctum %d" % idx
		"brawler": return "Brawler's Arena %d" % idx
		"cistern": return "Sunken Cistern %d" % idx
		"shrine": return "Sacred Relic Shrine %d" % idx
		"armory": return "Forgotten Armory %d" % idx
		"vault": return "Treasure Vault %d" % idx
		"boss": return "Grand Boss Throne Chamber"
		_: return "Chamber %d" % idx
