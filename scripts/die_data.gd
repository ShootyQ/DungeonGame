class_name DieData
extends RefCounted

var name: String = "D6 Sword"
var icon_path: String = "res://assets/sprites/sword_d6.svg"
var die_type: String = "d6"
var faces: Array = []

static func create_default_d6_sword() -> DieData:
	var die = DieData.new()
	die.name = "Rusty D6 Sword"
	die.icon_path = "res://assets/sprites/sword_d6.svg"
	die.die_type = "d6"
	die.faces = [
		{
			"roll": 1,
			"title": "MISS",
			"desc": "Stumble! 0 Damage",
			"damage": 0,
			"knockback": false,
			"icon": "res://assets/ui/die_face_1.svg"
		},
		{
			"roll": 2,
			"title": "SLASH",
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
			"title": "SLASH",
			"desc": "4 Damage",
			"damage": 4,
			"knockback": false,
			"icon": "res://assets/ui/die_face_4.svg"
		},
		{
			"roll": 5,
			"title": "HEAVY",
			"desc": "6 Damage",
			"damage": 6,
			"knockback": false,
			"icon": "res://assets/ui/die_face_5.svg"
		},
		{
			"roll": 6,
			"title": "CRIT!",
			"desc": "9 Damage + Knockback",
			"damage": 9,
			"knockback": true,
			"icon": "res://assets/ui/die_face_6.svg"
		}
	]
	return die

static func create_executioner_axe() -> DieData:
	var die = DieData.new()
	die.name = "Executioner's Greataxe"
	die.icon_path = "res://assets/ui/icon_axe.svg"
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
	die.icon_path = "res://assets/ui/icon_mace.svg"
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
