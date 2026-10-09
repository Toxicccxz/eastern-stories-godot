class_name NpcApprenticeTrial
extends RefCounted

## daemon/class/fighter/champion.c do_accept("test"): before each blow the master's
## line; the blow is combatd.c do_attack(master, student, its weapon) outside any fight
## (`attack`, which returns what the player saw, or null when no blow could be struck:
## then the test did not take place and says nothing); after it, a student whose kee went
## below zero or who is no longer there (`stands` false) did not stand it: the blow's
## failure line ends the test. Past the last blow, `success` and the master's recruit
## (NpcApprenticeship.npc_recruit()). The student falls only on the heart beat after
## (char.c), which the caller runs.
enum Outcome { NOT_RUN, FAILED, PASSED }


class Result:
	extends RefCounted
	var outcome: Outcome = Outcome.NOT_RUN
	## The blows that were struck (the failing one too).
	var blows: int = 0
	## The recruit's outcome after a passed test.
	var recruit: NpcApprenticeship.Outcome = NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var lines: Array[ColoredLine] = []


## `attack` () -> Array[ColoredLine] or null; `stands` () -> bool; `recruit` () -> Outcome
## after it set `request.lines` (NpcApprenticeship.npc_recruit()).
static func run(rule: NpcTeaching.ApprenticeRule, request: NpcApprenticeship, attack: Callable, stands: Callable, recruit: Callable) -> Result:
	var result := Result.new()
	if rule == null or rule.kind != NpcTeaching.Kind.TRIAL or rule.blows.is_empty():
		return result
	for blow: NpcTeaching.TrialBlow in rule.blows:
		result.lines.append(ColoredLine.new(_t(blow.say)))
		var struck: Variant = attack.call()
		if struck == null:
			# Nothing said for a test that never began.
			if result.blows == 0:
				result.lines.clear()
			result.outcome = Outcome.NOT_RUN
			return result
		var seen: Array[ColoredLine] = []
		seen.assign(struck)
		result.lines.append_array(seen)
		result.blows += 1
		if not bool(stands.call()):
			# elon.c's first: command("sigh"), command("shake"): emotes print nothing.
			if not blow.fail.is_empty():
				result.lines.append(ColoredLine.new(_t(blow.fail)))
			result.outcome = Outcome.FAILED
			return result
	result.lines.append(ColoredLine.new(_t(rule.success)))
	result.outcome = Outcome.PASSED
	result.recruit = recruit.call()
	for line: String in request.lines:
		result.lines.append(ColoredLine.new(line))
	return result


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
