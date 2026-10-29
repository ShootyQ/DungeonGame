class_name DieData
extends RefCounted

var name: String = "D6 Sword"
var faces: Array = []

static func create_default_d6_sword() -> DieData:
	var die = DieData.new()
	die.name = "Rusty D6 Sword"
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

func roll_random_face() -> Dictionary:
	if faces.is_empty():
		return {}
	return faces[randi() % faces.size()]
