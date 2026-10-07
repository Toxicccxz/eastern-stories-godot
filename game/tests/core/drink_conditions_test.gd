extends RefCounted

## 青石村 B: daemon/condition/drunk.c and slumber_drug.c, and what a sip does
## (feature/liquid.c do_drink(): the powder poured in, then alcohol's drunk_apply), with
## pour (std/medicine/powder.c, obj/toy/poison_dust.c do_pour()).
const WINESKIN: StringName = &"es2:obj/example/wineskin"
const JAR: StringName = &"es2:d/green/npc/obj/ricewine"
const DRUG: StringName = &"es2:obj/slumber_drug"
const DUST: StringName = &"es2:obj/toy/poison_dust"
const JADE: StringName = &"es2:d/green/obj/jade"

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_tolerance()
	_test_drunk_tiers()
	_test_drunk_unconscious()
	_test_slumber()
	_test_one_pass_after_knock_out()
	_test_cadence_stops_on_knock_out()
	_test_items()
	_test_sips()
	_test_pour_records()
	return {"assertions": _count, "failures": _failures}


func _character(con: int = 20, max_force: int = 0) -> CharacterState:
	var state := CharacterState.new()
	state.attributes.constitution = con
	state.recovery.inner_force.maximum = max_force
	state.spirit = CharacterResourceState.new(100, 100, 100)
	return state


func _tick(state: CharacterState, conscious: bool = true) -> ConditionUpdateResult:
	return ConditionSystem.new().update_once(state, conscious)


func _duration(state: CharacterState, id: StringName) -> int:
	var payload: DurationConditionPayload = state.conditions.get_condition(id) as DurationConditionPayload
	return -999 if payload == null else payload.remaining


func _test_tolerance() -> void:
	_check(DrunkConditionEffect.tolerance(_character(20, 0)) == 40, "(con + max_force / 50) * 2: con 20 bears 40")
	_check(DrunkConditionEffect.tolerance(_character(20, 1049)) == 80, "max_force 1049 adds 20 (integer division)")


func _test_drunk_tiers() -> void:
	var state: CharacterState = _character()
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 25)
	var result: ConditionUpdateResult = _tick(state)
	_check(ColoredLine.texts(result.lines) == ["你觉得脑中昏昏沉沉，身子轻飘飘地，大概是醉了。"] and result.room_lines == ["{name}摇头晃脑地站都站不稳，显然是喝醉了。"], "past half of 40: reeling: %s" % [result.room_lines])
	_check(state.spirit.current == 90 and _duration(state, ConditionIds.DRUNK) == 24 and not result.knocked_out, "sen -10, one less")
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 20)
	result = _tick(state)
	_check(ColoredLine.texts(result.lines) == ["你觉得一阵酒意上冲，眼皮有些沉重了。"] and result.room_lines == ["{name}脸上已经略显酒意了。"], "past a quarter, not past half (20 is not > 20)")
	_check(state.spirit.current == 87 and state.essence.current == 0 and state.vitality.current == 0, "sen -3; receive_healing() reaches no function: gin and kee unchanged")
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 10)
	result = _tick(state)
	_check(result.lines.is_empty() and result.room_lines.is_empty() and _duration(state, ConditionIds.DRUNK) == 9, "10 is not past a quarter: nothing, counts down")
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 0)
	result = _tick(state)
	_check(result.updated == 1 and not state.conditions.has_condition(ConditionIds.DRUNK), "an update that finds 0 ends it")


func _test_drunk_unconscious() -> void:
	var state: CharacterState = _character()
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 41)
	var result: ConditionUpdateResult = _tick(state)
	_check(result.knocked_out and result.lines.is_empty() and not state.conditions.has_condition(ConditionIds.DRUNK), "past 40 the drinker falls unconscious and the condition ends")
	_check(state.life_threshold() == CharacterState.LifeThreshold.UNCONSCIOUS, "the fall happens at the next life check")
	var out: CharacterState = _character()
	out.conditions.add_or_replace_duration(ConditionIds.DRUNK, 50)
	result = _tick(out, false)
	_check(not result.knocked_out and result.lines.is_empty() and result.room_lines == ["{name}打了个隔，不过依然烂醉如泥。"] and _duration(out, ConditionIds.DRUNK) == 49, "lying unconscious: only the hiccup, counting down")


func _test_slumber() -> void:
	var state: CharacterState = _character()
	state.conditions.add_or_replace_duration(ConditionIds.SLUMBER_DRUG, 100)
	var result: ConditionUpdateResult = _tick(state)
	_check(result.knocked_out and not state.conditions.has_condition(ConditionIds.SLUMBER_DRUG), "a dose of 100 floors con 20 at once")
	var strong: CharacterState = _character(30, 1500)
	strong.conditions.add_or_replace_duration(ConditionIds.SLUMBER_DRUG, 100)
	result = _tick(strong)
	_check(not result.knocked_out and ColoredLine.texts(result.lines) == ["你觉得脑中昏昏沉沉，心中空荡荡的，直想躺下来睡一觉。"] and result.room_lines == ["{name}摇头晃脑地站都站不稳，显然是蒙汗药的药力发作了。"], "con 30 and max_force 1500 bear 120: it only sways them")
	_check(strong.spirit.current == 100 and _duration(strong, ConditionIds.SLUMBER_DRUG) == 99, "no damage; one less")
	strong.conditions.add_or_replace_duration(ConditionIds.SLUMBER_DRUG, 60)
	result = _tick(strong)
	_check(result.lines.is_empty() and result.room_lines.is_empty(), "60 is not past half of 120")


func _test_one_pass_after_knock_out() -> void:
	var state: CharacterState = _character()
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 45)
	state.conditions.add_or_replace_duration(ConditionIds.SLUMBER_DRUG, 30)
	var result: ConditionUpdateResult = _tick(state)
	_check(result.knocked_out and result.lines.is_empty() and result.room_lines == ["{name}摇头晃脑地站都站不稳，显然是蒙汗药的药力发作了。"], "drunk.c floors them first; slumber_drug then finds them not living: nothing told, the room still sees it")
	_check(_duration(state, ConditionIds.SLUMBER_DRUG) == 29, "and it counts down")


func _test_cadence_stops_on_knock_out() -> void:
	var state: CharacterState = _character()
	state.vitality = CharacterResourceState.new(100, 100, 100)
	state.recovery.water = 100
	state.recovery.food = 100
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 41)
	var cadence := PlayerRecoveryCadence.new(FixedTick.new())
	var result: PlayerRecoveryCadenceResult = cadence.advance(2.0 * 6, state, ActionBusyState.new())
	_check(result.conditions_updated == 1 and state.life_threshold() == CharacterState.LifeThreshold.UNCONSCIOUS, "heal_up() does not lift sen back on the beat a daemon floors the character")


func _test_items() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var drug: ItemContentDefinition = catalog.item(DRUG)
	var dust: ItemContentDefinition = catalog.item(DUST)
	_check(drug != null and drug.is_stack and drug.pour != null and drug.pour.condition == ConditionIds.SLUMBER_DRUG and drug.pour.dose == 100 and drug.unit == "包", "蒙汗药: a 包, poured it adds 100 slumber_drug a sip (drink_drug())")
	_check(dust != null and dust.pour != null and dust.pour.dose == 0 and dust.pour.adds_to_liquid == 100, "极乐逍遥散: each pour adds 100 to the drink's slumber_effect")
	var jade: ItemContentDefinition = catalog.item(JADE)
	_check(jade != null and jade.unique and jade.value == 1000 and jade.study != null and jade.study.max_skill == 40 and jade.study.exp_required == 100, "玉佩: unique, worth 1000, studied for force up to 40")
	_check(catalog.item(JAR).liquid_name(LiquidState.Content.RED_WINE) == "米酒" and catalog.item(JAR).liquid_name(LiquidState.Content.CLEAR_WATER) == "清水" and catalog.item(WINESKIN).liquid_name(LiquidState.Content.RED_WINE) == "红酒", "a container's own alcohol keeps its name")
	var errors: Array[String] = []
	var both := ContentRecordReader.new({"condition": "slumber_drug", "dose": 100, "adds_to_liquid": 100}, "pour", errors)
	PourDefinition.from_record(both)
	var neither := ContentRecordReader.new({"condition": "slumber_drug"}, "pour", errors)
	PourDefinition.from_record(neither)
	_check(errors.size() == 2, "a pour has a dose or adds to the liquid, not both: %s" % [errors])


func _test_sips() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var skin: LiquidDefinition = catalog.item(WINESKIN).liquid_definition()
	var state: CharacterState = _character()
	var wine: LiquidState = catalog.item(WINESKIN).fresh_liquid_state()
	LiquidDrinkEffects.apply(state, wine, skin, catalog)
	LiquidDrinkEffects.apply(state, wine, skin, catalog)
	_check(_duration(state, ConditionIds.DRUNK) == 12 and not state.conditions.has_condition(ConditionIds.SLUMBER_DRUG), "two sips of 红酒: drunk 6 + 6")
	LiquidDrinkEffects.pour(wine, catalog.item(DRUG))
	LiquidDrinkEffects.apply(state, wine, skin, catalog)
	_check(_duration(state, ConditionIds.SLUMBER_DRUG) == 100 and _duration(state, ConditionIds.DRUNK) == 18 and wine.drink_func == DRUG and wine.slumber_effect == 0, "drugged wine: slumber_drug + 100, and the wine still makes drunk (drink_drug() returns 0)")
	var water: LiquidState = LiquidState.new(LiquidState.Content.CLEAR_WATER, 15)
	var sober: CharacterState = _character()
	LiquidDrinkEffects.pour(water, catalog.item(DUST))
	LiquidDrinkEffects.pour(water, catalog.item(DUST))
	LiquidDrinkEffects.apply(sober, water, skin, catalog)
	_check(water.slumber_effect == 200 and _duration(sober, ConditionIds.SLUMBER_DRUG) == 200 and not sober.conditions.has_condition(ConditionIds.DRUNK), "two pours of 极乐逍遥散 in water: + 200 a sip, nobody gets drunk on water")
	LiquidDrinkEffects.pour(water, catalog.item(DRUG))
	LiquidDrinkEffects.apply(sober, water, skin, catalog)
	_check(water.drink_func == DRUG and water.slumber_effect == 200 and _duration(sober, ConditionIds.SLUMBER_DRUG) == 300, "the last powder poured decides: 蒙汗药's fixed 100")


func _test_pour_records() -> void:
	var record := NativeLiquidConsumableRecord.new(&"x", LiquidState.Content.RED_WINE, 3, DUST, 200)
	var copy: NativeLiquidConsumableRecord = record.duplicate_snapshot()
	_check(copy.drink_func == DUST and copy.slumber_effect == 200, "the save record keeps what was poured in")


class FixedTick:
	extends RecoveryCadenceRandomSource

	func draw_reset_tick() -> int:
		return 5


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("drink conditions: " + label)
