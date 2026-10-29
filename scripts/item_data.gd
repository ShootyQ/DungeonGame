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
var die: DieData = null

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
	if self.die:
		it.die = self.die.duplicate_die()
	return it

func get_stat_summary() -> String:
	var parts: Array[String] = []
	if hp_bonus > 0:
		parts.append("+%d HP" % hp_bonus)
	if armor_bonus > 0:
		parts.append("+%d Armor" % armor_bonus)
	if dmg_bonus > 0:
		parts.append("+%d DMG" % dmg_bonus)
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
