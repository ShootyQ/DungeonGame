class_name DieData
extends RefCounted

var name: String = "D6 Sword"
var icon_path: String = "res://assets/sprites/sword_d6.svg"
var die_type: String = "d6"
var faces: Array = []

static func create_default_d6_sword() -> DieData:
	var die = DieData.new()
	die.name = "D6 Adventurer Sword"
	die.icon_path = "res://assets/items/item_sword_starter.svg"
	die.die_type = "d6"
	die.faces = [
		{
			"roll": 1,
			"title": "STRIKE",
			"desc": "1 Damage",
			"damage": 1,
			"knockback": false,
			"icon": "res://assets/ui/die_face_1.svg"
		},
		{
			"roll": 2,
			"title": "LIGHT SLASH",
			"desc": "2 Damage",
			"damage": 2,
			"knockback": false,
			"icon": "res://assets/ui/die_face_2.svg"
		},
		{
			"roll": 3,
			"title": "SLASH",
			"desc": "3 Damage",
			"damage": 3,
			"knockback": false,
			"icon": "res://assets/ui/die_face_3.svg"
		},
		{
			"roll": 4,
			"title": "HEAVY SLASH",
			"desc": "4 Damage",
			"damage": 4,
			"knockback": false,
			"icon": "res://assets/ui/die_face_4.svg"
		},
		{
			"roll": 5,
			"title": "CRUSH",
			"desc": "5 Damage",
			"damage": 5,
			"knockback": false,
			"icon": "res://assets/ui/die_face_5.svg"
		},
		{
			"roll": 6,
			"title": "CRITICAL",
			"desc": "6 Damage",
			"damage": 6,
			"knockback": false,
			"icon": "res://assets/ui/die_face_6.svg"
		}
	]
	return die

static func create_executioner_axe() -> DieData:
	var die = DieData.new()
	die.name = "Executioner's Greataxe"
	die.icon_path = "res://assets/items/item_executioner.svg"
	die.die_type = "d6"
	die.faces = [
		{
			"roll": 1,
			"title": "MISS",
			"desc": "Heavy swing misses! 0 DMG",
			"damage": 0,
			"knockback": false,
			"icon": "res://assets/ui/die_face_1.svg"
		},
		{
			"roll": 2,
			"title": "CHOP",
			"desc": "3 Damage",
			"damage": 3,
			"knockback": false,
			"icon": "res://assets/ui/die_face_2.svg"
		},
		{
			"roll": 3,
			"title": "CLEAVE",
			"desc": "4 Damage",
			"damage": 4,
			"knockback": false,
			"icon": "res://assets/ui/die_face_3.svg"
		},
		{
			"roll": 4,
			"title": "HEAVY CHOP",
			"desc": "6 Damage + Stagger",
			"damage": 6,
			"knockback": false,
			"icon": "res://assets/ui/die_face_4.svg"
		},
		{
			"roll": 5,
			"title": "CRUSH",
			"desc": "7 Damage + Push",
			"damage": 7,
			"knockback": true,
			"icon": "res://assets/ui/die_face_5.svg"
		},
		{
			"roll": 6,
			"title": "EXECUTE",
			"desc": "12 Damage + Wall Slam!",
			"damage": 12,
			"knockback": true,
			"icon": "res://assets/ui/die_face_6.svg"
		}
	]
	return die

static func create_pyromancer_wand() -> DieData:
	var die = DieData.new()
	die.name = "Pyromancer's Flame Wand"
	die.icon_path = "res://assets/ui/icon_wand.svg"
	die.die_type = "d6"
	die.faces = [
		{
			"roll": 1,
			"title": "MISCAST",
			"desc": "Fizzle! 1 Singe Damage",
			"damage": 1,
			"knockback": false,
			"icon": "res://assets/ui/die_face_1.svg"
		},
		{
			"roll": 2,
			"title": "SPARK",
			"desc": "3 Fire Damage",
			"damage": 3,
			"knockback": false,
			"icon": "res://assets/ui/die_face_2.svg"
		},
		{
			"roll": 3,
			"title": "FIREBOLT",
			"desc": "5 Fire Damage",
			"damage": 5,
			"knockback": false,
			"icon": "res://assets/ui/die_face_3.svg"
		},
		{
			"roll": 4,
			"title": "FLAME RUNE",
			"desc": "7 Damage + Burn Hazard!",
			"damage": 7,
			"knockback": false,
			"icon": "res://assets/ui/die_face_fire.svg"
		},
		{
			"roll": 5,
			"title": "IGNITE",
			"desc": "8 Damage + Burn Hazard!",
			"damage": 8,
			"knockback": false,
			"icon": "res://assets/ui/die_face_fire.svg"
		},
		{
			"roll": 6,
			"title": "PYROBLAST",
			"desc": "11 Damage + Shockwave!",
			"damage": 11,
			"knockback": true,
			"icon": "res://assets/ui/die_face_6.svg"
		}
	]
	return die

static func create_warhammer() -> DieData:
	var die = DieData.new()
	die.name = "Phalanx Warhammer"
	die.icon_path = "res://assets/items/item_warhammer.svg"
	die.die_type = "d6"
	die.faces = [
		{
			"roll": 1,
			"title": "GLANCE",
			"desc": "Glancing Blow! 1 Damage",
			"damage": 1,
			"knockback": false,
			"icon": "res://assets/ui/die_face_1.svg"
		},
		{
			"roll": 2,
			"title": "BASH",
			"desc": "3 Damage + Shatters Shield!",
			"damage": 3,
			"knockback": true,
			"icon": "res://assets/ui/die_face_2.svg"
		},
		{
			"roll": 3,
			"title": "BASH",
			"desc": "4 Damage + Shatters Shield!",
			"damage": 4,
			"knockback": true,
			"icon": "res://assets/ui/die_face_3.svg"
		},
		{
			"roll": 4,
			"title": "HAMMER CRUSH",
			"desc": "6 Damage + Push",
			"damage": 6,
			"knockback": true,
			"icon": "res://assets/ui/die_face_4.svg"
		},
		{
			"roll": 5,
			"title": "SHIELD BREAKER",
			"desc": "7 Damage + Wall Slam!",
			"damage": 7,
			"knockback": true,
			"icon": "res://assets/ui/die_face_5.svg"
		},
		{
			"roll": 6,
			"title": "CONCUSSION",
			"desc": "10 Damage + Stuns Target!",
			"damage": 10,
			"knockback": true,
			"icon": "res://assets/ui/die_face_6.svg"
		}
	]
	return die

static func create_swift_dagger() -> DieData:
	var die = DieData.new()
	die.name = "Swift Stiletto"
	die.icon_path = "res://assets/items/item_dagger.svg"
	die.die_type = "d6"
	die.faces = [
		{"roll": 1, "title": "GLANCE", "desc": "1 Quick Poke DMG", "damage": 1, "knockback": false, "icon": "res://assets/ui/die_face_1.svg"},
		{"roll": 2, "title": "STAB", "desc": "3 Fast Piercing DMG", "damage": 3, "knockback": false, "icon": "res://assets/ui/die_face_2.svg"},
		{"roll": 3, "title": "FLURRY", "desc": "4 Double Strike DMG", "damage": 4, "knockback": false, "icon": "res://assets/ui/die_face_3.svg"},
		{"roll": 4, "title": "RUPTURE", "desc": "5 Deep Arterial DMG", "damage": 5, "knockback": false, "icon": "res://assets/ui/die_face_4.svg"},
		{"roll": 5, "title": "BACKSTAB", "desc": "7 Critical Puncture DMG", "damage": 7, "knockback": false, "icon": "res://assets/ui/die_face_5.svg"},
		{"roll": 6, "title": "ASSASSINATE", "desc": "11 Lethal Execution DMG", "damage": 11, "knockback": false, "icon": "res://assets/ui/die_face_6.svg"}
	]
	return die

static func create_spiked_morningstar() -> DieData:
	var die = DieData.new()
	die.name = "Spiked Morningstar"
	die.icon_path = "res://assets/items/item_spikes.svg"
	die.die_type = "d6"
	die.faces = [
		{"roll": 1, "title": "GRAZE", "desc": "1 Chain Scrape DMG", "damage": 1, "knockback": false, "icon": "res://assets/ui/die_face_1.svg"},
		{"roll": 2, "title": "SWING", "desc": "3 Blunt Impact DMG", "damage": 3, "knockback": false, "icon": "res://assets/ui/die_face_2.svg"},
		{"roll": 3, "title": "PUNCTURE", "desc": "5 Heavy Spike DMG", "damage": 5, "knockback": false, "icon": "res://assets/ui/die_face_3.svg"},
		{"roll": 4, "title": "FLAIL SMASH", "desc": "6 Crushing DMG + Push", "damage": 6, "knockback": true, "icon": "res://assets/ui/die_face_4.svg"},
		{"roll": 5, "title": "SKULL CRACK", "desc": "8 Staggering DMG + Push", "damage": 8, "knockback": true, "icon": "res://assets/ui/die_face_5.svg"},
		{"roll": 6, "title": "DEVASTATION", "desc": "12 Brutal Smash + Slam!", "damage": 12, "knockback": true, "icon": "res://assets/ui/die_face_6.svg"}
	]
	return die

static func create_chaos_staff() -> DieData:
	var die = DieData.new()
	die.name = "Chaos Blast Staff"
	die.icon_path = "res://assets/items/item_chaos_staff.svg"
	die.die_type = "d6"
	die.faces = [
		{"roll": 1, "title": "SURGE", "desc": "2 Chaotic Spark DMG", "damage": 2, "knockback": false, "icon": "res://assets/ui/die_face_1.svg"},
		{"roll": 2, "title": "VOID BOLT", "desc": "4 Nether Pulse DMG", "damage": 4, "knockback": false, "icon": "res://assets/ui/die_face_2.svg"},
		{"roll": 3, "title": "ARCANE BLAST", "desc": "6 Sorcerous Burst DMG", "damage": 6, "knockback": false, "icon": "res://assets/ui/die_face_3.svg"},
		{"roll": 4, "title": "GRAVITY CRUSH", "desc": "7 Void Rip + Push", "damage": 7, "knockback": true, "icon": "res://assets/ui/die_face_4.svg"},
		{"roll": 5, "title": "CHAOS NOVA", "desc": "9 Void Rupture + Knockback", "damage": 9, "knockback": true, "icon": "res://assets/ui/die_face_fire.svg"},
		{"roll": 6, "title": "BLACK HOLE", "desc": "14 Singularity Collapse!", "damage": 14, "knockback": true, "icon": "res://assets/ui/die_face_6.svg"}
	]
	return die

static func generate_random_face(floor_depth: int = 1) -> Dictionary:
	# 1. Roll Value based on weighted depth curve
	var val = 1
	var r_val = randf()
	if floor_depth <= 5:
		if r_val < 0.25: val = 1
		elif r_val < 0.60: val = 2
		elif r_val < 0.85: val = 3
		elif r_val < 0.96: val = 4
		else: val = 5
	elif floor_depth <= 12:
		if r_val < 0.15: val = 2
		elif r_val < 0.45: val = 3
		elif r_val < 0.75: val = 4
		elif r_val < 0.92: val = 5
		elif r_val < 0.98: val = 6
		else: val = 8 # Rare Jackpot!
	else:
		if r_val < 0.15: val = 3
		elif r_val < 0.45: val = 4
		elif r_val < 0.72: val = 5
		elif r_val < 0.90: val = 6
		elif r_val < 0.97: val = 8
		else: val = 10 # Legendary Jackpot!

	# 2. Roll Ability Affix (40% chance)
	var abilities = [
		{"type": "slash", "tier": 1, "desc": "+1 Bleed on pulse"},
		{"type": "slash", "tier": 2, "desc": "+2 Bleed over 2 pulses"},
		{"type": "stun", "tier": 1, "desc": "Stuns enemy for 1 pulse"},
		{"type": "stun", "tier": 2, "desc": "Stuns enemy for 2 pulses"},
		{"type": "pierce", "tier": 1, "desc": "Bypasses enemy Armor"},
		{"type": "push", "tier": 1, "desc": "Knocks back 1 tile"},
		{"type": "burn", "tier": 1, "desc": "Ignites enemy for fire DMG"},
		{"type": "guard", "tier": 1, "desc": "+2 Guard Armor for 1 pulse"},
		{"type": "leech", "tier": 1, "desc": "Heals hero for +1 HP on hit"}
	]

	var ability = null
	var r_affix = randf()
	if r_affix < 0.40:
		ability = abilities.pick_random()

	# 3. Assemble Title, Desc, and Attributes
	var title = "STRIKE"
	var desc = "%d Direct Damage" % val
	var knockback = false
	var ability_type = "none"
	var ability_tier = 0

	if ability != null:
		ability_type = ability["type"]
		ability_tier = ability["tier"]
		match ability_type:
			"slash":
				title = "SERRATED SLASH" if ability_tier == 1 else "DEEP GASH"
				desc = "%d DMG • %s" % [val, ability["desc"]]
			"stun":
				title = "HEAVY HILT" if ability_tier == 1 else "SKULL CRACK"
				desc = "%d DMG • %s" % [val, ability["desc"]]
			"pierce":
				title = "PIERCING SPIKE"
				desc = "%d DMG • Bypasses Armor" % val
			"push":
				title = "FORCE IMPACT"
				desc = "%d DMG • Knocks back 1 tile" % val
				knockback = true
			"burn":
				title = "EMBER BRAND"
				desc = "%d DMG • Ignites Target" % val
			"guard":
				title = "DEFENSIVE COUNTER"
				desc = "%d DMG • +2 Guard Armor" % val
			"leech":
				title = "VAMPIRIC THIRST"
				desc = "%d DMG • Leech 1 HP" % val
	else:
		match val:
			1: title = "LIGHT POKE"
			2: title = "SOLID CUT"
			3: title = "CLEAN SLASH"
			4: title = "HEAVY SWING"
			5: title = "BRUTAL BLOW"
			6: title = "PERFECT CRIT"
			8: title = "TITAN SMASH"
			10: title = "DRAGON BANE"
			_: title = "STRIKE"
		desc = "%d Pure Damage" % val

	var icon_index = clampi(val, 1, 6)
	var icon_path = "res://assets/ui/die_face_%d.svg" % icon_index
	if ability_type == "burn" and ResourceLoader.exists("res://assets/ui/die_face_fire.svg"):
		icon_path = "res://assets/ui/die_face_fire.svg"

	return {
		"roll": val,
		"damage": val,
		"title": title,
		"desc": desc,
		"knockback": knockback,
		"icon": icon_path,
		"ability": ability_type,
		"ability_tier": ability_tier
	}

func roll_random_face() -> Dictionary:
	if faces.is_empty():
		return {}
	return faces[randi() % faces.size()]

func get_average_damage() -> float:
	if faces.is_empty():
		return 0.0
	var sum: float = 0.0
	for f in faces:
		sum += float(f.get("damage", 0))
	return sum / float(faces.size())

func duplicate_die() -> DieData:
	var d = DieData.new()
	d.name = self.name
	d.icon_path = self.icon_path
	d.die_type = self.die_type
	d.faces = self.faces.duplicate(true)
	return d
