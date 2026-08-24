class_name ArmorNumericModifiers
extends RefCounted

## Immutable typed projection of the numeric armor_prop keys present in the
## active LPC mudlib. Presentation keys (id/name/short/long) are deliberately
## excluded. The armor scan found no armor_prop/spirituality entry.
var _armor: int
var _armor_vs_force: int
var _attack: int
var _defense: int
var _dodge: int
var _composure: int
var _courage: int
var _intelligence: int
var _karma: int
var _personality: int
var _magic: int
var _move: int
var _spells: int
var _unarmed: int

var armor: int:
	get:
		return _armor
var armor_vs_force: int:
	get:
		return _armor_vs_force
var attack: int:
	get:
		return _attack
var defense: int:
	get:
		return _defense
var dodge: int:
	get:
		return _dodge
var composure: int:
	get:
		return _composure
var courage: int:
	get:
		return _courage
var intelligence: int:
	get:
		return _intelligence
var karma: int:
	get:
		return _karma
var personality: int:
	get:
		return _personality
var magic: int:
	get:
		return _magic
var move: int:
	get:
		return _move
var spells: int:
	get:
		return _spells
var unarmed: int:
	get:
		return _unarmed


func _init(
	p_armor: int = 0,
	p_armor_vs_force: int = 0,
	p_attack: int = 0,
	p_defense: int = 0,
	p_dodge: int = 0,
	p_composure: int = 0,
	p_courage: int = 0,
	p_intelligence: int = 0,
	p_karma: int = 0,
	p_personality: int = 0,
	p_magic: int = 0,
	p_move: int = 0,
	p_spells: int = 0,
	p_unarmed: int = 0,
) -> void:
	_armor = p_armor
	_armor_vs_force = p_armor_vs_force
	_attack = p_attack
	_defense = p_defense
	_dodge = p_dodge
	_composure = p_composure
	_courage = p_courage
	_intelligence = p_intelligence
	_karma = p_karma
	_personality = p_personality
	_magic = p_magic
	_move = p_move
	_spells = p_spells
	_unarmed = p_unarmed


func added(other: ArmorNumericModifiers) -> ArmorNumericModifiers:
	if other == null:
		return duplicate_snapshot()
	return ArmorNumericModifiers.new(
		_armor + other.armor,
		_armor_vs_force + other.armor_vs_force,
		_attack + other.attack,
		_defense + other.defense,
		_dodge + other.dodge,
		_composure + other.composure,
		_courage + other.courage,
		_intelligence + other.intelligence,
		_karma + other.karma,
		_personality + other.personality,
		_magic + other.magic,
		_move + other.move,
		_spells + other.spells,
		_unarmed + other.unarmed,
	)


func duplicate_snapshot() -> ArmorNumericModifiers:
	return ArmorNumericModifiers.new(
		_armor,
		_armor_vs_force,
		_attack,
		_defense,
		_dodge,
		_composure,
		_courage,
		_intelligence,
		_karma,
		_personality,
		_magic,
		_move,
		_spells,
		_unarmed,
	)
