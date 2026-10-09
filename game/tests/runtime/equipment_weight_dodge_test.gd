extends RefCounted

## A heavy weapon or armor costs dodge (DECISIONS A1): std/equip.c setup() gives a weapon
## from 3000 weight without a dodge of its own weapon_prop/dodge -weight/3000, the eleven
## std/armor/<type>.c an armor above 3000 the same armor_prop/dodge over its own. The item
## details say 轻功, the 武学 page's effective level and combat (player and NPCs) count it.
## TEST-ONLY fixtures, each marked where used: the sword, leather and thin sword put into
## the pack, the player's dodge skill.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const LONG_SWORD: StringName = &"es2:d/oldpine/obj/long_sword"
const LEATHER: StringName = &"es2:d/oldpine/obj/leather"
const THIN_SWORD: StringName = &"es2:d/snow/obj/thin_sword"

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _hud: SharedGameplayUI
var _page: MartialArtsPage


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_catalog()
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_hud = _session.shared_ui()
	_page = _hud.martial_arts_page()
	_test_details_page_and_combat()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## What each rule gives the imported items (weapon_prop or armor_prop dodge).
func _test_catalog() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var got: Array = []
	var expected: Array = []
	for row: Array in [
		["es2:obj/longsword", -2], # 长剑 7000
		["es2:daemon/class/swordsman/blackthorn", -5], # 玄苏剑 15000
		["es2:d/waterfog/obj/iron_staff", -23], # 黑铁杖 70000
		["es2:d/oldpine/obj/short_sword", -1], # 短剑: equip.c counts from 3000 itself
		["es2:daemon/class/juechen/jingang_staff", -5], # 金刚杖 13000 sets its own -5
		[String(THIN_SWORD), 0], # 细剑 1400
		["es2:d/snow/npc/obj/throwing_knife", 0], # 飞刀: throwing.c has its own setup()
	]:
		got.append(catalog.item(StringName(row[0])).weapon_apply.get(&"dodge", 0))
		expected.append(row[1])
	_check(got == expected, "weapons: equip.c's -weight/3000 from 3000, an own dodge kept: %s" % [got])
	got.clear()
	expected.clear()
	for row: Array in [
		["es2:d/snow/obj/shield", -2], # 牛皮盾 7000
		["es2:obj/npc/obj/golden_armor", -16], # 天兵战甲 50000, over its own -20
		["es2:d/waterfog/obj/leather_boot", -1], # 牛皮靴 4000, over its own +1
		["es2:d/snow/obj/raincoat", -2], # 蓑衣 7000
		[String(LEATHER), -2], # 皮衣 6000 (cloth.c, as before)
		["es2:obj/cloth", 0], # 布衣 3000: armor.c's needs more than 3000
		["es2:daemon/class/taoist/robe", 0], # 天师道袍 3000 inherits EQUIP, calls no setup()
		["es2:daemon/class/swordsman/silk_cloth", 6], # 丝绸马褂's own +6
	]:
		got.append(catalog.item(StringName(row[0])).armor_definition().numeric_modifiers.dodge)
		expected.append(row[1])
	_check(got == expected, "armor: std/armor/*.c's -weight/3000 above 3000, over the own value: %s" % [got])
	_check(catalog.item(ItemContentDefinition.broken_id(LONG_SWORD)).weapon_apply.is_empty(), "a broken sword (weapon_prop 0) adds nothing")


func _test_details_page_and_combat() -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	for pair: Array in [[&"test:sword", LONG_SWORD], [&"test:leather", LEATHER], [&"test:thin", THIN_SWORD]]:
		_add_item(pair[0], pair[1]) # TEST-ONLY
	_check(_details(map, &"test:sword").contains("伤害：25\n轻功：-2"), "the sword's details: 轻功：-2 — " + _details(map, &"test:sword"))
	_check(_details(map, &"test:leather").contains("防护：+5\n轻功：-2"), "the leather's details: 轻功：-2")
	_check(not _details(map, &"test:thin").contains("轻功"), "a light sword shows no 轻功")
	_hud.close_inventory()
	_hud.open_martial_arts()
	_check(not _page._use_texts.has(&"dodge"), "no dodge row yet (nothing learnt, nothing worn)")
	_hud.dismiss_current_panel()
	_check(_session.wield_player_item(&"test:sword").succeeded, "the sword wielded")
	_check(_session.martial_arts().apply_modifier(&"dodge") == -2, "apply/dodge -2")
	_hud.open_martial_arts()
	_check(_dodge_row() == "轻功：无 · 有效等级 %s" % _red(-2), "the 武学 page: effective 轻功 -2 in HIR: " + _dodge_row())
	_hud.dismiss_current_panel()
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if _player.armor.is_worn(row.item_instance_id):
			_session.remove_player_item(row.item_instance_id)
	_check(_session.wear_player_item(&"test:leather").succeeded, "the leather worn")
	_player.state.skills.set_raw_level(&"dodge", 20) # TEST-ONLY
	_hud.open_martial_arts()
	_check(_dodge_row() == "轻功：无 · 有效等级 %s" % _red(10 - 4), "query_skill: 20 / 2 - 2 - 2: " + _dodge_row())
	_hud.dismiss_current_panel()
	var bindings: Dictionary[StringName, CombatSliceCharacterBinding] = {}
	for binding: CombatSliceCharacterBinding in map.combat_lifecycle.build_participants(true):
		bindings[binding.character_id] = binding
	_check(CombatSliceProjectionBuilder.apply_of(bindings[_player.character_id], &"dodge") == -4, "combat counts the player's -4")
	var npcs: Dictionary = {}
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition_id in [&"snow.npc.woodcutter", &"snow.npc.farmer", &"snow.npc.annihir"]:
			npcs[npc.definition_id] = CombatSliceProjectionBuilder.apply_of(bindings[npc.character_id], &"dodge")
	_check(npcs == {&"snow.npc.woodcutter": -7, &"snow.npc.farmer": -2, &"snow.npc.annihir": -2}, "NPCs: the woodcutter's 铁斧 -7, the farmer's 蓑衣 -2, 安惜迩's 长剑 -2: %s" % [npcs])
	_check(_session.unwield_player_item(&"test:sword").succeeded and _session.martial_arts().apply_modifier(&"dodge") == -2, "put the sword away: the leather's -2 stays")


func _details(map: WorldMapController, id: StringName) -> String:
	if not OldPineTestMap.inspect_item(map, id):
		return ""
	return _hud.inventory_panel.inspection_display()


func _dodge_row() -> String:
	return _page._use_texts[&"dodge"].text if _page._use_texts.has(&"dodge") else ""


func _red(level: int) -> String:
	return "[color=#%s]%d[/color]" % [SharedGameplayUI.ES2_COLORS[ColoredLine.HIR].to_html(false), level]


func _add_item(id: StringName, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(_session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	_check(context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(id, context.endpoint()), "test item %s" % id)


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("equipment weight dodge: " + label)
