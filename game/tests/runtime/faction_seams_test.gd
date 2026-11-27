extends RefCounted

## 修补 Z (the review's completeness round, 2026-11-19), the small seams of the 势力 lines: the two 龙头 each refuse
## one who acknowledged the other; 朱鸿雪 gives another 黑木令 to one who lost theirs; 乔阴's 骆云舟 is not at the gate
## while he is in the capital; the false 帮闲 of 雪亭's south street go once the 封山 line has ended.

const LU: StringName = &"common.npc.beggar.master"
const TRUE_HEAD: StringName = &"native.npc.lu_decai_home"
const ZHU: StringName = &"cloud.npc.god"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_two_heads()
	_test_token_given_again()
	_test_luo_at_the_gate()
	_test_liaochen_knows_the_temple()
	_test_false_helpers_go()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
	return state


## The rule `npc` answers `topic` with; its marks set on the state as the ask records them (TEST-ONLY).
func _answer(state: CharacterState, npc: StringName, topic: String) -> NpcInquiryRule:
	var rule: NpcInquiryRule = NpcInquiryRule.decide(GameContent.catalog().npc(npc).talk().inquiry_rules(topic), state.marks)
	if rule != null:
		if not rule.mark_asker.is_empty():
			state.marks[rule.mark_asker] = 1
		for mark: String in rule.marks_asker:
			state.marks[mark] = 1
	return rule


func _says(rule: NpcInquiryRule, part: String) -> bool:
	return rule != null and rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _holds(condition: JournalEntryDefinition, state: CharacterState) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return condition == null or JournalLog.holds(condition, state, temps, held)


func _test_two_heads() -> void:
	var state: CharacterState = _fresh(["福林大街碰了面", "认了二十三个结", "花紫会的票随了真龙头"])
	var rule: NpcInquiryRule = _answer(state, LU, "龙头")
	_check(_says(rule, "不认两个龙头") and not state.marks.has("认了管事的陆得财") and not state.marks.has("花紫会的票随了陆得财") and rule.also_leaves.is_empty(), "陆得财 refuses one who acknowledged the 真龙头")
	state = _fresh(["福林大街碰了面", "认了管事的陆得财", "花紫会的票随了陆得财"])
	rule = _answer(state, TRUE_HEAD, "龙头")
	_check(_says(rule, "不认两个龙头") and not state.marks.has("认了二十三个结") and not state.marks.has("花紫会的票随了真龙头") and not rule.pardons_thief, "the 真龙头 refuses one who acknowledged 陆得财")
	state = _fresh(["福林大街碰了面"])
	_answer(state, LU, "龙头")
	_check(state.marks.has("认了管事的陆得财") and state.marks.has("花紫会的票随了陆得财"), "before either: 陆得财 is acknowledged as ever")


func _test_token_given_again() -> void:
	var held: NpcInquiryRule = _answer(_fresh(["持黑木令"]), ZHU, "令牌")
	_check(held != null and held.gives == TOKEN and _says(held, "别再丢了"), "持黑木令 without it: 朱鸿雪 gives another")
	var found: CharacterState = _fresh(["取了黑木令"])
	var rule: NpcInquiryRule = _answer(found, ZHU, "令牌")
	_check(rule != null and rule.gives == TOKEN and found.marks.has("持黑木令"), "the reeds' token lost before she saw it: another, and it is yours")
	var errand: NpcInquiryRule = _answer(_fresh(["朱鸿雪说了三个名字", "持黑木令"]), ZHU, "交差")
	_check(errand != null and errand.gives == TOKEN and _says(errand, "再来交差"), "交差 without the token: another, then report")


func _test_luo_at_the_gate() -> void:
	var gate: NpcSpawnDefinition = GameContent.catalog().spawn(&"choyin.town.entrance.master")
	_check(gate != null and gate.present != null and gate.resident and gate.away_for_a_while and gate.remade_by_reset(), "乔阴's 骆云舟: an ES2 resident, away for a while, remade by his room's reset")
	if gate == null:
		return
	_check(_holds(gate.present, _fresh([])), "at the gate as ever")
	_check(not _holds(gate.present, _fresh(["骆云舟听了抄本的事"])), "not while he is in the capital for his brother")
	_check(_holds(gate.present, _fresh(["骆云舟听了抄本的事", "骆建章作了证"])) and _holds(gate.present, _fresh(["骆云舟听了抄本的事", "保住了骆家"])), "back once the brothers chose")
	_check(_holds(gate.present, _fresh(["骆云舟听了抄本的事", "步玄的线断了"])), "back when the line ended (the capital one stays away)")
	var capital: NpcSpawnDefinition = GameContent.catalog().spawn(&"native.xiangguo.luo_yunzhou")
	for marks: Array in [[], ["骆云舟听了抄本的事"], ["骆云舟听了抄本的事", "骆建章作了证"], ["骆云舟听了抄本的事", "保住了骆家"], ["骆云舟听了抄本的事", "步玄的线断了"]]:
		var state: CharacterState = _fresh(marks)
		var there: bool = _holds(capital.present, state) and not (capital.until != null and _holds(capital.until, state))
		_check(there != _holds(gate.present, state), "one 骆云舟 at a time (%s)" % [marks])
	# 势力线复查 第 23 条: the one in the capital answers 「虹台」 too (乔阴's is away while the brothers' matter is open).
	var catalog: ContentCatalog = GameContent.catalog()
	var talk: NpcTalk = catalog.npc(&"native.npc.luo_yunzhou_capital").talk()
	_check(not talk.listed_for("虹台", _fresh(["骆云舟听了抄本的事"]).marks) and talk.listed_for("虹台", _fresh(["骆云舟听了抄本的事", "终章"]).marks), "the capital's 骆云舟: 虹台 on his list once the 终章 began")
	var asked: CharacterState = _fresh(["骆云舟听了抄本的事", "终章"])
	var rule: NpcInquiryRule = _answer(asked, &"native.npc.luo_yunzhou_capital", "虹台")
	_check(_says(rule, "颜违") and _says(rule, "再问我一回") and asked.marks.get("步玄表了态", 0) == 1 and not asked.marks.has("步玄肯听你的"), "he says how 步玄 votes while it is open, and counts as asked")
	_check(_holds(catalog.conditions()["assembly.buxuan.stated"], asked) and _holds(catalog.conditions()["assembly.buxuan.yan"], asked), "the tally reads it: 步玄 stated, for 颜违")
	asked.marks["骆建章作了证"] = 1 # TEST-ONLY: the brothers chose; he is back at 乔阴's gate
	asked.marks["步玄的票随了作证"] = 1 # TEST-ONLY
	rule = _answer(asked, &"common.npc.scholar.master", "虹台")
	_check(_says(rule, "这一票，你要，就是你的") and asked.marks.get("步玄肯听你的", 0) == 1, "asked again at 乔阴 once it is settled: the vote can still be had")
	_check(_says(_answer(_fresh(["骆云舟听了抄本的事", "终章", "大会散了"]), &"native.npc.luo_yunzhou_capital", "虹台"), "骆家记下了"), "after the 大会: no vote to speak of")


## 势力线复查 第 12 条: 了尘's story of thirty years ago knows what 山烟寺 already chose.
func _test_liaochen_knows_the_temple() -> void:
	const LIAOCHEN: StringName = &"native.npc.juechen_liaochen"
	const TOLD: Array = ["了尘说了洞里的事", "喂了樵夫药"]
	for small: String in ["头陀进了流云轩", "守了寺规"]:
		var open: NpcInquiryRule = _answer(_fresh(TOLD + [small]), LIAOCHEN, "师父")
		_check(_says(open, "我要回山烟寺去") and not _says(open, "你在场，你知道"), "%s, 山烟寺 not chosen yet: the story as it was" % small)
		var took: CharacterState = _fresh(TOLD + [small, "山烟寺收了经"])
		var taken: NpcInquiryRule = _answer(took, LIAOCHEN, "师父")
		_check(_says(taken, "进了门") and _says(taken, "我要回山烟寺去") and took.marks.get("了尘说了玄尘", 0) == 1, "%s, the sutra taken in: he says so, and the story still ends in 「玄尘」" % small)
		var kept: CharacterState = _fresh(TOLD + [small, "山烟寺守了寺"])
		var guarded: NpcInquiryRule = _answer(kept, LIAOCHEN, "师父")
		_check(_says(guarded, "头陀回了番坊") and _says(guarded, "我要回山烟寺去") and kept.marks.get("了尘说了玄尘", 0) == 1, "%s, the temple kept to itself: he says so" % small)
		_check(taken != null and open != null and taken.lines.size() == open.lines.size() + 1, "one line more, nothing dropped")


func _test_false_helpers_go() -> void:
	for spawn_id: StringName in [&"native.sroad3.fake_head", &"native.sroad3.fake_disciples"]:
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
		var running := _fresh([])
		running.quests["faction.fonxan/hear"] = 1 # TEST-ONLY
		_check(spawn != null and _holds(spawn.present, running), "%s on the south street while the line runs" % spawn_id)
		running.marks["封山的线断了"] = 1 # TEST-ONLY
		_check(spawn != null and not _holds(spawn.present, running), "%s gone once the 封山 line ended" % spawn_id)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
