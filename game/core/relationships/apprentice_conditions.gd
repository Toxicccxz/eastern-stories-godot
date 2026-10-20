class_name ApprenticeConditions
extends RefCounted

## A master's conditions for taking the student, with the student's own values (owner,
## 2026-10-19; DECISIONS「上限预览和拜师条件」): each attempt_apprentice() check a row met or
## not ("定力 ≥ 20（你 30）"), then what the master asks beyond its checks without saying
## it before (a test, an oath, a letter) as rows that tell nothing more (owner Q3). A
## mark the master wants (marks/桃林) is told only by the master's own refusal, once the
## student has heard it. The popup's 拜师 page lists the rows, 查看 counts them.

enum State { MET, UNMET, UNSAID }


class Row:
	extends RefCounted
	var text: String
	var state: State

	func _init(p_text: String, p_state: State) -> void:
		text = p_text
		state = p_state


# TRANSLATORS: a 拜师 condition: an attribute ({what}: 胆识, 定力, 灵性, 实战经验) at least {required}; the student has {have}.
const AT_LEAST: String = "{what} ≥ {required}（你 {have}）"
# TRANSLATORS: the attributes attempt_apprentice() checks, as the character sheet names them.
const ATTRIBUTES: Dictionary[StringName, String] = {&"cor": "胆识", &"cps": "定力", &"spi": "灵性", &"combat_exp": "实战经验"}
# TRANSLATORS: a 拜师 condition: the gender the master takes (taolord.c, dancer master.c).
const GENDERS: Dictionary[String, String] = {"男性": "只收男弟子", "女性": "只收女弟子"}
# TRANSLATORS: a 拜师 condition: the class the master takes (bonze master.c: 剃度 first).
const CLASSES: Dictionary[StringName, String] = {&"bonze": "须先剃度出家"}
# TRANSLATORS: a 拜师 condition of a class this table does not name.
const OTHER_CLASS: String = "身份须合师门的规矩"
# TRANSLATORS: a 拜师 condition the master does not say before he is asked (a mark: scholar master.c's 桃林); met or not.
const UNSAID_MARK: String = "另有条件"
# TRANSLATORS: the same, not met, the master not asked yet.
const UNSAID_MARK_UNMET: String = "另有条件（拜师时便知）"
# TRANSLATORS: the same, not met, once the master ({npc}) said what it is: {line} his refusal.
const SAID_MARK: String = "{npc}说过：{line}"
# TRANSLATORS: a 拜师 condition (beggar master.c can_afford()): the student carries less than {money}.
const POOR: String = "身上的钱不到{money}"
# TRANSLATORS: a 拜师 condition (juechen master.c, elon.c): one who belongs to a family is taken for a traitor.
const COMMONERS: String = "只收没有门派的人"
# TRANSLATORS: a 拜师 condition: the master's test (champion.c's 三招, elon.c's 三鞭), not told before.
const TRIAL: String = "须通过考验"
# TRANSLATORS: a 拜师 condition: the master asks for something when asked (master.c's oath), not told before.
const OATH: String = "拜师时另有要求"
# TRANSLATORS: a 拜师 condition: the master takes no one who just asks (chen.c); how, not told before.
const SILENT: String = "须另有机缘"
# TRANSLATORS: the master takes no apprentice at all (annihi.c).
const REFUSES: String = "不收徒"
# TRANSLATORS: the master has said he will take the student (recruit.c's offer, a test passed).
const OFFERED: String = "{npc}已经愿意收你"
# TRANSLATORS: money in a 拜师 condition: {n} taels of gold, of silver, or coins.
const GOLD: String = "{n} 两黄金"
# TRANSLATORS: money in a 拜师 condition: {n} taels of silver.
const SILVER: String = "{n} 两银子"
# TRANSLATORS: money in a 拜师 condition: {n} coins.
const COINS: String = "{n} 文钱"


## The rows for `student` and `master`; `request` the student's 拜师 state (offers),
## `affords` can_afford(price) of the student, `student_title` their title as ES2 keeps it,
## `respect` how the master addresses them ($RESPECT). Empty for one who takes no one or
## is already their master.
static func of(student: CharacterState, master: NpcDefinition, request: NpcApprenticeship, affords: Callable, student_title: String, respect: String) -> Array[Row]:
	var rows: Array[Row] = []
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or NpcApprenticeship.is_master_of(student, master):
		return rows
	var npc: String = _t(master.display_name)
	var rule: NpcTeaching.ApprenticeRule = teaching.apprentice
	if request != null and request.is_offered(master.definition_id):
		rows.append(Row.new(_t(OFFERED).format({"npc": npc}), State.MET))
		return rows
	match rule.kind:
		NpcTeaching.Kind.REFUSES:
			rows.append(Row.new(_t(REFUSES), State.UNMET))
			return rows
		NpcTeaching.Kind.SILENT:
			rows.append(Row.new(_t(SILENT), State.UNSAID))
			return rows
		NpcTeaching.Kind.OATH:
			rows.append(Row.new(_t(OATH), State.UNSAID))
			return rows
	for check: NpcTeaching.RequirementCheck in rule.checks:
		if not check.gender.is_empty():
			rows.append(Row.new(_t(GENDERS.get(check.gender, OTHER_CLASS)), _state(String(student.gender) == check.gender)))
		if not check.class_id.is_empty():
			rows.append(Row.new(_t(CLASSES.get(check.class_id, OTHER_CLASS)), _state(student.affiliation.class_id == check.class_id)))
		if not check.mark.is_empty():
			rows.append(_mark_row(student, check, npc, respect))
		if check.cannot_afford > 0 and affords.is_valid():
			rows.append(Row.new(_t(POOR).format({"money": money(check.cannot_afford)}), _state(not bool(affords.call(check.cannot_afford)))))
		for key: StringName in check.requires:
			var have: int = NpcApprenticeship.requirement_value(student, key)
			rows.append(Row.new(
				_t(AT_LEAST).format({"what": _t(ATTRIBUTES.get(key, String(key))), "required": check.requires[key], "have": have}),
				_state(have >= check.requires[key]),
			))
	if not rule.commoners_only.is_empty():
		rows.append(Row.new(_t(COMMONERS), _state(student_title == NpcApprenticeship.COMMONER_TITLE)))
	if rule.kind == NpcTeaching.Kind.TRIAL:
		rows.append(Row.new(_t(TRIAL), State.UNSAID))
	return rows


## Owner Q3: a mark is told by the master's own refusal once the student has heard it
## (the refusal sets its refuse_marks: marks/书生); before that only that there is more.
static func _mark_row(student: CharacterState, check: NpcTeaching.RequirementCheck, npc: String, respect: String) -> Row:
	if student.marks.get(check.mark, 0) != 0:
		return Row.new(_t(UNSAID_MARK), State.MET)
	var heard: bool = not check.refuse_marks.is_empty()
	for mark: String in check.refuse_marks:
		heard = heard and student.marks.get(mark, 0) != 0
	if heard and not check.refuse_say.is_empty():
		var line: String = NpcTalk.line(check.refuse_say).replace("$RESPECT", _t(respect)).strip_edges()
		return Row.new(_t(SAID_MARK).format({"npc": npc, "line": line}), State.UNMET)
	return Row.new(_t(UNSAID_MARK_UNMET), State.UNMET)


## Coins as gold, silver or coins (10000 and 100 to the tael, ES2's money).
@warning_ignore("integer_division")
static func money(coins: int) -> String:
	if coins % 10000 == 0:
		return _t(GOLD).format({"n": coins / 10000})
	if coins % 100 == 0:
		return _t(SILVER).format({"n": coins / 100})
	return _t(COINS).format({"n": coins})


## The rows that are met and the rows told: [met, told]; UNSAID rows count in neither.
static func counts(rows: Array[Row]) -> Array[int]:
	var met: int = 0
	var told: int = 0
	for row: Row in rows:
		if row.state != State.UNSAID:
			told += 1
			met += 1 if row.state == State.MET else 0
	return [met, told]


static func _state(met: bool) -> State:
	return State.MET if met else State.UNMET


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
