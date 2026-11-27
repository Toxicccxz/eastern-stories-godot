extends SceneTree

## Opt-in measure of the 雪亭驿 board's pace (成长曲线 D; DECISIONS「成长曲线 D」; plan §4 row D): for
## each outlaw, from the exp a player first meets it on the board to its ceiling (pacing.json's
## bounty_ceiling_percent of its own exp), how much one bounty pays (MilestoneRewards, kind BOUNTY:
## priced at the player's own stage, no headroom), how many bounties that takes and how long at two
## paces: the board's own limit (`postings` per bounty_refresh_seconds of play time) and a round trip
## of `trip=` minutes (揭榜 at 雪亭驿, there, the fight, back; 4 by default). The combat trickle of
## the fights themselves and any 落后补偿 are left out. Never an autoload; tests/ is not in a release:
## <godot> --headless --path game --script res://tests/sim/run_bounty_pace_sim.gd -- [trip=<minutes>]

const Arrival := preload("res://tests/support/story_arrival.gd")

## Where each tier is first met by a player who follows the main story: A2's five where the
## ceiling's gap-filling hands them on (twice the last outlaw), the last four at the arrival after
## the chapter that opens them (StoryArrival.TUNED; past the finale, its end).
const FIRST_MET: Array[int] = [0, 200, 800, 2000, 5000, 11626, 21136, 31486, 48000]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var trip_minutes: float = 4.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("trip="):
			trip_minutes = float(arg.substr(5))
	var catalog: ContentCatalog = GameContent.catalog()
	var rules: BountyRules = catalog.bounties()
	var progression: ProgressionRules = catalog.progression()
	var pacing: PacingDefinition = catalog.pacing()
	var ceiling: int = pacing.bounty_ceiling_percent
	var board_per_hour: float = 3600.0 * rules.postings / maxf(1.0, float(pacing.bounty_refresh_seconds))
	var trip_per_hour: float = 60.0 / trip_minutes
	var per_hour: float = minf(board_per_hour, trip_per_hour)
	print("| 恶人 | 经验 | 碰到时 | 封顶 | 一张的历练（碰到时 → 封顶前） | 刷到封顶要几张 | 要多久（每小时 %.0f 张） |" % per_hour)
	print("|---|---|---|---|---|---|---|")
	for index: int in rules.tiers.size():
		var tier: BountyRules.Tier = rules.tiers[index]
		var outlaw: NpcDefinition = catalog.npc(tier.npc_id)
		@warning_ignore("integer_division")
		var top: int = outlaw.combat_experience * ceiling / 100
		var experience: int = FIRST_MET[index] if index < FIRST_MET.size() else tier.min_exp
		var first_pay: int = progression.reward_exp(ProgressionRules.Kind.BOUNTY, experience)
		var last_pay: int = first_pay
		var bounties: int = 0
		while experience < top and bounties < 10000:
			last_pay = progression.reward_exp(ProgressionRules.Kind.BOUNTY, experience)
			experience += last_pay
			bounties += 1
		print("| %s | %d | %d | %d | %d → %d | %d | %.1f 小时 |" % [outlaw.display_name, outlaw.combat_experience, FIRST_MET[index] if index < FIRST_MET.size() else tier.min_exp, top, first_pay, last_pay, bounties, bounties / per_hour])
	print("board limit %.1f an hour (%d postings, %d s refresh); a %.0f-minute round trip %.1f an hour" % [board_per_hour, rules.postings, pacing.bounty_refresh_seconds, trip_minutes, trip_per_hour])
	quit()
