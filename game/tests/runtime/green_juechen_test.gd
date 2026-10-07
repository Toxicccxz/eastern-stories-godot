extends RefCounted

## 青石村 C: 绝尘派. 绝尘子 in the hall with his 金刚杖 and 紫金冠, his arts as data; the
## spells he casts in a fight with scripted draws (遁: the target busy; 召天将: a 天X神兵
## comes); joining him (a family's member is taken for a traitor and attacked, asked
## first; spi 24 and combat_exp 100000 each with its say; class taoist: 道士 / 女冠); the
## seal; learning; then the real session: 拜师 as a traitor and as a commoner, his fight
## with the soldier who comes against the player and leaves once it is over, or falls and
## leaves its corpse, which Save/Continue keeps; 冥思 and 修行; 法力 and 灵力 on the sheet.
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const MASTER: StringName = &"common.npc.juechen.master"
const SOLDIER: StringName = &"common.npc.heaven_soldier"
const STAFF: StringName = &"es2:daemon/class/juechen/jingang_staff"
const HAT: StringName = &"es2:daemon/class/juechen/hat"
const ARMOR: StringName = &"es2:obj/npc/obj/golden_armor"
const SWORD: StringName = &"es2:obj/npc/obj/golden_sword"
const MASTER_POINT: StringName = &"green.cavehall.master.1"


## Draws by bound: each bound's queue first (saveme's random(spells), the chat's
## random(100)...), then the highest value: nobody's chat fires unless told to.
class Forced extends CombatRandomSource:
	var queues: Dictionary[int, Array] = {}
	func next_below(bound: int) -> int:
		var queue: Array = queues.get(bound, [])
		if not queue.is_empty():
			return clampi(queue.pop_front(), 0, bound - 1)
		return bound - 1


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog
var _original_random: CombatRandomSource
var _kee: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_dun()
	_test_saveme()
	_test_apprentice_rule()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_original_random = session.combat_random_source()
	_kee = session.player_runtime().state.vitality.maximum
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"green.mountain", &"green.cavehall", &"green.cavehall", &"green.cavehall.stoneroom_arrival").succeeded(), "TEST-ONLY: in the hall")
	await tree.physics_frame
	await tree.physics_frame
	await _test_master_in_the_hall(tree, session)
	await _test_traitor(tree, session)
	await _test_join(tree, session)
	await _test_soldier_leaves(tree, session)
	await _test_soldier_falls(tree, session)
	await _test_cultivation(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	_check(master != null and master.display_name == "绝尘子" and master.internal_power(&"mana") == 4000 and master.internal_power(&"max_mana") == 2000 and master.internal_power(&"atman") == 2000, "绝尘子: mana 4000 of 2000, atman 2000")
	var talk: NpcTalk = master.talk()
	var kinds: Array[String] = []
	for entry: Variant in talk.combat_chat_entries():
		kinds.append("%s" % entry.function_id if entry is NpcSpecialAction else String(entry).strip_edges())
	_check(talk.combat_chat_chance == 40 and kinds == ["dun", "saveme", "绝尘子道：你为何无故滋事，误我清修！", "绝尘子道：贫道向以遁世为乐，你何苦如此相逼？"], "chat_chance_combat 40: 遁, 召天将 and his two lines: %s" % [kinds])
	var teaching: NpcTeaching = master.teaching()
	_check(teaching.family_id == &"family.juechen" and teaching.family_generation == 1 and teaching.f_master and teaching.apprentice.class_id == &"taoist", "绝尘派's founder, an F_MASTER who gives the class taoist")
	var taught: Array[StringName] = NpcTeacher.teachable_skills(master, _catalog)
	_check(taught.size() == 14 and taught.has(&"magic-array") and taught.has(&"tao-mystery") and taught.has(&"jingang-staff") and taught.has(&"juechen-force") and taught.has(&"magic") and taught.has(&"spells"), "he teaches every skill he has: %s" % [taught])
	var array: SkillDefinition = _catalog.skill(&"magic-array")
	_check(array.skill_type == SkillDefinition.Type.KNOWLEDGE and array.can_enable_for(&"spells") and array.cast_functions == [&"dun", &"saveme"] and array.display_name == "奇门遁甲", "奇门遁甲: spells, casts 遁 and 召天将")
	var staff: SkillDefinition = _catalog.skill(&"jingang-staff")
	_check(staff.can_enable_for(&"staff") and staff.can_enable_for(&"parry") and staff.action_set() != null and staff.action_set().size() == 4, "金刚杖法: staff and parry, four moves")
	_check(_catalog.skill(&"juechen-force").standard_force_hit and _catalog.skill(&"juechen-force").exert_functions.is_empty(), "绝尘心法: std/force.c's hit, no exert file")
	_check(_catalog.skill(&"tao-mystery").kind == SkillDefinition.Kind.BASIC and _catalog.skill(&"magic").skill_type == SkillDefinition.Type.KNOWLEDGE and _catalog.skill(&"spells").skill_type == SkillDefinition.Type.KNOWLEDGE, "小天魔道, magic and spells are knowledge")
	var staff_item: ItemContentDefinition = _catalog.item(STAFF)
	var hat: ItemContentDefinition = _catalog.item(HAT)
	_check(staff_item.weapon_apply.get(&"spells", 0) == 10 and staff_item.weapon_apply.get(&"dodge", 0) == -5 and hat != null, "金刚杖: spells 10, dodge -5; 紫金冠")
	var soldier: NpcDefinition = _catalog.npc(SOLDIER)
	_check(soldier.name_pick().size() == 10 and soldier.name_pick()[9] == "天癸神兵" and soldier.summoning().arrive.size() == 2 and soldier.summoning().color == ColoredLine.HIY, "the heaven soldier draws one of ten names; its coming and going in HIY")
	_check(_catalog.spawns_for_map(&"green.mountain").any(func(spawn: NpcSpawnDefinition) -> bool: return spawn.npc_definition_id == MASTER and spawn.zone_id == &"green.cavehall"), "cavehall.c places him in the hall")


# --- Spells -------------------------------------------------------------------------

## dun.c at an enemy: busy mana / 200 (after the cost) less its max_mana / 100, plus 2.
func _test_dun() -> void:
	var dun := NpcSpecialAction.new(NpcSpecialAction.Kind.CAST, &"", &"dun")
	var pair: Array[SpecialSide] = _pair()
	# random(1): the target; random(210) 100: no failure; random(5) 1: the golden light; then it holds.
	var context: SpecialContext = _context(pair, Specials.Pattern.new([0, 100, 1, 999999999]))
	_check(pair[0].query_skill(&"spells") == 210, "his spells: 150 / 2 + 奇门遁甲 120 + the staff's 10 and the crown's 5")
	_check(NpcSpecials.run(dun, context), "遁 is cast")
	_check(pair[1].busy.busy_value == 21 and pair[0].state.recovery.mana.current == 3800 and pair[0].state.spirit.current == 220, "the target busy 3800 / 200 + 2 = 21; 200 mana and 80 sen spent: %d" % pair[1].busy.busy_value)
	_check(context.lines.size() == 2 and context.lines[0].template == DunSpell.CHANT and context.lines[1].template == "只见一道金光罩在$n身上！" and context.lines[1].color == ColoredLine.HIW, "the chant and the golden light, in HIW")
	_check(not NpcSpecials.run(dun, _context(pair, Specials.Pattern.new([0]))) and pair[0].state.recovery.mana.current == 3800, "a busy target: 正自顾不暇, nothing spent")
	pair = _pair()
	pair[1].state.recovery.mana = CharacterInternalResourceState.new(0, 2500) # TEST-ONLY: a target with max_mana 2500
	context = _context(pair, Specials.Pattern.new([0, 100, 4, 999999999]))
	NpcSpecials.run(dun, context)
	_check(pair[1].busy.busy_value == 2, "max_mana 2500: 19 - 25 is below 0, so busy 2")
	pair = _pair()
	context = _context(pair, Specials.Pattern.new([0, 100, 3, 0]))
	NpcSpecials.run(dun, context)
	_check(not pair[1].busy.is_busy() and pair[0].busy.busy_value == 1 and context.lines.size() == 3 and context.lines[2].template == DunSpell.ESCAPED and context.lines[2].color == ColoredLine.PLAIN, "random(ap + dp) not above dp: the target leaps free, the caster busy 1")
	pair = _pair()
	context = _context(pair, Specials.Pattern.new([0, 39]))
	_check(NpcSpecials.run(dun, context) and context.lines.is_empty() and pair[0].state.recovery.mana.current == 3800 and not pair[1].busy.is_busy(), "random(spells) below 40: 你失败了 (the caster alone), the cost spent")
	pair = _pair()
	pair[0].state.recovery.mana = CharacterInternalResourceState.new(199, 2000)
	_check(not NpcSpecials.run(dun, _context(pair, Specials.Pattern.new([0]))) and pair[0].state.recovery.mana.current == 199, "199 mana: 你的法力不够")


## saveme.c: 100 mana, 60 sen, the incantation; random(spells) below 60 brings nothing.
func _test_saveme() -> void:
	var saveme := NpcSpecialAction.new(NpcSpecialAction.Kind.CAST, &"", &"saveme")
	var pair: Array[SpecialSide] = _pair()
	var context: SpecialContext = _context(pair, Specials.Pattern.new([60]))
	_check(NpcSpecials.run(saveme, context) and context.summons == [SOLDIER] and context.lines.size() == 1 and context.lines[0].template == "$N喃喃地念了几句咒语。", "random(spells) 60: the soldier is called")
	_check(pair[0].state.recovery.mana.current == 3900 and pair[0].state.spirit.current == 240, "100 mana and 60 sen")
	context = _context(pair, Specials.Pattern.new([59]))
	_check(NpcSpecials.run(saveme, context) and context.summons.is_empty() and context.lines[1].template == "但是什麽也没有发生。", "59: nothing comes")
	pair[0].state.spirit = CharacterResourceState.new(59, 300, 300)
	_check(not NpcSpecials.run(saveme, _context(pair, Specials.Pattern.new())), "59 sen: 你的精神无法集中")
	var alone: Array[SpecialSide] = _pair()
	alone[0].relationship.remove_opponent(&"player")
	_check(not NpcSpecials.run(saveme, SpecialContext.new(alone[0], [], Specials.Pattern.new().legacy_random, _catalog)), "only in a fight")


## TEST-ONLY: 绝尘子's spells (150, 奇门遁甲 120, staff 10 and crown 5) with 4000 mana and
## 300 sen, fighting a player of 100000 combat_exp and no mana.
func _pair() -> Array[SpecialSide]:
	var state := CharacterState.new()
	state.skills.set_raw_level(&"spells", 150)
	state.skills.set_raw_level(&"magic-array", 120)
	state.skills.map_skill(&"spells", &"magic-array")
	state.recovery.mana = CharacterInternalResourceState.new(4000, 2000)
	state.spirit = CharacterResourceState.new(300, 300, 300)
	var player := CharacterState.new()
	player.progression.combat_experience = 100000
	var me_relationship := CombatRelationshipState.new(&"master")
	me_relationship.add_opponent(&"player")
	var player_relationship := CombatRelationshipState.new(&"player")
	player_relationship.add_opponent(&"master")
	var me := SpecialSide.new(&"master", state, ActionBusyState.new(), me_relationship, func(key: StringName) -> int: return 15 if key == &"spells" else 0)
	return [me, SpecialSide.new(&"player", player, ActionBusyState.new(), player_relationship)]


func _context(pair: Array[SpecialSide], random: CombatRandomSource) -> SpecialContext:
	return SpecialContext.new(pair[0], [pair[1]], random.legacy_random, _catalog, SkillImprovementEffectRegistry.new(), [pair[1]])


# --- Joining ------------------------------------------------------------------------

func _test_apprentice_rule() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var family: FamilyDefinition = _catalog.family(&"family.juechen")
	var student := CharacterState.new()
	student.gender = CharacterState.GENDER_FEMALE
	student.attributes.spirituality = 23
	student.progression.combat_experience = 100000
	var request := NpcApprenticeship.new()
	_check(request.request(student, master, family, 1, "姑娘") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines[1] == "绝尘子说道：入我派者，需有慧根。姑娘的资质不宜！", "spi 23: 需有慧根: %s" % [request.lines])
	student.attributes.spirituality = 24
	student.progression.combat_experience = 99999
	request = NpcApprenticeship.new()
	_check(request.request(student, master, family, 1, "姑娘") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines[1] == "绝尘子说道：姑娘似乎尚缺江湖历练，不宜投入绝尘门下。", "99999 combat_exp: 尚缺江湖历练")
	_check(not NpcApprenticeship.new().takes_at_once(student, master), "99999: the panel would not take her at once")
	student.progression.combat_experience = 100000
	request = NpcApprenticeship.new()
	_check(request.takes_at_once(student, master) and not request.would_attack(student, master, NpcApprenticeship.COMMONER_TITLE), "a commoner with spi 24 and 100000 combat_exp is taken at once")
	_check(request.request(student, master, family, 1, "姑娘") == NpcApprenticeship.Outcome.RECRUITED and student.affiliation.class_id == &"taoist" and student.family.family_id == &"family.juechen" and student.family.generation == 2, "taken: 绝尘派's second generation, class taoist: %s" % [request.lines])
	_check(request.lines[1] == "绝尘子说道：很好姑娘多加努力他日必定有成。" and request.lines.back() == "恭喜您成为绝尘派的第二代弟子。", "很好 and 恭喜: %s" % [request.lines])
	_check(NpcApprenticeship.family_title("绝尘派", 2, student.affiliation.family_title) == "绝尘派第二代弟子" and RankWords.query_rank(student.gender, &"taoist") == "【 女  冠 】" and RankWords.query_rank(CharacterState.GENDER_MALE, &"taoist") == "【 道  士 】", "绝尘派第二代弟子: 女冠, or 道士")
	var member := CharacterState.new()
	member.family = FamilyState.new(&"family.fonxan", 14)
	member.attributes.spirituality = 30
	request = NpcApprenticeship.new()
	_check(request.would_attack(member, master, "封山剑派第十四代弟子") and not request.takes_at_once(member, master, "封山剑派第十四代弟子"), "a family's member would be attacked, not taken")
	var outcome: NpcApprenticeship.Outcome = request.request(member, master, family, 1, "壮士", "封山剑派第十四代弟子", "封山剑派第十四代弟子", "阿青")
	_check(outcome == NpcApprenticeship.Outcome.ATTACKED and request.lines == ["你想要拜绝尘子为师。"] and request.chat_line == "【闲聊】绝尘子：封山剑派第十四代弟子阿青要叛师！！！", "a traitor: the chat line: %s" % request.chat_line)
	_check(member.family.family_id == &"family.fonxan" and member.progression.score == 0 and member.apprenticeship.betrayer_count == 0, "nothing else changes")
	_check(request.request(member, master, family, 1, "壮士", "封山剑派第十四代弟子") == NpcApprenticeship.Outcome.PENDING and not request.would_attack(member, master, "封山剑派第十四代弟子"), "asked again: 对方还没有答应 (apprentice.c), no second attack")


# --- The session --------------------------------------------------------------------

func _test_master_in_the_hall(_tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var master: NpcRuntimeState = _master(map)
	_check(master != null and master.world_location().zone_id == &"green.cavehall", "绝尘子 stands in the hall")
	if master == null:
		return
	var weapon: EquippedWeaponRef = master.character_state.equipment.primary_weapon()
	_check(weapon != null and weapon.weapon_id == STAFF, "the 金刚杖 in hand")
	_check(_carried_by(session, master.character_id).has(HAT) and master.armor.is_slot_occupied(&"head"), "the 紫金冠 worn")
	_check(master.character_state.skills.mapped_skill(&"spells") == &"magic-array" and master.character_state.recovery.mana.current == 4000, "奇门遁甲 for his spells, 4000 mana")
	var seal: ZoneExitRuleDefinition = _catalog.exit_rules_between(&"green.outdoor", &"green.cavehall")[0]
	_check(seal.npc_id == MASTER, "the seal names him")


## A family's member asks: asked first (owner), then 要叛师 on the chat channel and his kill.
func _test_traitor(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _master(map)
	_beside(tree, map, session, master)
	await tree.physics_frame
	# TEST-ONLY: a member of 封山剑派 with its title, and kee to outlast him.
	player.state.family = FamilyState.new(&"family.fonxan", 14)
	player.state.apprenticeship.master_teacher_id = &"common.npc.swordsman.master"
	player.state.apprenticeship.legacy_master_name = "柳淳风"
	player.state.affiliation.has_family_rank = true
	player.state.affiliation.family_title = "弟子"
	player.take_title("封山剑派第十四代弟子")
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var service: TeacherService = map.service(&"green.mountain.cavehall.master") as TeacherService
	_check(service != null and service.takes_apprentices(), "he takes apprentices")
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("绝尘子只收没有门派的普通百姓为徒。你现在是封山剑派第十四代弟子") and ui.confirm_text.text.contains("生死之战") and ui.confirm_button.text == "确定拜师", "asked first: %s" % ui.confirm_text.text)
	ui.keep_button.pressed.emit()
	_check(not ui.is_confirming() and not session.combat_encounter_coordinator().has_active_encounter(), "不拜了: nothing happens")
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: nobody's chat fires
	ui.apprentice_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and master.relationship.has_lethal_target(player.character_id) and not player.relationship.has_lethal_target(master.character_id), "he attacks to kill; the player only fights back")
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has("你想要拜绝尘子为师。") and log.has("【闲聊】绝尘子：封山剑派第十四代弟子%s要叛师！！！" % player.facts.display_name) and log.has("看起来绝尘子想杀死你！"), "the request, the chat line and kill_ob()'s warning: %s" % [log.slice(-4)])
	await _flee(tree, session)


## A commoner with spi 24 and 100000 combat_exp: his apprentice, a 道士; the seal lets them through.
func _test_join(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _master(map)
	# TEST-ONLY: back to a commoner without a family, with his spi and experience.
	player.state.family = FamilyState.new()
	player.state.apprenticeship.master_teacher_id = &""
	player.state.apprenticeship.legacy_master_name = ""
	player.state.affiliation = CharacterAffiliationState.new()
	player.take_title(NpcApprenticeship.COMMONER_TITLE)
	player.state.attributes.spirituality = 24
	player.state.progression.combat_experience = 100000
	player.apprenticeship_request.cancel()
	_beside(tree, map, session, master)
	await tree.physics_frame
	var service: TeacherService = map.service(&"green.mountain.cavehall.master") as TeacherService
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜绝尘子为师，便成为绝尘派的弟子"), "a first master: asked first")
	ui.confirm_button.pressed.emit()
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.state.affiliation.class_id == &"taoist" and player.shown_title() == "绝尘派第二代弟子", "his apprentice: %s" % [service.last_lines])
	var seal: ZoneExitRuleDefinition = _catalog.exit_rules_between(&"green.outdoor", &"green.cavehall")[0]
	_check(not seal.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, player.state.apprenticeship.master_teacher_id), false), "the seal lets his apprentice into the hall")
	var hud: SharedGameplayUI = session.shared_ui()
	ui.close_panel()
	hud.open_character()
	var sheet: String = hud._presentation_layout.character.sheet.text
	_check(sheet.contains(RankWords.query_rank(player.state.gender, &"taoist") + "绝尘派第二代弟子"), "score.c's rank: %s" % sheet.left(60))
	hud.dismiss_current_panel()
	# learn.c with each of his rules.
	player.state.progression.potential = 1000 # TEST-ONLY
	var learned: LearnResult = service.request_learn(&"magic-array")
	_check(learned.failure_reason == LearnResult.FailureReason.SKILL_LEARN_REJECTED and service.last_lines.has("你的小天魔道修为不够，无法领悟更高深的奇门遁甲之术。"), "奇门遁甲 needs more 小天魔道: %s" % [service.last_lines])
	learned = service.request_learn(&"jingang-staff")
	_check(learned.failure_reason == LearnResult.FailureReason.SKILL_LEARN_REJECTED and service.last_lines.has("你的膂力还不够，也许该练一练内力来增强力量。"), "金刚杖法 needs str + max_force / 10 of 50: %s" % [service.last_lines])
	var bellicosity: int = player.state.attributes.bellicosity
	for _attempt: int in range(40):
		if player.state.skills.raw_level(&"tao-mystery") > 0:
			break
		service.request_learn(&"tao-mystery")
	_check(player.state.skills.raw_level(&"tao-mystery") == 1 and player.state.attributes.bellicosity == bellicosity + 100, "小天魔道's first level: 100 bellicosity (skill_improved())")


## His fight: 召天将 brings a soldier against the player; it leaves when the fight is over.
func _test_soldier_leaves(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _master(map)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var soldier_id: StringName = await _fight_until_summoned(tree, session, master)
	var soldier: NpcRuntimeState = map.find_resident_npc(soldier_id)
	_check(soldier != null and SummonedNpc.definition_id_of(soldier_id) == SOLDIER and soldier.definition().name_pick().has(soldier.definition().display_name), "a 天X神兵 came: %s" % ("" if soldier == null else soldier.definition().display_name))
	if soldier == null:
		await _flee(tree, session)
		return
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter.participant_for(soldier_id) != null and encounter.participant_for(soldier_id).side_id == encounter.participant_for(master.character_id).side_id, "it fights on his side")
	_check(soldier.relationship.has_lethal_target(player.character_id) and player.relationship.has_opponent(soldier_id) and encounter.mode == CombatEncounterMode.Value.LETHAL, "it kills the player, who fights it back")
	var carried: Array[StringName] = _carried_by(session, soldier_id)
	_check(carried.has(ARMOR) and carried.has(SWORD) and soldier.character_state.equipment.primary_weapon().weapon_id == SWORD, "its 天兵战甲 and 金锋剑")
	var battle: String = _battle_log(session)
	var name: String = soldier.definition().display_name
	_check(battle.contains("绝尘子喃喃地念了几句咒语。") and battle.contains("一道金光由天而降，金光中走出一个身穿金色战袍的将官。") and battle.contains("%s说道：末将奉法主召唤，特来护法！" % name), "the incantation and its coming, in the battle log: %s" % battle.right(200))
	# Its name is in its lines, as it may be gone before they are read.
	var arrive := VisionLine.new("$N说道：末将奉法主召唤，特来护法！", &"gone")
	arrive.actor_name = name
	_check(BattleNarrator.seen([arrive], _ui(session).current_projection())[0].text == "%s说道：末将奉法主召唤，特来护法！" % name, "named without the fight's list")
	# 遁 at the player: his chat fires again (random(100) 0) and takes dun (random(4) 0).
	var forced := Forced.new()
	forced.queues[100] = [0]
	forced.queues[4] = [0]
	forced.queues[5] = [4]
	session.configure_combat_random_source(forced) # TEST-ONLY
	var mana: int = master.character_state.recovery.mana.current
	for _round: int in range(5):
		coordinator.advance_scheduler(1.0)
		_ui(session).refresh_projection()
		if master.character_state.recovery.mana.current < mana:
			break
	@warning_ignore("integer_division")
	var held: int = (mana - 200) / 200 + 2
	_check(master.character_state.recovery.mana.current == mana - 200 and player.busy.busy_value >= held - 1 and player.busy.busy_value <= held, "遁 holds the player %d rounds: %d" % [held, player.busy.busy_value])
	_check(_battle_log(session).contains("绝尘子口中喃喃地念著咒文，忽然大喝一声“疾！”") and _battle_log(session).contains("只见空中落下无数大木，正把你困在中央！"), "the chant and the trees falling round the player")
	var save: OldPineSaveEligibilityResult = OldPineSaveEligibility.inspect(session)
	_check(not save.allowed(), "no save while it is here: %s" % OldPineSaveEligibilityResult.Outcome.find_key(save.outcome))
	await _flee(tree, session)
	_check(map.find_resident_npc(soldier_id) == null and _count_items(session, ARMOR) == 0 and _count_items(session, SWORD) == 0, "it left with all it carried")
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has("%s说道：末将奉法主召唤，现在已经完成护法任务，就此告辞！" % name) and log.has("%s化成一道金光，冲上天际消失不见了。" % name), "its going: %s" % [log.slice(-3)])
	# Outside a fight a summoned NPC still blocks a save (it is never saved alive).
	var lone: StringName = map.summon_beside(master.character_id, SOLDIER) # TEST-ONLY
	save = OldPineSaveEligibility.inspect(session)
	_check(not lone.is_empty() and not save.allowed() and save.subject_id == lone, "a soldier standing outside a fight blocks the save: %s" % save.subject_id)
	map.dismiss_summoned()
	_check(map.find_resident_npc(lone) == null and _count_items(session, ARMOR) == 0, "dismissed, with its gear")


## The soldier falls: its corpse stays with its gear, and Save/Continue keeps it.
func _test_soldier_falls(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var master: NpcRuntimeState = _master(map)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var soldier_id: StringName = await _fight_until_summoned(tree, session, master)
	var soldier: NpcRuntimeState = map.find_resident_npc(soldier_id)
	if soldier == null:
		_check(false, "no soldier came")
		await _flee(tree, session)
		return
	var name: String = soldier.definition().display_name
	soldier.character_state.vitality.effective = -1 # TEST-ONLY: a mortal wound
	soldier.character_state.vitality.current = -1
	coordinator.advance_scheduler(1.0)
	_check(soldier.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "it dies")
	await _flee(tree, session)
	_check(map.find_resident_npc(soldier_id) == null and _count_items(session, ARMOR) == 1 and _count_items(session, SWORD) == 1, "its corpse keeps its gear")
	var corpse: CorpseState = null
	for state: CorpseState in map.corpse_states():
		if state.victim_character_id == soldier_id:
			corpse = state
	_check(corpse != null and corpse.victim_display_name == name, "its corpse: %s的尸体" % name)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.busy.advance() # TEST-ONLY: busy from his 遁 may linger
	while player.busy.is_busy():
		player.busy.advance()
	session.configure_combat_random_source(_original_random)
	# TEST-ONLY: the kee race/human.c gives back (Continue recomputes the maximum).
	player.state.vitality = CharacterResourceState.new(_kee, _kee, _kee)
	_check(OldPineSaveEligibility.inspect(session).allowed(), "after the fight Save is open")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "青石村 C")
	_check(walker._failures.is_empty(), "Save/Continue restores the soldier's corpse exactly: " + str(walker._failures))


## 冥思 and 修行 on the 武学 page; 法力 and 灵力 on the sheet.
func _test_cultivation(_tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	# TEST-ONLY: whole, spi 30, no spells or magic.
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	state.attributes.spirituality = 30
	state.recovery.mana = CharacterInternalResourceState.new(0, 100)
	state.recovery.atman = CharacterInternalResourceState.new(0, 100)
	var hud: SharedGameplayUI = session.shared_ui()
	hud.open_martial_arts()
	var page: MartialArtsPage = hud.martial_arts_page()
	page.refresh()
	_check(page.mana_text.text == "法力 0 / 100" and page.atman_text.text == "灵力 0 / 100", "the page shows 法力 and 灵力")
	page.meditate_amount.value = 30
	page.meditate_button.pressed.emit()
	_check(state.recovery.mana.current == 3 and state.spirit.current == state.spirit.maximum - 30 and session.martial_arts().last_lines[0].text == "你盘膝而坐，静坐冥思了一会儿。", "冥思 30 sen: 30 * (0 + 30) / 300 = 3 mana")
	page.respirate_amount.value = 30
	page.respirate_button.pressed.emit()
	_check(state.recovery.atman.current == 3 and session.martial_arts().last_lines[0].text == "你闭上眼睛开始打坐。", "修行 30 gin: 3 atman")
	page.meditate_amount.value = 10
	state.spirit.current = 5
	page.meditate_button.pressed.emit()
	_check(session.martial_arts().last_lines[0].text == "你现在精神太差了，进行冥思将会迷失，永远醒不过来！", "too little sen: meditate.c's warning")
	hud.dismiss_current_panel()
	hud.open_character()
	_check(hud._presentation_layout.character.sheet.text.contains("灵力 3 / 100 · 法力 3 / 100"), "the sheet: 灵力 and 法力")
	# meditate.c: past twice the maximum with no spells to carry it, the bottleneck: mana back to its maximum.
	state.recovery.mana = CharacterInternalResourceState.new(0, 0) # TEST-ONLY
	state.spirit.current = state.spirit.maximum
	page.meditate_amount.value = 30
	page.meditate_button.pressed.emit()
	_check(state.recovery.mana.current == 0 and session.martial_arts().last_lines[1].text.begins_with("当你的法力增加的瞬间"), "no spells: the bottleneck at once (max_mana 0 >= spells * 10)")
	hud.dismiss_current_panel()


# --- Helpers ------------------------------------------------------------------------

## The player attacks him; his chat fires (random(100) 0) and takes saveme (random(4) 1),
## which succeeds (random(spells) at its highest). Returns the soldier's ID.
func _fight_until_summoned(tree: SceneTree, session: OldPineWorldSessionController, master: NpcRuntimeState) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# TEST-ONLY: whole again, kee to outlast him, his mana and sen back.
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	master.character_state.recovery.mana.current = 4000
	master.character_state.spirit.current = master.character_state.spirit.effective
	_beside(tree, map, session, master)
	await tree.physics_frame
	var forced := Forced.new()
	forced.queues[100] = [0]
	forced.queues[4] = [1]
	session.configure_combat_random_source(forced) # TEST-ONLY
	map.select_npc(master.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 绝尘子")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var before: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		before.append(npc.character_id)
	for _round: int in range(10):
		coordinator.advance_scheduler(1.0)
		_ui(session).refresh_projection()
		for npc: NpcRuntimeState in map.npc_runtimes():
			if not before.has(npc.character_id):
				return npc.character_id
		if not coordinator.has_active_encounter():
			break
	return &""


func _flee(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no more chat
	for attempt: int in range(400):
		if not coordinator.has_active_encounter():
			break
		if coordinator.active_encounter().queued_player_action() == null:
			var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
			coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "fled: " + coordinator.last_abort_detail())
	_ui(session).refresh_projection()
	await tree.process_frame


func _ui(session: OldPineWorldSessionController) -> BattlePresentationController:
	return session.get_node("BattlePresentationLayer/BattleSurface")


func _battle_log(session: OldPineWorldSessionController) -> String:
	return _ui(session).log_panel._text.get_parsed_text()


func _master(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == MASTER_POINT:
			return npc
	return null


## TEST-ONLY: the player beside him, where his teaching reaches.
func _beside(_tree: SceneTree, map: WorldMapController, session: OldPineWorldSessionController, npc: NpcRuntimeState) -> void:
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, &"green.cavehall", body.global_position + Vector2(0, 56), 60.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(&"green.cavehall")), "TEST-ONLY: beside 绝尘子")


func _carried_by(session: OldPineWorldSessionController, character_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(id)
		if item != null:
			result.append(item.item_definition_id)
	return result


func _count_items(session: OldPineWorldSessionController, definition_id: StringName) -> int:
	var count: int = 0
	for id: StringName in session.item_instance_index().snapshot_ids():
		var item: ItemInstance = session.item_instance_index().resolve(id)
		if item != null and item.item_definition_id == definition_id and session.inventory_state().is_registered(id):
			count += 1
	return count


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("青石村 C: " + label)
