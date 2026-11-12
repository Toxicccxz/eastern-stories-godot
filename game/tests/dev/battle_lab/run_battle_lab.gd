extends SceneTree

## Dev only: battle-lab fights from the command line (BattleLabFight), for comparing families,
## levels and numbers without the panel. Never an autoload; tests/ is not in a release.
##
## <godot> --headless --fixed-fps 60 --path game --script res://tests/dev/battle_lab/run_battle_lab.gd -- <args>
##   me=<family>:<level>        the player (family id, or "-" for the story-grown sword build)
##   ally=<fighter> foe=<fighter>  repeatable; a fighter is <family id or npc:<definition id>>[:<level>][x<count>]
##   place=<zone id>  n=<duels> (20)  seed=<n> (7)  spec=<json file, from the project's parent folder>
##   verbose            print each duel's end
##   families           list the families and their template NPCs, then quit
## e.g. -- me=family.fonxan:30 foe=family.celestial:30 n=40
##      -- me=-:20 ally=npc:snow.npc.girl foe=npc:oldpine.npc.bandit:0x3

const Roster := preload("res://tests/dev/battle_lab/battle_lab_roster.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TestFeel.turn_off()
	TestAway.turn_off()
	TestAlert.turn_off()
	TestDay.turn_off()
	TestDeath.turn_off()
	WorldSessionController.keep_map_scenes = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("families"):
		for family: BattleLabRoster.Family in Roster.families():
			var template: NpcDefinition = GameContent.catalog().npc(family.template_id)
			print("%s\t%s\t%s（%s）\texp %d\t%s" % [family.family_id, family.display_name, template.display_name, family.template_id, family.template_exp, Roster.weapon_of(template)])
		quit()
		return
	var spec: Dictionary = {"player": {"family": "", "level": 20}, "allies": [], "foes": []}
	var duels: int = 20
	for arg: String in args:
		var key: String = arg.get_slice("=", 0)
		var value: String = arg.substr(key.length() + 1)
		match key:
			"spec":
				spec = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../" + value)))
			"me":
				spec["player"] = {"family": "" if value.get_slice(":", 0) == "-" else value.get_slice(":", 0), "level": int(value.get_slice(":", 1)) if value.contains(":") else 20}
			"ally":
				spec["allies"].append(fighter(value))
			"foe":
				spec["foes"].append(fighter(value))
			"place":
				spec["place"] = value
			"seed":
				spec["seed"] = int(value)
			"n":
				duels = int(value)
	print("SPEC %s" % JSON.stringify(spec))
	var fight := BattleLabFight.new(self)
	fight.verbose = args.has("verbose")
	if not await fight.setup(spec):
		print("SETUP FAILED: %s" % fight.error)
		await fight.close()
		quit(1)
		return
	var result: BattleLabFight.Result = await fight.run(duels, int(spec.get("seed", 7)))
	print(result.summary())
	print("LAB DONE")
	await fight.close()
	quit()


## <family id | npc:<definition id>>[:<level>][x<count>]
static func fighter(text: String) -> Dictionary:
	var count: int = 1
	if text.contains("x"):
		var tail: String = text.get_slice("x", text.get_slice_count("x") - 1)
		if tail.is_valid_int():
			count = int(tail)
			text = text.substr(0, text.length() - tail.length() - 1)
	var out: Dictionary = {"count": count}
	var parts: PackedStringArray = text.split(":")
	if parts[0] == "npc":
		out["npc"] = parts[1]
		out["level"] = int(parts[2]) if parts.size() > 2 else 0
	else:
		out["family"] = parts[0]
		out["level"] = int(parts[1]) if parts.size() > 1 else 0
	return out
