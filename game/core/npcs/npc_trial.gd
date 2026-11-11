class_name NpcTrial
extends RefCounted

## Native (主线 第四章; DECISIONS「第四章 宝衣」): a test an NPC puts whoever asks it for
## something through, outside any 拜师 — 瑷伦 the 守衣人's 三鞭 for the 寒於宝衣. Its blows
## are elon.c do_accept()'s (NpcApprenticeTrial: a line, a blow outside any fight, the fall
## or the next), offered on the interaction popup as a row of its own (`label`) to one who
## holds every mark of `asker_marks` and lacks `unless_mark`, asked first (`confirm`). Past
## the last blow `success` is said, the player gets `mark` and the deed `deed` is written;
## one who falls may rest and come again. The NPC's 拜师 test, if it has one, is untouched.
## DECISIONS「考验三招」: a trial's blows may carry only `inner_force_percent` of the force
## hook's bonus and never kill (`lethal` false: the blows leave no wound and no condition, only
## kee lost; one who fails falls, wakes, rests and may come again); both default to elon.c's
## real do_attack() (100, true).

var label: String = ""
var asker_marks: Array[String] = []
var unless_mark: String = ""
var confirm: String = ""
var blows: Array[NpcTeaching.TrialBlow] = []
var success: String = ""
var mark: String = ""
var deed: String = ""
var inner_force_percent: int = 100
var lethal: bool = true


## The blows' modifiers for the resolver (CombatRoundModifiers), or null for elon.c's own.
func blow_modifiers() -> CombatRoundModifiers:
	if inner_force_percent == 100 and lethal:
		return null
	var modifiers := CombatRoundModifiers.new()
	modifiers.inner_force_percent = inner_force_percent
	modifiers.spare_life = not lethal
	return modifiers


## Whether a player with these marks is offered it now.
func offered_to(marks: Dictionary[String, int]) -> bool:
	if not unless_mark.is_empty() and marks.get(unless_mark, 0) != 0:
		return false
	for needed: String in asker_marks:
		if marks.get(needed, 0) == 0:
			return false
	return true


## The blows as an apprentice rule, for NpcApprenticeTrial.run() (a trial with no family).
func as_rule() -> NpcTeaching.ApprenticeRule:
	var rule := NpcTeaching.ApprenticeRule.new()
	rule.kind = NpcTeaching.Kind.TRIAL
	rule.blows = blows
	rule.success = success
	return rule


## {label, asker_marks?: [mark], unless_mark?, confirm, blows: [{say, fail?}], success, mark, deed?,
## inner_force_percent?: 0..100 (100), lethal?: bool (true)}.
static func from_record(reader: ContentRecordReader) -> NpcTrial:
	var trial := NpcTrial.new()
	trial.label = reader.required_text("label")
	trial.asker_marks = reader.text_list("asker_marks")
	trial.unless_mark = reader.text("unless_mark")
	trial.confirm = reader.required_text("confirm")
	for record: ContentRecordReader in reader.children("blows"):
		var blow := NpcTeaching.TrialBlow.new()
		blow.say = record.required_text("say")
		blow.fail = record.text("fail")
		record.finish()
		trial.blows.append(blow)
	if trial.blows.is_empty():
		reader.fail("blows", "a trial needs at least one blow")
	trial.success = reader.required_text("success")
	trial.mark = reader.required_text("mark")
	trial.deed = reader.text("deed")
	trial.inner_force_percent = reader.integer("inner_force_percent", 100)
	if trial.inner_force_percent < 0 or trial.inner_force_percent > 100:
		reader.fail("inner_force_percent", "a percent from 0 to 100")
	trial.lethal = reader.boolean("lethal", true)
	reader.finish()
	return trial
