class_name HeroVisual
extends Node2D

# Dynamic layered character rendering system
var gender: String = "male" # "male", "female"
var face_id: int = 1 # 1, 2, 3
var hair_id: String = "short_brown" # "short_brown", "spiky_blonde", "long_black", "braid_red", "none"
var cloak_id: String = "cloak_blue" # "cloak_blue", "cloak_red", "none"

# Equipped gear references for visual overlay
var equipped_helmet: ItemData = null
var equipped_chest: ItemData = null
var equipped_pants: ItemData = null
var equipped_boots: ItemData = null
var equipped_weapon: ItemData = null
var equipped_offhand: ItemData = null

# Child Sprite layers in back-to-front rendering order
var spr_shadow: Sprite2D
var spr_cloak: Sprite2D
var spr_body: Sprite2D
var spr_pants: Sprite2D
var spr_boots: Sprite2D
var spr_chest: Sprite2D
var spr_face: Sprite2D
var spr_hair: Sprite2D
var spr_helmet: Sprite2D
var spr_offhand: Sprite2D
var spr_weapon: Sprite2D

func _init() -> void:
	spr_shadow = _create_layer()
	spr_cloak = _create_layer()
	spr_body = _create_layer()
	spr_pants = _create_layer()
	spr_boots = _create_layer()
	spr_chest = _create_layer()
	spr_face = _create_layer()
	spr_hair = _create_layer()
	spr_helmet = _create_layer()
	spr_offhand = _create_layer()
	spr_weapon = _create_layer()
	
	update_appearance()

func _create_layer() -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = true
	add_child(s)
	return s

func set_flip_h(val: bool) -> void:
	for child in get_children():
		if child is Sprite2D:
			child.flip_h = val

func update_appearance() -> void:
	# 1. Shadow
	spr_shadow.texture = _load_tex("res://assets/sprites/hero_layers/shadow.svg")
	
	# 2. Cloak
	if cloak_id != "none" and cloak_id != "":
		spr_cloak.texture = _load_tex("res://assets/sprites/hero_layers/%s.svg" % cloak_id)
		spr_cloak.visible = true
	else:
		spr_cloak.visible = false
		
	# 3. Base Body
	var body_path = "res://assets/sprites/hero_layers/body_%s.svg" % gender
	spr_body.texture = _load_tex(body_path)
	
	# 4. Pants / Legs
	if equipped_pants != null and "Plate" in equipped_pants.name:
		spr_pants.texture = _load_tex("res://assets/sprites/hero_layers/pants_plate.svg")
	else:
		spr_pants.texture = _load_tex("res://assets/sprites/hero_layers/pants_basic.svg")
		
	# 5. Boots
	if equipped_boots != null:
		spr_boots.texture = _load_tex("res://assets/sprites/hero_layers/boots_leather.svg")
		spr_boots.visible = true
	else:
		spr_boots.visible = false
		
	# 6. Chestplate
	if equipped_chest != null:
		spr_chest.texture = _load_tex("res://assets/sprites/hero_layers/chest_plate.svg")
		spr_chest.visible = true
	else:
		spr_chest.visible = false
		
	# 7. Face
	var face_path = "res://assets/sprites/hero_layers/face_%s_%d.svg" % [gender, face_id]
	spr_face.texture = _load_tex(face_path)
	
	# 8. Helmet vs Hair
	if equipped_helmet != null:
		spr_helmet.texture = _load_tex("res://assets/sprites/hero_layers/helmet_greathelm.svg")
		spr_helmet.visible = true
		spr_hair.visible = false # Greathelm covers hair
	else:
		spr_helmet.visible = false
		if hair_id != "none" and hair_id != "":
			spr_hair.texture = _load_tex("res://assets/sprites/hero_layers/hair_%s.svg" % hair_id)
			spr_hair.visible = true
		else:
			spr_hair.visible = false
			
	# 9. Off-Hand
	if equipped_offhand != null:
		if equipped_offhand.item_type == "shield" or "Shield" in equipped_offhand.name:
			spr_offhand.texture = _load_tex("res://assets/sprites/hero_layers/offhand_shield.svg")
			spr_offhand.visible = true
		elif equipped_offhand.item_type == "tome" or "Tome" in equipped_offhand.name:
			spr_offhand.texture = _load_tex("res://assets/sprites/hero_layers/offhand_tome.svg")
			spr_offhand.visible = true
		else:
			spr_offhand.texture = _load_tex("res://assets/sprites/hero_layers/offhand_shield.svg")
			spr_offhand.visible = true
	else:
		spr_offhand.visible = false
		
	# 10. Main Hand Weapon
	if equipped_weapon != null:
		if "Staff" in equipped_weapon.name or "Wand" in equipped_weapon.name or "Scepter" in equipped_weapon.name:
			spr_weapon.texture = _load_tex("res://assets/sprites/hero_layers/weapon_staff.svg")
		elif "Axe" in equipped_weapon.name or "Cleaver" in equipped_weapon.name or "Executioner" in equipped_weapon.name or "Warhammer" in equipped_weapon.name:
			spr_weapon.texture = _load_tex("res://assets/sprites/hero_layers/weapon_axe.svg")
		else:
			spr_weapon.texture = _load_tex("res://assets/sprites/hero_layers/weapon_sword.svg")
		spr_weapon.visible = true
	else:
		spr_weapon.visible = false

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
