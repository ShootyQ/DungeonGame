class_name ItemData
extends RefCounted

var id: String = ""
var name: String = ""
var slot: String = "hand_1" # "helmet", "necklace", "chestplate", "hand_1", "hand_2", "gloves", "pants", "boots", "ring_1", "ring_2"
var hands: int = 1 # 1 for 1-handed, 2 for 2-handed
var item_type: String = "weapon" # "weapon", "shield", "tome", "armor", "jewelry"
var icon_path: String = ""
var desc: String = ""
var hp_bonus: int = 0
var armor_bonus: int = 0
var dmg_bonus: int = 0
var str_bonus: int = 0
var dex_bonus: int = 0
var int_bonus: int = 0
var trait_id: String = "" # "honed_edge", "serrated", "titans_grip", "vampiric", "ember_core", "phalanx_guard"
var trait_name: String = ""
var trait_desc: String = ""
var estate_perk_id: String = ""
var estate_perk_desc: String = ""
var gold_value: int = 25
var die: DieData = null
var face_data: Dictionary = {}

func get_sell_value() -> int:
	if item_type == "face":
		var dmg = face_data.get("damage", 1)
		var eff = face_data.get("effect", "")
		return maxi(12, dmg * 7 + (18 if eff != "" else 0))
	elif item_type == "weapon":
		return 50 + (str_bonus + dex_bonus + int_bonus) * 15 + (30 if trait_id != "" else 0)
	elif item_type == "trophy":
		return 100
	elif item_type == "armor" or item_type == "shield":
		return 35 + armor_bonus * 12 + hp_bonus * 4
	elif item_type == "jewelry":
		return 45 + hp_bonus * 5 + (str_bonus + dex_bonus + int_bonus) * 15
	return 25

func duplicate_item() -> ItemData:
	var it = ItemData.new()
	it.id = self.id
	it.name = self.name
	it.slot = self.slot
	it.hands = self.hands
	it.item_type = self.item_type
	it.icon_path = self.icon_path
	it.desc = self.desc
	it.hp_bonus = self.hp_bonus
	it.armor_bonus = self.armor_bonus
	it.dmg_bonus = self.dmg_bonus
	it.str_bonus = self.str_bonus
	it.dex_bonus = self.dex_bonus
	it.int_bonus = self.int_bonus
	it.trait_id = self.trait_id
	it.trait_name = self.trait_name
	it.trait_desc = self.trait_desc
	it.estate_perk_id = self.estate_perk_id
	it.estate_perk_desc = self.estate_perk_desc
	it.gold_value = self.gold_value
	if self.die:
		it.die = self.die.duplicate_die()
	it.face_data = self.face_data.duplicate(true)
	return it

func get_stat_summary() -> String:
	var parts: Array[String] = []
	if hp_bonus > 0:
		parts.append("+%d HP" % hp_bonus)
	if armor_bonus > 0:
		parts.append("+%d Armor" % armor_bonus)
	if dmg_bonus > 0:
		parts.append("+%d DMG" % dmg_bonus)
	if str_bonus > 0:
		parts.append("+%d STR" % str_bonus)
	if dex_bonus > 0:
		parts.append("+%d DEX" % dex_bonus)
	if int_bonus > 0:
		parts.append("+%d INT" % int_bonus)
	if trait_name != "":
		parts.append("Trait: %s" % trait_name)
	if estate_perk_desc != "":
		parts.append("Perk: %s" % estate_perk_desc)
	if hands == 2:
		parts.append("2-Handed")
	elif hands == 1 and item_type == "weapon":
		parts.append("1-Handed")
	return " | ".join(parts) if not parts.is_empty() else "Standard"

static func get_slot_silhouette(slot_name: String) -> String:
	match slot_name:
		"helmet": return "res://assets/items/slot_helmet.svg"
		"necklace": return "res://assets/items/slot_necklace.svg"
		"chestplate": return "res://assets/items/slot_chestplate.svg"
		"hand_1": return "res://assets/items/slot_hand_1.svg"
		"hand_2": return "res://assets/items/slot_hand_2.svg"
		"gloves": return "res://assets/items/slot_gloves.svg"
		"pants": return "res://assets/items/slot_pants.svg"
		"boots": return "res://assets/items/slot_boots.svg"
		"ring_1", "ring_2": return "res://assets/items/slot_ring.svg"
		_: return "res://assets/items/slot_chestplate.svg"

static func get_slot_title(slot_name: String) -> String:
	match slot_name:
		"helmet": return "Helmet"
		"necklace": return "Necklace"
		"chestplate": return "Chestplate"
		"hand_1": return "Main Hand"
		"hand_2": return "Off Hand"
		"gloves": return "Gloves"
		"pants": return "Pants"
		"boots": return "Boots"
		"ring_1": return "Ring 1"
		"ring_2": return "Ring 2"
		_: return slot_name.capitalize()

# --- Factory Methods ---

static func create_starter_sword() -> ItemData:
	var it = ItemData.new()
	it.id = "sword_starter"
	it.name = "Rusty D6 Sword"
	it.slot = "hand_1"
	it.hands = 1
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_sword_starter.svg"
	it.desc = "Reliable 1-handed knight's blade. Standard combat dice."
	it.die = DieData.create_default_d6_sword()
	return it

static func create_warhammer() -> ItemData:
	var it = ItemData.new()
	it.id = "warhammer"
	it.name = "Phalanx Warhammer"
	it.slot = "hand_1"
	it.hands = 2
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_warhammer.svg"
	it.desc = "Massive 2-handed stone warhammer. Shatters enemy tower shields!"
	it.die = DieData.create_warhammer()
	return it

static func create_swift_dagger() -> ItemData:
	var it = ItemData.new()
	it.id = "dagger"
	it.name = "Swift Stiletto"
	it.slot = "hand_1"
	it.hands = 1
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_dagger.svg"
	it.desc = "Fast 1-handed stiletto with lethal puncture strikes."
	it.die = DieData.create_swift_dagger()
	return it

static func create_executioner_axe() -> ItemData:
	var it = ItemData.new()
	it.id = "executioner"
	it.name = "Executioner's Greataxe"
	it.slot = "hand_1"
	it.hands = 2
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_executioner.svg"
	it.desc = "Brutal 2-handed cleaver capable of 12 DMG execute strikes."
	it.die = DieData.create_executioner_axe()
	return it

static func create_chaos_staff() -> ItemData:
	var it = ItemData.new()
	it.id = "chaos_staff"
	it.name = "Chaos Blast Staff"
	it.slot = "hand_1"
	it.hands = 2
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_chaos_staff.svg"
	it.desc = "Unstable 2-handed arcane staff that triggers void singular strikes."
	it.die = DieData.create_chaos_staff()
	return it

static func create_spiked_morningstar() -> ItemData:
	var it = ItemData.new()
	it.id = "morningstar"
	it.name = "Spiked Morningstar"
	it.slot = "hand_1"
	it.hands = 1
	it.item_type = "weapon"
	it.icon_path = "res://assets/items/item_spikes.svg"
	it.desc = "Heavy flail with steel spikes that bludgeons and pushes foes."
	it.die = DieData.create_spiked_morningstar()
	return it

# Off-Hand Items (Hand 2)
static func create_shield() -> ItemData:
	var it = ItemData.new()
	it.id = "phalanx_shield"
	it.name = "Phalanx Tower Shield"
	it.slot = "hand_2"
	it.hands = 1
	it.item_type = "shield"
	it.icon_path = "res://assets/items/item_shield.svg"
	it.desc = "Heavy oak and steel shield. Bolsters defense (+2 Armor, +5 HP)."
	it.armor_bonus = 2
	it.hp_bonus = 5
	return it

static func create_tome() -> ItemData:
	var it = ItemData.new()
	it.id = "pyro_tome"
	it.name = "Pyromancer's Grimoire"
	it.slot = "hand_2"
	it.hands = 1
	it.item_type = "tome"
	it.icon_path = "res://assets/items/item_tome.svg"
	it.desc = "Scorched spellbook radiating fire. Amplifies strikes (+2 DMG)."
	it.dmg_bonus = 2
	return it

static func create_parry_dagger() -> ItemData:
	var it = ItemData.new()
	it.id = "parry_dagger"
	it.name = "Duelist Main-Gauche"
	it.slot = "hand_2"
	it.hands = 1
	it.item_type = "shield"
	it.icon_path = "res://assets/items/item_parry_dagger.svg"
	it.desc = "Nimble off-hand parrying dagger (+1 Armor, +1 DMG)."
	it.armor_bonus = 1
	it.dmg_bonus = 1
	return it

# Armor
static func create_helmet() -> ItemData:
	var it = ItemData.new()
	it.id = "steel_greathelm"
	it.name = "Steel Greathelm"
	it.slot = "helmet"
	it.hands = 1
	it.item_type = "armor"
	it.icon_path = "res://assets/items/item_helmet.svg"
	it.desc = "Tempered steel visored helm (+6 HP, +1 Armor)."
	it.hp_bonus = 6
	it.armor_bonus = 1
	return it

static func create_chestplate() -> ItemData:
	var it = ItemData.new()
	it.id = "reinforced_cuirass"
	it.name = "Reinforced Cuirass"
	it.slot = "chestplate"
	it.hands = 1
	it.item_type = "armor"
	it.icon_path = "res://assets/items/item_chestplate.svg"
	it.desc = "Layered plate cuirass with heavy breastplate (+12 HP, +2 Armor)."
	it.hp_bonus = 12
	it.armor_bonus = 2
	return it

static func create_gloves() -> ItemData:
	var it = ItemData.new()
	it.id = "iron_gauntlets"
	it.name = "Iron Gauntlets"
	it.slot = "gloves"
	it.hands = 1
	it.item_type = "armor"
	it.icon_path = "res://assets/items/item_gloves.svg"
	it.desc = "Articulated iron gloves enhancing grip (+4 HP, +1 DMG)."
	it.hp_bonus = 4
	it.dmg_bonus = 1
	return it

static func create_pants() -> ItemData:
	var it = ItemData.new()
	it.id = "plate_greaves"
	it.name = "Plate Greaves"
	it.slot = "pants"
	it.hands = 1
	it.item_type = "armor"
	it.icon_path = "res://assets/items/item_pants.svg"
	it.desc = "Solid steel greaves with armored poleyns (+8 HP, +1 Armor)."
	it.hp_bonus = 8
	it.armor_bonus = 1
	return it

static func create_boots() -> ItemData:
	var it = ItemData.new()
	it.id = "armored_sabatons"
	it.name = "Armored Sabatons"
	it.slot = "boots"
	it.hands = 1
	it.item_type = "armor"
	it.icon_path = "res://assets/items/item_boots.svg"
	it.desc = "Winged steel sabatons (+4 HP, +1 DMG)."
	it.hp_bonus = 4
	it.dmg_bonus = 1
	return it

# Jewelry
static func create_necklace() -> ItemData:
	var it = ItemData.new()
	it.id = "blood_amulet"
	it.name = "Blood Amber Pendant"
	it.slot = "necklace"
	it.hands = 1
	it.item_type = "jewelry"
	it.icon_path = "res://assets/items/item_necklace.svg"
	it.desc = "Ancient pendant humming with vitality (+10 HP)."
	it.hp_bonus = 10
	return it

static func create_ring_fury() -> ItemData:
	var it = ItemData.new()
	it.id = "ruby_ring"
	it.name = "Ruby Band of Fury"
	it.slot = "ring_1" # Can also equip in ring_2
	it.hands = 1
	it.item_type = "jewelry"
	it.icon_path = "res://assets/items/item_ring_fury.svg"
	it.desc = "A glowing ruby band infusing strikes with fire (+2 DMG)."
	it.dmg_bonus = 2
	return it

static func create_ring_protection() -> ItemData:
	var it = ItemData.new()
	it.id = "sapphire_ring"
	it.name = "Sapphire Aegis Ring"
	it.slot = "ring_2" # Can also equip in ring_1
	it.hands = 1
	it.item_type = "jewelry"
	it.icon_path = "res://assets/items/item_ring_protection.svg"
	it.desc = "Celestial sapphire band projecting a protective ward (+1 Armor)."
	it.armor_bonus = 1
	return it

# Loose Die Face Item for Socketing
static func create_face_item(face: Dictionary) -> ItemData:
	var it = ItemData.new()
	var ability = face.get("ability", "none")
	it.id = "face_%d_%s" % [face.get("roll", 1), ability]
	it.name = "%d DMG - %s" % [face.get("damage", 1), face.get("title", "Die Face")]
	it.slot = "face"
	it.item_type = "face"
	it.icon_path = "res://assets/items/item_die_face.svg"
	it.desc = face.get("desc", "%d Damage" % face.get("damage", 1))
	it.dmg_bonus = face.get("damage", 1)
	it.face_data = face.duplicate(true)
	return it

# Procedural Weapon Chassis Drops with Traits
static func generate_random_weapon(floor_depth: int = 1) -> ItemData:
	var it = ItemData.new()
	var weapon_archetypes = [
		{"name": "Knight's Arming Sword", "hands": 1, "icon": "res://assets/items/item_sword_starter.svg", "str": 1, "dex": 0, "int": 0},
		{"name": "Executioner's Greatsword", "hands": 2, "icon": "res://assets/items/item_axe_executioner.svg", "str": 2, "dex": 0, "int": 0},
		{"name": "Shadow Dirk", "hands": 1, "icon": "res://assets/items/item_dagger_parry.svg", "str": 0, "dex": 2, "int": 0},
		{"name": "Phalanx Battleaxe", "hands": 1, "icon": "res://assets/items/item_axe_executioner.svg", "str": 1, "dex": 1, "int": 0},
		{"name": "Crusher Warhammer", "hands": 2, "icon": "res://assets/items/item_warhammer_phalanx.svg", "str": 3, "dex": 0, "int": 0},
		{"name": "Pyromancer's Scepter", "hands": 1, "icon": "res://assets/items/item_wand_pyro.svg", "str": 0, "dex": 0, "int": 2}
	]
	var arch = weapon_archetypes.pick_random()
	it.id = "chassis_%s_%d" % [arch["name"].to_lower().replace(" ", "_"), randi() % 1000]
	it.name = arch["name"]
	it.slot = "hand_1"
	it.hands = arch["hands"]
	it.item_type = "weapon"
	it.icon_path = arch["icon"]
	it.str_bonus = arch["str"]
	it.dex_bonus = arch["dex"]
	it.int_bonus = arch["int"]

	# Chassis Traits
	var traits = [
		{"id": "honed_edge", "name": "Honed Edge", "desc": "+1 DMG to all socketed faces"},
		{"id": "serrated", "name": "Serrated Crossguard", "desc": "All attacks inflict +1 Bleed"},
		{"id": "titans_grip", "name": "Titan's Grip", "desc": "Faces with 5+ DMG knock back targets"},
		{"id": "vampiric", "name": "Vampiric Thirst", "desc": "Critical strikes restore +2 HP"},
		{"id": "ember_core", "name": "Ember Core", "desc": "All attacks ignite targets for +1 Burn"},
		{"id": "phalanx_guard", "name": "Phalanx Guard", "desc": "+2 Guard Armor after every attack"}
	]
	var t = traits.pick_random()
	it.trait_id = t["id"]
	it.trait_name = t["name"]
	it.trait_desc = t["desc"]
	it.desc = "%s. Chassis Trait: %s (%s)." % [arch["name"], t["name"], t["desc"]]

	# Generate 6 procedural faces for this weapon chassis
	it.die = DieData.new()
	it.die.name = it.name
	it.die.icon_path = it.icon_path
	it.die.faces = []
	for slot_idx in range(6):
		var face = DieData.generate_random_face(floor_depth)
		face["roll"] = slot_idx + 1
		it.die.faces.append(face)

	return it

static func get_available_chassis_traits() -> Array[Dictionary]:
	return [
		{"id": "honed_edge", "name": "Honed Edge", "desc": "+1 DMG to all socketed faces"},
		{"id": "serrated", "name": "Serrated Crossguard", "desc": "All attacks inflict +1 Bleed"},
		{"id": "titans_grip", "name": "Titan's Grip", "desc": "Faces with 5+ DMG knock back targets"},
		{"id": "vampiric", "name": "Vampiric Thirst", "desc": "Critical strikes restore +2 HP"},
		{"id": "ember_core", "name": "Ember Core", "desc": "All attacks ignite targets for +1 Burn"},
		{"id": "phalanx_guard", "name": "Phalanx Guard", "desc": "+2 Guard Armor after every attack"}
	]

# Collectible Estate / Mansion Trophies
static func create_estate_trophy(p_id: String, p_name: String, p_desc: String) -> ItemData:
	var it = ItemData.new()
	it.id = p_id
	it.name = p_name
	it.slot = "trophy"
	it.item_type = "trophy"
	it.gold_value = 100
	
	match p_id:
		"trophy_goblin_idol":
			it.icon_path = "res://assets/items/item_crown_victory.svg"
			it.estate_perk_id = "gold_find"
			it.estate_perk_desc = "+25% Dungeon Gold Find"
		"trophy_gargoyle":
			it.icon_path = "res://assets/items/item_shield_starter.svg"
			it.estate_perk_id = "estate_armor"
			it.estate_perk_desc = "+2 Base Armor"
		"trophy_dragon_seal":
			it.icon_path = "res://assets/items/item_ring_ruby.svg"
			it.estate_perk_id = "estate_crit"
			it.estate_perk_desc = "+5% Critical Hit Chance"
		"trophy_chalice":
			it.icon_path = "res://assets/items/item_amulet_life.svg"
			it.estate_perk_id = "estate_hp"
			it.estate_perk_desc = "+15 Max HP"
		"trophy_obsidian_relic":
			it.icon_path = "res://assets/items/item_wand_pyro.svg"
			it.estate_perk_id = "estate_dmg"
			it.estate_perk_desc = "+2 Flat Bonus DMG"
		_:
			it.icon_path = "res://assets/items/item_crown_victory.svg"
			it.estate_perk_id = "prestige"
			it.estate_perk_desc = "+10 Estate Prestige"
			
	it.desc = "%s. Estate Perk: %s (Furnish onto an Estate Pedestal in your Manor to activate)." % [p_desc, it.estate_perk_desc]
	return it
