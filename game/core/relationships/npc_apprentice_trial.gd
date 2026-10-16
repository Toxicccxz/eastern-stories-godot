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
##
## ES2 strikes the blows in one command, and so does run(); the game then tells a passed
## test blow by blow (`steps`, pacing.json's trial_blow_ms apart: DECISIONS「响应性」).
enum Outcome { NOT_RUN, FAILED, PASSED }


class Result:
	extends RefCounted
	var outcome: Outcome = Outcome.NOT_RUN
	## The blows that were struck (the failing one too).
	var blows: int = 0
	## The recruit's outcome after a passed test.
	var recruit: NpcApprenticeship.Outcome = NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var lines: Array[ColoredLine] = []
	## `lines` blow by blow: each blow's line and what it did, the last with the end.
	var steps: Array[Array] = []


## A test under way: step() strikes the next blow.
class Run:
	extends RefCounted
	var result := Result.new()
	## Every blow struck or the test over.
	var finished: bool = false
	var _rule: NpcTeaching.ApprenticeRule
	var _request: NpcApprenticeship
	var _attack: Callable
	var _stands: Callable
	var _recruit: Callable
	var _next: int = 0

	func _init(rule: NpcTeaching.ApprenticeRule, request: NpcApprenticeship, attack: Callable, stands: Callable, recruit: Callable) -> void:
		_rule = rule
		_request = request
		_attack = attack
		_stands = stands
		_recruit = recruit
		finished = rule == null or rule.kind != NpcTeaching.Kind.TRIAL or rule.blows.is_empty()

	## How many blows the test has.
	func blow_count() -> int:
		return 0 if _rule == null else _rule.blows.size()

	## The next blow, with its line before it and the end after it; the lines of this step.
	func step() -> Array[ColoredLine]:
		var lines: Array[ColoredLine] = []
		if finished:
			return lines
		var blow: NpcTeaching.TrialBlow = _rule.blows[_next]
		_next += 1
		lines.append(ColoredLine.new(NpcApprenticeTrial._t(blow.say)))
		var struck: Variant = _attack.call()
		if struck == null:
			finished = true
			# Nothing said for a test that never began.
			if result.blows == 0:
				lines.clear()
				return lines
			result.outcome = Outcome.NOT_RUN
			result.lines.append_array(lines)
			return lines
		var seen: Array[ColoredLine] = []
		seen.assign(struck)
		lines.append_array(seen)
		result.blows += 1
		if not bool(_stands.call()):
			# elon.c's first: command("sigh"), command("shake"): emotes print nothing.
			if not blow.fail.is_empty():
				lines.append(ColoredLine.new(NpcApprenticeTrial._t(blow.fail)))
			finished = true
			result.outcome = Outcome.FAILED
		elif _next >= _rule.blows.size():
			lines.append(ColoredLine.new(NpcApprenticeTrial._t(_rule.success)))
			finished = true
			result.outcome = Outcome.PASSED
			result.recruit = _recruit.call()
			for line: String in _request.lines:
				lines.append(ColoredLine.new(line))
		result.lines.append_array(lines)
		return lines


## `attack` () -> Array[ColoredLine] or null; `stands` () -> bool; `recruit` () -> Outcome
## after it set `request.lines` (NpcApprenticeship.npc_recruit()).
static func start(rule: NpcTeaching.ApprenticeRule, request: NpcApprenticeship, attack: Callable, stands: Callable, recruit: Callable) -> Run:
	return Run.new(rule, request, attack, stands, recruit)


## champion.c: every blow in one go.
static func run(rule: NpcTeaching.ApprenticeRule, request: NpcApprenticeship, attack: Callable, stands: Callable, recruit: Callable) -> Result:
	var test: Run = start(rule, request, attack, stands, recruit)
	while not test.finished:
		var told: Array[ColoredLine] = test.step()
		if not told.is_empty():
			test.result.steps.append(told)
	return test.result


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
