extends RefCounted

## 战斗拍数 C (DECISIONS「战斗拍数 C」): the fight in the scene and its sounds, off a session —
## the figures are bare models under a view's actor nodes. The templates by tag (快 / 重 / 虚 /
## 守 / 平), every duration from the feel and 0 = nothing moves, the three signatures of a hit
## (克 / 相持 / 被克: the flash's colour and how far the one hit falls back), the hit-stop only
## where it belongs, the camera moving twice, 柳家拳's close as the figures standing nearer,
## everyone home between rounds; the sounds rationed by weight and a beat won in full only the
## first time; the 总音量 setting. Rules, numbers and the fight's draws are untouched.
const Outcome := CombatAttackResult.Outcome
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
const ME: StringName = &"me"
const YOU: StringName = &"you"

var assertions: int = 0
var failures: Array[String] = []
var _root: Node3D
var _view: WorldVoxelView
var _show: BattleSceneShow


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_feel_keys()
	_sound_ration()
	_volume_setting()
	await _feel_off_moves_nothing(tree)
	await _templates(tree)
	await _signatures(tree)
	await _camera_and_stance(tree)
	await _heavy_aftermath(tree)
	await _limbs(tree)
	_fall_curve()
	await _blow_effects(tree)
	await _stage_answers(tree)
	_mode_title(tree)
	_teardown(tree)
	TestFeel.restore()
	BattlePace.speed = BattlePace.Speed.NORMAL
	return {"assertions": assertions, "failures": failures}


## pacing.json carries the nine durations; left out they are 0.
func _feel_keys() -> void:
	var feel: FeelDefinition = TestFeel.production
	var seconds: Array[float] = [
		feel.scene_step_seconds, feel.scene_windup_seconds, feel.hit_stop_seconds, feel.scene_flash_seconds, feel.scene_dust_seconds,
		feel.afterimage_seconds, feel.scene_return_seconds, feel.beat_pause_seconds, feel.battle_zoom_seconds,
	]
	check(seconds == [0.12, 0.3, 0.1, 0.06, 0.26, 0.18, 0.32, 0.14, 0.5], "pacing.json: the nine durations: %s" % [seconds])
	var off := FeelDefinition.new()
	check(off.scene_step_seconds == 0.0 and off.hit_stop_seconds == 0.0 and off.battle_zoom_seconds == 0.0, "left out: 0")
	check(feel.hit_stop_seconds >= 0.08 and feel.hit_stop_seconds <= 0.12, "the hit-stop within 80–120 ms")
	# 战斗拍数 E: a 重 is two beats and looks it — the windup, the long lunge and the longer freeze
	# within 0.7 s; a 快's lunge is over in a tenth of that.
	check(feel.scene_windup_seconds + feel.scene_step_seconds * 1.3 + feel.hit_stop_seconds * BattleSceneShow.HEAVY_STOP <= 0.7, "a 重 that lands plays out within 0.7 s")
	check(feel.scene_step_seconds * BattleSceneShow.QUICK_LUNGE <= 0.07, "a 快 lands within 0.07 s")


## The sounds a told line asks for, by weight: 普通 < 克制 < 绝招 < 致命; a miss by its tag; a
## beat won in full the first time only.
func _sound_ration() -> void:
	var plain: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0), false, false)
	check(plain == [[BattleSounds.THUD, 1.0, BattleSounds.PLAIN_HIT_DB]], "a plain hit: the thud, a little under: %s" % [plain])
	var counter: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 1), false, false)
	check(counter == [[BattleSounds.THUD, 1.0, 0.0], [BattleSounds.CRACK, 1.0, 0.0]], "a 克 hit: the thud with the crack over it: %s" % [counter])
	var countered: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, -1), false, false)
	check(countered == [[BattleSounds.THUD, 1.0, BattleSounds.COUNTERED_HIT_DB]], "a 被克 hit: the thud alone, quieter: %s" % [countered])
	var heavy: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.HEAVY, 0), false, false)
	check(heavy == [[BattleSounds.THUD, 1.0, 0.0], [BattleSounds.DRUM, 1.0, BattleSounds.DRUM_DB]], "a 重 that lands: the drum under the thud: %s" % [heavy])
	var special: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0).with_special_blow(), false, false)
	check(special.size() == 2 and special[1][0] == BattleSounds.DRUM, "a special's blow: the drum too")
	var fatal: Array[Array] = BattleSounds.for_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 1), true, false)
	check(fatal.size() == 3 and fatal[2] == [BattleSounds.DRUM, 1.0, BattleSounds.FATAL_DRUM_DB], "a felling 克 hit: thud, crack and the drum loud: %s" % [fatal])
	check(BattleSounds.for_line(_blow(Outcome.DODGE, CombatMoveTags.QUICK, 0), false, false) == [[BattleSounds.WHOOSH, BattleSounds.WHOOSH_QUICK_PITCH, 0.0]], "a 快 missed: the whoosh high")
	check(BattleSounds.for_line(_blow(Outcome.DODGE, CombatMoveTags.HEAVY, 0), false, false) == [[BattleSounds.WHOOSH, BattleSounds.WHOOSH_HEAVY_PITCH, 0.0]], "a 重 missed: the whoosh low")
	check(BattleSounds.for_line(_blow(Outcome.PARRY, &"", 0), false, false) == [[BattleSounds.CLANG, 1.0, 0.0]], "a parry: the clang")
	var earned := BattleNarrationLine.new("你抢得一手（隙）！").with_cue(BattleNarrationLine.CUE_EARNED)
	check(BattleSounds.for_line(earned, false, true) == [[BattleSounds.CLAPPER, BattleSounds.EARNED_PITCH, BattleSounds.EARNED_FIRST_DB]], "a beat won: the clap an octave up, loud the first time")
	check(BattleSounds.for_line(earned, false, false) == [[BattleSounds.CLAPPER, BattleSounds.EARNED_PITCH, BattleSounds.EARNED_AGAIN_DB]], "and quiet after")
	check(BattleSounds.for_line(BattleNarrationLine.new("野狗咆哮。"), false, false).is_empty() and BattleSounds.for_line(BattleNarrationLine.new("x").with_special(ME, "「封」"), false, false).is_empty(), "plain words and a special's opening line: nothing (its blows sound)")
	for kind: StringName in BattleSounds.FILES:
		check(ResourceLoader.exists(BattleSounds.DIRECTORY + BattleSounds.FILES[kind]), "the file of %s is there" % kind)
	# The narrator marks the ring on a blow's line and the cue on a beat won.
	var cast := BattlePresentationProjection.new(&"e", 0, ME, YOU, [], [], null, 0, -1, -1)
	var noted: Array[BattleNarrationLine] = BattleNarrator.seen([VisionLine.new("$N抢得一手（隙）！", ME, &"", ColoredLine.HIY)], cast)
	check(noted.size() == 1 and noted[0].cue == BattleNarrationLine.CUE_EARNED, "the scheduler's 抢得一手 note carries the cue")
	check(BattleNarrator.seen([VisionLine.new("$N退了一步。", ME)], cast)[0].cue.is_empty(), "other words carry none")


## 总音量: version 10 of the settings; an older file reads as the default; the Master bus follows.
func _volume_setting() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	var v9: String = "[application]\nschema_version=9\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"normal\"\nhit_flash=true\nui_scale=100\nafter_knockout=\"ask\"\nobjective_hints=true\nday_night=\"follow\"\nautosave_notice=true\nresolution=\"\"\nscreen=-1\n"
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = v9.to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	check(old.succeeded() and old.snapshot().master_volume() == ApplicationSettingsSnapshot.DEFAULT_MASTER_VOLUME, "a version 9 file reads at the default volume")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = v9.replace("schema_version=9", "schema_version=10").to_utf8_buffer()
	check(not repository.load().succeeded(), "a version 10 file without it rejects")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = (v9.replace("schema_version=9", "schema_version=10") + "master_volume=150\n").to_utf8_buffer()
	check(not repository.load().succeeded(), "over 100 rejects")
	check(not ApplicationSettingsSnapshot.defaults().with_master_volume(-1).is_valid() and ApplicationSettingsSnapshot.defaults().with_master_volume(0).is_valid(), "0–100 is the range")
	var written: ApplicationSettingsResult = repository.write(ApplicationSettingsSnapshot.defaults().with_master_volume(35).with_ui_scale(125))
	var back: ApplicationSettingsResult = repository.load()
	check(written.succeeded() and back.succeeded() and back.snapshot().master_volume() == 35 and back.snapshot().ui_scale() == 125, "35 % round-trips beside the other settings")
	var bus: int = AudioServer.get_bus_index(&"Master")
	var before_db: float = AudioServer.get_bus_volume_db(bus)
	var before_mute: bool = AudioServer.is_bus_mute(bus)
	ApplicationSettingsService.apply_master_volume(50)
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)) and not AudioServer.is_bus_mute(bus), "50 %: the Master bus at half, not muted")
	ApplicationSettingsService.apply_master_volume(0)
	check(AudioServer.is_bus_mute(bus), "0: muted")
	ApplicationSettingsService.apply_master_volume(100)
	check(is_zero_approx(AudioServer.get_bus_volume_db(bus)) and not AudioServer.is_bus_mute(bus), "100: full")
	AudioServer.set_bus_volume_db(bus, before_db)
	AudioServer.set_bus_mute(bus, before_mute)


## The feel off (the suites' default): a line played moves no figure, leaves nothing behind.
func _feel_off_moves_nothing(tree: SceneTree) -> void:
	_setup(tree)
	_show.begin(_view)
	var me: Node3D = _model(ME)
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.HEAVY, 1), true)
	await tree.process_frame
	check(me.position == Vector3.ZERO and me.scale == Vector3.ONE and _model(YOU).position == Vector3.ZERO, "nothing moved")
	check(_show.effect_count() == 0 and _show.zoom_moves == 0 and _view.zoom() == 1.0, "no ghost, no dust, the camera still")
	check(_show.played.size() == 1 and _show.played[0][1] == BattleSceneShow.TEMPLATE_HEAVY, "the template was still picked (for the suites): %s" % [_show.played])
	_show.end()


## The templates by tag, the feel on and slowed four times so the frames can be read.
func _templates(tree: SceneTree) -> void:
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	var me: Node3D = _model(ME)
	var you: Node3D = _model(YOU)
	# 快: a short dash with a ghost left behind.
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0))
	check(_show.effect_count() == 1 and _ghost() != null and _ghost().position == Vector3.ZERO, "快: a ghost where it stood")
	await tree.create_timer(0.3).timeout
	check(me.position.z > 0.15 and me.position.z <= BattleSceneShow.STEP_QUICK + 0.01 and is_zero_approx(me.position.x), "快: a short step toward the target (%.2f)" % me.position.z)
	await tree.create_timer(1.6).timeout
	check(me.position.is_equal_approx(Vector3.ZERO) and _show.effect_count() == 0, "then home, the ghost gone (%s)" % me.position)
	# 重: the crouch first, held, then the long lunge and the freeze with the shake.
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.HEAVY, 0))
	check(_show.played.back()[1] == BattleSceneShow.TEMPLATE_HEAVY and _show.played.back()[3] == true, "重 landing: the hit-stop")
	await tree.create_timer(0.7).timeout
	check(me.scale.y < 0.95 and me.scale.y >= BattleSceneShow.CROUCH - 0.001 and me.position.z < 0.05, "重: crouched (%.3f), not yet moving" % me.scale.y)
	check(_effect_named("Charge") != null, "重: the 气 gathering round the figure")
	await tree.create_timer(1.1).timeout
	check(me.position.z > BattleSceneShow.STEP_HEAVY - 0.1, "重: the long lunge (%.2f)" % me.position.z)
	await tree.create_timer(2.6).timeout
	check(me.position.is_equal_approx(Vector3.ZERO) and is_equal_approx(me.scale.y, 1.0), "home and upright again")
	# 虚: half a dash stopped short, the ghost where it started, the body aside.
	_show.play_line(_blow(Outcome.DODGE, CombatMoveTags.FEINT, 0))
	check(_show.played.back()[1] == BattleSceneShow.TEMPLATE_FEINT and _ghost() != null and _ghost().position == Vector3.ZERO, "虚: the ghost left where it started")
	await tree.create_timer(0.55).timeout
	check(absf(me.position.x) > 0.05 and me.position.z <= BattleSceneShow.STEP_FEINT * 0.5 + 0.01, "虚: stopped half way and slid aside (%s)" % me.position)
	await tree.create_timer(2.0).timeout
	# 守: the sink; on a parry the arc before the chest.
	_show.play_line(_blow(Outcome.PARRY, CombatMoveTags.GUARD, 0))
	await tree.create_timer(0.5).timeout
	check(me.scale.y <= BattleSceneShow.SINK + 0.01 and me.position.z < 0.05, "守: sunk, not stepping (%.3f)" % me.scale.y)
	check(_show.effect_count() >= 1 and _effect_named("ParryArc") != null, "the parry's arc before the one who parried")
	await tree.create_timer(2.0).timeout
	# A windup asked before the line (the strip's half beat): the lunge follows from the crouch.
	_show.windup(ME)
	await tree.create_timer(0.7).timeout
	check(me.scale.y < 0.95, "the windup crouches before the line is told")
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.HEAVY, 0))
	await tree.create_timer(0.3).timeout
	check(me.position.z > 0.1, "told: the lunge goes at once, no second crouch (%.2f)" % me.position.z)
	await tree.create_timer(2.2).timeout
	check(you.position.length() < BattleSceneShow.KNOCKBACK_CAP + 0.01, "the one hit never farther than the cap (%.2f)" % you.position.length())
	_show.round_over()
	await tree.create_timer(1.6).timeout
	check(you.position.is_equal_approx(Vector3.ZERO), "the round over: the one hit home again (%s)" % you.position)
	# The round ends on the blow itself (the strip's last line): home once its show is done.
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0))
	_show.round_over()
	check(_show._running(YOU) and not _show._knock.has(YOU), "knocked and the round over in one frame: the show goes on")
	await tree.create_timer(0.6).timeout
	check(you.position.z > 0.1, "knocked back first (%.2f)" % you.position.z)
	await tree.create_timer(2.5).timeout
	check(you.position.is_equal_approx(Vector3.ZERO), "then home on its own (%s)" % you.position)
	_show.end()
	_show.pace = 1.0
	TestFeel.restore()


## The three signatures of a hit: 克 flashes gold and knocks farthest, 相持 white and a half
## step, 被克 dim red and barely; a dodge steps aside without a flash.
func _signatures(tree: SceneTree) -> void:
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	var you: Node3D = _model(YOU)
	var knocks: Array[float] = []
	var flashes: Array[Color] = []
	for ring: int in [1, 0, -1]:
		_show.round_over()
		_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, ring))
		knocks.append(_show._knock[YOU].length())
		# The flash lands at the impact (0.084 s × 4) and stays 0.24 s.
		await tree.create_timer(0.45).timeout
		flashes.append(_flash_colour(you))
		await tree.create_timer(2.0).timeout
	check(is_equal_approx(knocks[0], BattleSceneShow.KNOCKBACK[1]) and is_equal_approx(knocks[1], BattleSceneShow.KNOCKBACK[0]) and is_equal_approx(knocks[2], BattleSceneShow.KNOCKBACK[-1]) and knocks[0] > knocks[1] and knocks[1] > knocks[2], "克 farthest, 相持 half a step, 被克 barely: %s" % [knocks])
	check(flashes == [BattleSceneShow.FLASH_COUNTER, BattleSceneShow.FLASH_HIT, BattleSceneShow.FLASH_COUNTERED], "gold, white, dim red: %s" % [flashes])
	check(not you.has_meta("battle_flash") and _parts_overlaid(you) == 0, "the flash is one moment: gone after")
	_show.round_over()
	_show.play_line(_blow(Outcome.DODGE, CombatMoveTags.QUICK, 0))
	await tree.create_timer(0.55).timeout
	check(absf(you.position.x) > 0.05 and not you.has_meta("battle_flash"), "a dodge: aside, no flash (%s)" % you.position)
	await tree.create_timer(1.6).timeout
	_show.end()
	_show.pace = 1.0
	TestFeel.restore()


## The camera moves twice a fight (the opening, the last blow); a beat won flashes gold with
## a hop the first time only; close is standing nearer the target; the feel's zoom off keeps
## the camera still; end() brings everything back.
func _camera_and_stance(tree: SceneTree) -> void:
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	check(_show.zoom_moves == 1 and is_equal_approx(_view.zoom(), BattleSceneShow.ZOOM_OPEN), "the opening: the camera a little nearer")
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0), false)
	check(_show.zoom_moves == 1, "an ordinary blow: the camera still")
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0), true)
	check(_show.zoom_moves == 2 and is_equal_approx(_view.zoom(), BattleSceneShow.ZOOM_FINAL) and _show.played.back()[3] == true, "the felling blow: nearer again, with the hit-stop")
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0), true)
	check(_show.zoom_moves == 2, "and never a third time")
	await tree.create_timer(2.5).timeout
	# A beat won.
	var earned := BattleNarrationLine.new("你抢得一手（隙）！").with_cue(BattleNarrationLine.CUE_EARNED).with_beat(1, ME)
	_show.play_line(earned)
	var me: Node3D = _model(ME)
	check(_show.earned_shown() and _show._running(ME) and me.has_meta("battle_flash"), "the first beat won: the gold flash and the hop")
	await tree.create_timer(1.5).timeout
	_show.play_line(earned)
	check(not _show._running(ME) and me.has_meta("battle_flash"), "the next: the flash alone")
	await tree.create_timer(1.0).timeout
	# Close: standing nearer the target (the round over first: the blows above knocked it back).
	_show.round_over()
	await tree.create_timer(1.6).timeout
	_show.settle([[ME, YOU, true], [YOU, ME, false]])
	await tree.create_timer(1.6).timeout
	check(is_equal_approx(me.position.z, BattleSceneShow.CLOSE_STANCE) and _model(YOU).position.is_equal_approx(Vector3.ZERO), "close: a third of a unit nearer (%s)" % me.position)
	_show.settle([[ME, YOU, false], [YOU, ME, false]])
	await tree.create_timer(1.6).timeout
	check(me.position.is_equal_approx(Vector3.ZERO), "apart again")
	_show.end()
	check(is_equal_approx(_view.zoom(), 1.0) and _show.effect_count() == 0, "the end: the camera back, nothing left in the scene")
	# The zoom's feel off: the camera never moves.
	GameContent.catalog().pacing().feel = TestFeel.production.but({"battle_zoom_ms": 0})
	_show.begin(_view)
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0), true)
	check(_show.zoom_moves == 0 and _view.zoom() == 1.0, "battle_zoom_ms 0: the camera still")
	_show.end()
	_show.pace = 1.0
	TestFeel.restore()


## 战斗拍数 E: the scheduler's notes of 失衡 and 露空 carry their cues; the one thrown off balance
## reels, the one left open lurches, and both are back upright after.
func _heavy_aftermath(tree: SceneTree) -> void:
	var cast := BattlePresentationProjection.new(&"e", 0, ME, YOU, [], [], null, 0, -1, -1)
	var noted: Array[BattleNarrationLine] = BattleNarrator.seen([VisionLine.new("$N被震得失衡，丢了一手！", YOU, &"", ColoredLine.HIR), VisionLine.new("$N一招落空，露出了破绽！", ME, &"", ColoredLine.HIC)], cast)
	check(noted.size() == 2 and noted[0].cue == BattleNarrationLine.CUE_STAGGER and noted[1].cue == BattleNarrationLine.CUE_EXPOSED, "the notes of 失衡 and 露空 carry their cues")
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	var you: Node3D = _model(YOU)
	_show.play_line(BattleNarrationLine.new("x").with_cue(BattleNarrationLine.CUE_STAGGER).with_beat(1, YOU))
	check(_show.side_running(YOU), "失衡: the one thrown off balance reels")
	await tree.create_timer(1.6).timeout
	check(absf(you.rotation.z) > 0.01, "reeling side to side (%.3f)" % you.rotation.z)
	await tree.create_timer(2.0).timeout
	check(not _show.side_running(YOU) and is_zero_approx(you.rotation.z), "then upright again")
	_show.play_line(BattleNarrationLine.new("x").with_cue(BattleNarrationLine.CUE_EXPOSED).with_beat(1, ME))
	check(_show.side_running(ME), "露空: the striker lurches")
	_show.end()
	check(is_zero_approx(_model(ME).rotation.z) and not _show.side_running(ME), "end(): upright at once")
	_show.pace = 1.0
	TestFeel.restore()


## 战斗肢体 (DECISIONS「战斗肢体」): real figures. Everyone listed stands on guard with the weapon
## of its skill in its hand; a blow swings the arm by the weapon's motion (a 重 with a sword: the
## two-handed blow), wound up, through and back; the one struck at is thrown open, leans away or
## parries; one no longer listed and the fight's end put the weapon away; a beast leaps.
func _limbs(tree: SceneTree) -> void:
	check(BattleSceneShow.motion_of(&"sword", BattleSceneShow.TEMPLATE_QUICK) == "slam" and BattleSceneShow.motion_of(&"blade", BattleSceneShow.TEMPLATE_PLAIN) == "slash" and BattleSceneShow.motion_of(&"", BattleSceneShow.TEMPLATE_PLAIN) == "fist", "the motion is the weapon's (battle_stage.json)")
	check(BattleSceneShow.motion_of(&"sword", BattleSceneShow.TEMPLATE_HEAVY) == "heavy" and BattleSceneShow.motion_of(&"", BattleSceneShow.TEMPLATE_HEAVY) == "fist" and BattleSceneShow.motion_of(&"whip", BattleSceneShow.TEMPLATE_HEAVY) == "whip", "a 重 with a sword is the two-handed blow; a fist and a whip keep theirs")
	for skill: String in BattleArena.data()["moves"]["weapons"]:
		check(Person.STRIKES.has(String(BattleArena.data()["moves"]["weapons"][skill]["motion"])), "the motion of %s has its strike" % skill)
		check(skill.is_empty() or Person.ARMS.has(skill), "%s can be held in a hand" % skill)
	for motion: String in Person.STRIKES:
		check(Person.STRIKES[motion].size() == 2 and Person.STRIKES[motion][0].size() == Person.GUARD.size() and Person.STRIKES[motion][1].size() == Person.GUARD.size(), "%s: a windup and a blow of the guard's angles" % motion)
	for answer: String in Person.REACTIONS:
		check(Person.REACTIONS[answer].size() == Person.GUARD.size() + 2, "%s: the guard's angles and two more" % answer)
	_teardown(tree)
	_setup(tree, true)
	var me: Person = _model(ME) as Person
	var you: Person = _model(YOU) as Person
	await tree.process_frame
	await tree.process_frame
	# The feel off: on guard at once, the weapon drawn; a blow swings nothing.
	_show.begin(_view)
	_show.settle([[ME, YOU, false, "sword"], [YOU, ME, false, ""]])
	await tree.process_frame
	await tree.process_frame
	check(me.fighting and me.armed == "sword" and me.get_node_or_null("Frame") != null and me.arms[0].get_node_or_null("Weapon") != null and (me.arms[0].get_node("Weapon") as Node3D).visible, "on guard: the sword in the right hand")
	check(you.fighting and you.armed.is_empty() and you.arms[0].get_node_or_null("Weapon") == null, "bare-handed: on guard with nothing")
	check(is_equal_approx(me.arms[0].rotation.x, Person.GUARD[0]) and is_equal_approx(me.legs[1].rotation.x, Person.GUARD[7]) and me.torso.position.y < 0.0, "the guard: the arm up, a foot forward, the body a little lower (%.2f)" % me.arms[0].rotation.x)
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.HEAVY, 0).with_arms(&"sword", "刺伤"), true)
	await tree.process_frame
	check(is_zero_approx(me.swing) and is_zero_approx(you.react_amount) and not _show.limbs_running(ME), "the feel off: no swing, no answer")
	check(_view.fall_holds.is_empty(), "and nobody's fall waits")
	_show.end()
	await tree.process_frame
	await tree.process_frame
	check(not me.fighting and not (me.arms[0].get_node("Weapon") as Node3D).visible and is_zero_approx(me.arms[0].rotation.z), "the end: at ease, the sword put away")
	# The feel on, slowed four times.
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	_show.settle([[ME, YOU, false, "sword"], [YOU, ME, false, ""]])
	check(_view.fall_holds.has(ME) and _view.fall_holds.has(YOU), "the fight on: both figures' falls wait on their blows")
	await tree.create_timer(1.6).timeout
	check((me.arms[0].get_node("Weapon") as Node3D).visible and is_equal_approx(me.arms[0].rotation.x, Person.GUARD[0]), "on guard within the return's time")
	# A 快 with the sword: wound up at once, through as the step lands, then back.
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0).with_arms(&"sword", "刺伤"))
	check(me.motion == "slam" and is_equal_approx(me.swing, -1.0) and _show.limbs_running(ME), "快: the sword's own motion, wound up as the line is told")
	await tree.create_timer(0.3).timeout
	check(me.swing > 0.9 and me.arms[0].rotation.x > -1.2 and you.react == "hit" and you.react_amount > 0.5, "through, the one hit thrown open (swing %.2f, answer %.2f)" % [me.swing, you.react_amount])
	check(you.arms[0].rotation.z < -0.1 and you.arms[1].rotation.z > 0.1, "its arms flung outward")
	await tree.create_timer(2.6).timeout
	check(is_zero_approx(me.swing) and is_zero_approx(you.react_amount) and not _show.limbs_running(ME) and not _show.limbs_running(YOU), "then both back on guard")
	# A 重 with the sword: the two-handed blow, raised with the crouch.
	_show.windup(ME)
	await tree.create_timer(0.8).timeout
	check(me.motion == "heavy" and me.swing < -0.9 and me.arms[1].rotation.x < -2.0, "重: both arms up over the head as it gathers (%.2f)" % me.arms[1].rotation.x)
	_show.play_line(_blow(Outcome.DODGE, CombatMoveTags.HEAVY, 0).with_arms(&"sword", "刺伤"))
	await tree.create_timer(0.75).timeout
	check(me.swing > 0.9 and you.react == "dodge" and you.react_amount > 0.2 and not is_zero_approx(you.torso.rotation.z), "it comes down; the other leans out of its way")
	await tree.create_timer(3.0).timeout
	# Bare hands strike in turn; a parry brings the sword across.
	_show.play_line(_strike(YOU, ME, Outcome.PARRY, &""))
	var first: int = you._striker
	check(you.motion == "fist", "the bare hand: a fist")
	await tree.create_timer(0.5).timeout
	check(me.react == "parry" and me.react_amount > 0.9 and absf((me.arms[0].get_node("Weapon") as Node3D).rotation.y) > 0.9, "a parry: the sword turned across the body")
	await tree.create_timer(2.6).timeout
	_show.play_line(_strike(YOU, ME, Outcome.DODGE, &""))
	check(you._striker != first, "the next blow: the other hand")
	await tree.create_timer(2.6).timeout
	# A bare-handed 重: the hand raised in its half beat is the hand that strikes.
	_show.windup(YOU)
	await tree.create_timer(0.8).timeout
	var raised: int = you._striker
	_show.play_line(_strike(YOU, ME, Outcome.DODGE, &"").with_ring(CombatMoveTags.HEAVY, 0))
	check(you._striker == raised and you.swing < 0.0, "a bare-handed 重: the hand that was raised strikes")
	await tree.create_timer(3.4).timeout
	# A felling blow: the one felled is let go as it lands.
	_show.play_line(_blow(Outcome.HIT, CombatMoveTags.QUICK, 0).with_arms(&"sword", "刺伤"), true)
	check(_view.fall_holds.has(YOU), "the felling blow told: the one felled still stands")
	await tree.create_timer(1.2).timeout
	check(not _view.fall_holds.has(YOU) and _view.fall_holds.has(ME), "it lands: that one's fall waits no more, the striker's still does")
	# All told while a felling blow is still on its way: the one it fells waits for it.
	_show.play_line(_strike(YOU, ME, Outcome.HIT, &""), true)
	_show.lines_told(true)
	check(_view.fall_holds.has(ME), "the lines all told, the felling blow not landed: its victim still stands")
	await tree.create_timer(1.2).timeout
	check(not _view.fall_holds.has(ME), "landed: let go")
	_show.settle([[ME, YOU, false, "sword"], [YOU, ME, false, ""]])
	check(not _view.fall_holds.has(YOU), "and it is not held again this fight")
	# One no longer listed stands down; the fight's end lets everyone go.
	_show.settle([[ME, &"", false, "sword"]])
	check(not you.fighting and me.fighting, "one who left the fight stands down")
	_show.end()
	check(not me.fighting and _view.fall_holds.is_empty(), "the end: at ease, nobody held")
	# A beast (the view marks its model) leaps at its target.
	var beast := Node3D.new()
	beast.set_meta("pounce", 0.24)
	var actor := Node3D.new()
	_root.add_child(actor)
	actor.add_child(beast)
	_view.actors[&"dog"] = actor
	_show.begin(_view)
	_show.play_line(_strike(&"dog", YOU, Outcome.HIT, &""))
	await tree.create_timer(0.25).timeout
	check(beast.position.y > 0.05 and beast.position.z > 0.05, "a beast: off the ground on its way (%s)" % beast.position)
	await tree.create_timer(3.0).timeout
	check(beast.position.is_equal_approx(Vector3.ZERO) and is_zero_approx(beast.rotation.x), "and home again, level")
	_show.end()
	_show.pace = 1.0
	TestFeel.restore()
	# A figure's fall: slack limbs, the body turned onto its back and raised to lie on the ground.
	me.limp = 1.0
	await tree.process_frame
	await tree.process_frame
	check(is_equal_approx(me.frame.rotation.x, -PI / 2.0) and is_equal_approx(me.frame.position.y, Person.LIE_LIFT) and is_equal_approx(me.arms[0].rotation.z, -Person.LIMP[1]), "fallen: on its back, the arms slack")
	me.limp = 0.0
	await tree.process_frame
	await tree.process_frame
	check(is_zero_approx(me.frame.rotation.x) and is_zero_approx(me.arms[0].rotation.z), "up again: as it stood")


## 战斗特效 (DECISIONS「战斗特效」): what a blow leaves in the scene. The light of a swung weapon
## (its edge, its colour, its fade), what is thrown, the chips off the one hit and the dark ones
## among them, a beast's leap all the way; nothing of it with the feel off.
func _blow_effects(tree: SceneTree) -> void:
	# The data: colours by the wound, dark chips by the fight's look, a beast's reach.
	var stab: BattleNarrationLine = _strike(ME, YOU, Outcome.HIT, &"sword")
	var stab_colour: Color = BattleSceneShow.trail_colour(stab.with_arms(&"sword", "刺伤"))
	var whip_colour: Color = BattleSceneShow.trail_colour(_strike(ME, YOU, Outcome.HIT, &"whip").with_arms(&"whip", "鞭伤"))
	var special_colour: Color = BattleSceneShow.trail_colour(_strike(ME, YOU, Outcome.HIT, &"sword").with_special_blow())
	check(stab_colour.is_equal_approx(Color(Color("efc77b"), 0.6)) and not whip_colour.is_equal_approx(stab_colour) and special_colour.is_equal_approx(Color(Color("ffd98a"), 0.6)), "the light's colour: by the wound, a special's its own (%s %s %s)" % [stab_colour, whip_colour, special_colour])
	check(BattleSceneShow.blood_for(CombatEncounterMode.Value.LETHAL) == 3 and BattleSceneShow.blood_for(CombatEncounterMode.Value.SPAR) == 0 and BattleSceneShow.blood_for(CombatEncounterMode.Value.LESSON) == 0, "dark chips: three in a 死斗, none in a 切磋 or a 拆招")
	check(is_equal_approx(BattleSceneShow._beast_reach(0.42, 2.4), 1.55) and is_equal_approx(BattleSceneShow._beast_reach(0.42, 0.9), 0.42) and is_equal_approx(BattleSceneShow._beast_reach(0.42, 9.0), 2.4), "a beast's leap: to within the gap, never short of the step nor past its reach")
	# The edge a blow's light follows.
	_teardown(tree)
	_setup(tree, true)
	var me: Person = _model(ME) as Person
	var you: Person = _model(YOU) as Person
	await tree.process_frame
	await tree.process_frame
	check(me.strike_edge().is_empty(), "at ease: no edge")
	me.take_guard("sword")
	var edge: Array = me.strike_edge()
	check(edge.size() == 3 and edge[0] == me.arms[0].get_node("Weapon") and (edge[2] as Vector3).z > (edge[1] as Vector3).z, "a sword in the hand: its edge along the blade")
	me.take_guard("throwing")
	check(me.strike_edge().is_empty(), "something thrown: no edge (it flies)")
	you.take_guard("")
	check(you.strike_edge().is_empty(), "a bare hand: none")
	me.stand_down()
	you.stand_down()
	# The trail itself: facets while the edge moves, gone once it has faded.
	var arm := Node3D.new()
	_root.add_child(arm)
	var trail := BattleSwingTrail.new()
	trail.source = arm
	trail.from = Vector3(0, 0, 0.5)
	trail.to = Vector3(0, 0, 1.0)
	trail.sampling = 0.1
	trail.fade = 0.2
	var done: Array[bool] = [false]
	trail.finished.connect(func() -> void: done[0] = true)
	_root.add_child(trail)
	trail.set_process(false)
	for step: int in 5:
		arm.rotation.x += 0.3
		trail.advance(0.02)
	check(trail.facet_count() == 4 and trail.mesh.get_surface_count() == 1, "the edge swept: a facet between one step and the next (%d)" % trail.facet_count())
	arm.rotation.x += 0.3
	trail.advance(0.05)
	check(trail.facet_count() == 4, "past the blow's travel: no more facets (%d)" % trail.facet_count())
	trail.advance(0.1)
	check(trail.facet_count() < 4 and not done[0], "the oldest fade first (%d)" % trail.facet_count())
	trail.advance(0.3)
	check(done[0] and trail.mesh.get_surface_count() == 0, "all faded: finished, nothing drawn")
	trail.queue_free()
	arm.queue_free()
	# The feel off: a blow leaves nothing.
	_show.begin(_view)
	_show.blood_chips = 3
	_show.settle([[ME, YOU, false, "sword"], [YOU, ME, false, ""]])
	_show.play_line(_strike(ME, YOU, Outcome.HIT, &"sword"))
	await tree.process_frame
	check(_show.effect_count() == 0, "the feel off: no light, no chips")
	_show.end()
	# The feel on, slowed four times.
	TestFeel.use()
	_show.pace = 4.0
	_show.begin(_view)
	_show.blood_chips = 3
	_show.settle([[ME, YOU, false, "sword"], [YOU, ME, false, ""]])
	await tree.create_timer(1.6).timeout
	_show.play_line(_strike(ME, YOU, Outcome.HIT, &"sword"))
	await tree.process_frame
	await tree.process_frame
	var light: BattleSwingTrail = _effect_named("SwingTrail") as BattleSwingTrail
	check(light != null and light.source == me.arms[0].get_node("Weapon"), "a sword's blow: its light follows the blade")
	check(light != null and light.colour.is_equal_approx(BattleSceneShow.trail_colour(_strike(ME, YOU, Outcome.HIT, &"sword"))) and light.from.z > 0.14 and light.to.z > light.from.z, "in the blow's colour, along the outer part of the edge")
	await tree.create_timer(0.6).timeout
	check(light != null and is_instance_valid(light) and light.facet_count() >= 2, "swept as the arm comes down (%d facets)" % (light.facet_count() if is_instance_valid(light) else -1))
	var chips: Node3D = _effect_named("Chips")
	var counts: Dictionary = BattleArena.data()["impact"]["chips"]
	check(chips != null and chips.get_child_count() == int(counts["count"]) + 3, "landed: chips off the one hit, three dark ones among them (%d)" % (chips.get_child_count() if chips != null else -1))
	await tree.create_timer(3.0).timeout
	check(_effect_named("SwingTrail") == null and _effect_named("Chips") == null, "the light faded, the chips fallen")
	# The bare hand: chips, no light. No dark chips where the fight has none.
	_show.blood_chips = 0
	_show.play_line(_strike(YOU, ME, Outcome.HIT, &""))
	await tree.create_timer(0.7).timeout
	chips = _effect_named("Chips")
	check(_effect_named("SwingTrail") == null and chips != null and chips.get_child_count() == int(counts["count"]), "a fist: no light; chips, none dark")
	await tree.create_timer(3.0).timeout
	# A 重 throws more.
	_show.windup(ME)
	await tree.create_timer(0.8).timeout
	_show.play_line(_strike(ME, YOU, Outcome.HIT, &"sword").with_ring(CombatMoveTags.HEAVY, 0))
	await tree.create_timer(0.9).timeout
	chips = _effect_named("Chips")
	check(chips != null and chips.get_child_count() == int(counts["heavy_count"]), "a 重: more chips (%d)" % (chips.get_child_count() if chips != null else -1))
	await tree.create_timer(4.0).timeout
	# Something thrown flies to the one struck at; on past one who dodged.
	_show.play_line(_strike(ME, YOU, Outcome.DODGE, &"throwing"))
	await tree.process_frame
	await tree.process_frame
	var dart: Node3D = _effect_named("Thrown")
	check(me.motion == "thrown" and dart != null and _effect_named("SwingTrail") == null, "thrown: it leaves the hand, and no light")
	var start: float = dart.global_position.z if dart != null else 0.0
	await tree.create_timer(0.3).timeout
	check(dart != null and is_instance_valid(dart) and dart.global_position.z > start + 0.2, "on its way to the one struck at (%.2f from %.2f)" % [dart.global_position.z if is_instance_valid(dart) else -1.0, start])
	await tree.create_timer(0.4).timeout
	check(dart != null and is_instance_valid(dart) and dart.global_position.z > 1.5, "dodged: it flies on past (%.2f)" % (dart.global_position.z if is_instance_valid(dart) else -1.0))
	await tree.create_timer(3.0).timeout
	check(_effect_named("Thrown") == null, "and is gone")
	# Parried: it spins up and away.
	_show.play_line(_strike(ME, YOU, Outcome.PARRY, &"throwing"))
	await tree.create_timer(0.75).timeout
	dart = _effect_named("Thrown")
	check(dart != null and dart.global_position.y > 1.3, "parried: it flies up off the guard (%.2f)" % (dart.global_position.y if dart != null else -1.0))
	await tree.create_timer(3.0).timeout
	# The base answers through the show: a 重 that lands makes its bricks hop under the one hit, a
	# special's opening and a felling blow make it flare.
	var arena := BattleArena.new()
	_root.add_child(arena)
	var spots: Array[Vector2] = [Vector2(0, 0), Vector2(0, 48)]
	arena.lay(spots, spots[0], CombatEncounterMode.Value.LETHAL)
	arena.skip()
	arena._process(0.0)
	_show.stage = arena
	_show.windup(ME)
	await tree.create_timer(0.8).timeout
	_show.play_line(_strike(ME, YOU, Outcome.HIT, &"sword").with_ring(CombatMoveTags.HEAVY, 0), true)
	await tree.create_timer(1.0).timeout
	check(arena.jolting() and arena.lifted_bricks() > 0 and arena.lifted_bricks() < arena.brick_count() and arena.lift_at(Vector3(0, 0, 1.5)) > 0.0, "a 重 that lands: the bricks under the one hit are in the air, the far ones lie still (%d of %d)" % [arena.lifted_bricks(), arena.brick_count()])
	check(arena.flaring(), "a felling blow: the braziers flare")
	await tree.create_timer(4.0).timeout
	check(not arena.jolting() and not arena.flaring(), "and the base is at rest again")
	_show.play_line(BattleNarrationLine.new("x").with_special(ME, "「封」"))
	check(arena.flaring(), "a special's opening: they flare")
	# One who joins while it flares: the base built again starts at rest.
	arena.jolt(Vector3.ZERO, 1.5, 0.1, 0.2)
	var wide: Array[Vector2] = [Vector2(0, 0), Vector2(0, 48), Vector2(0, 400)]
	arena.grow_to(wide, wide[0])
	arena._process(0.016)
	var flames_wild: bool = false
	for flame: MeshInstance3D in arena._flames:
		flames_wild = flames_wild or flame.scale.y > 3.0
	check(not arena.flaring() and not arena.jolting() and not flames_wild, "built again mid-flare: at rest, no flame out of size")
	await tree.create_timer(3.0).timeout
	_show.stage = null
	arena.queue_free()
	# A beast leaps all the way to the one it strikes at.
	var beast := Node3D.new()
	beast.set_meta("pounce", 0.24)
	var actor := Node3D.new()
	actor.position = Vector3(0, 0, -1.0)
	_root.add_child(actor)
	actor.add_child(beast)
	_view.actors[&"wolf"] = actor
	_show.play_line(_strike(&"wolf", YOU, Outcome.DODGE, &""))
	await tree.create_timer(0.52).timeout
	check(beast.position.z > 1.3, "a beast: its leap comes down beside the one it strikes at (%.2f of 2.5)" % beast.position.z)
	# Its next blow, told while it is still out there: from its place all the same, not backward.
	_show.play_line(_strike(&"wolf", YOU, Outcome.DODGE, &""))
	await tree.create_timer(0.52).timeout
	check(beast.position.z > 1.3, "and again straight after: the same leap, not a hop backward (%.2f)" % beast.position.z)
	await tree.create_timer(3.0).timeout
	check(beast.position.is_equal_approx(Vector3.ZERO), "and home again")
	_show.end()
	check(_show.effect_count() == 0, "the end: nothing left in the scene")
	_show.pace = 1.0
	TestFeel.restore()


## 战斗特效: the base answers — its bricks hop under a blow with weight, its braziers and flags
## flare; not while it is being laid or taken down.
func _stage_answers(tree: SceneTree) -> void:
	TestFeel.use()
	for mode: int in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]:
		var arena := BattleArena.new()
		_root.add_child(arena)
		var spots: Array[Vector2] = [Vector2(-24, 0), Vector2(24, 0)]
		arena.lay(spots, spots[0], mode)
		arena.jolt(Vector3.ZERO, 1.5, 0.1, 0.2)
		check(arena.laying() and not arena.jolting(), "while it is laid: no hop")
		arena.skip()
		arena._process(0.0)
		await tree.process_frame
		check(not arena.laying() and not arena.jolting() and not arena.flaring(), "mode %d: laid, at rest" % mode)
		arena.jolt(Vector3.ZERO, 1.5, 0.1, 0.2)
		arena._process(0.1)
		check(arena.jolting() and arena.lift_at(Vector3.ZERO) > 0.09 and arena.lift_at(Vector3(1.0, 0, 0)) < arena.lift_at(Vector3.ZERO) and is_zero_approx(arena.lift_at(Vector3(3.0, 0, 0))), "a hop: highest at its middle, none past its reach (%.3f, %.3f)" % [arena.lift_at(Vector3.ZERO), arena.lift_at(Vector3(1.0, 0, 0))])
		arena._process(0.4)
		check(not arena.jolting() and is_zero_approx(arena.lift_at(Vector3.ZERO)), "then every brick lies where it lay")
		arena.flare(1.3, 0.4)
		check(arena.flaring(), "a flare: the braziers or the flags answer")
		arena._process(0.2)
		var flags: Array = arena.find_children("Flag", "Node3D", false, false)
		var braziers: Array = arena.find_children("Brazier", "Node3D", false, false)
		check(not flags.is_empty() or not braziers.is_empty(), "the base has corners to answer with (%d flags, %d braziers)" % [flags.size(), braziers.size()])
		if not flags.is_empty():
			check(flags.any(func(flag: Node3D) -> bool: return not is_zero_approx(flag.rotation.z)), "a flag snaps")
		arena._process(0.3)
		check(not arena.flaring() and (flags.is_empty() or flags.all(func(flag: Node3D) -> bool: return is_zero_approx(flag.rotation.z))), "and is over: the flags hang still")
		arena.take_down(0.3)
		arena.jolt(Vector3.ZERO, 1.5, 0.1, 0.2)
		check(not arena.jolting(), "coming down: no hop")
		arena.queue_free()
		await tree.process_frame
	TestFeel.restore()


## 战斗肢体: the fall's curve — nothing at first, flat at the end, a bounce on landing; rising eased.
func _fall_curve() -> void:
	check(is_zero_approx(WorldVoxelView.fall_turn(0.0, true)) and is_equal_approx(WorldVoxelView.fall_turn(1.0, true), 1.0) and is_equal_approx(WorldVoxelView.fall_turn(0.8, true), 1.0), "falling: from upright to flat, flat already as it lands")
	check(WorldVoxelView.fall_turn(0.9, true) < 0.95 and WorldVoxelView.fall_turn(0.4, true) < 0.3, "slow at first, a bounce on landing")
	check(is_zero_approx(WorldVoxelView.fall_turn(0.0, false)) and is_equal_approx(WorldVoxelView.fall_turn(1.0, false), 1.0) and is_equal_approx(WorldVoxelView.fall_turn(0.5, false), 0.5), "rising: eased both ways")


## The mode's word in blocks (owner 2026-11-09): each pixel of the pixel face one block, from
## the font's outlines (no rendering); a word the face cannot draw builds nothing.
func _mode_title(tree: SceneTree) -> void:
	var lethal: Array = BattleModeTitle.mask_of("死斗")
	var ink: int = 0
	for row: PackedByteArray in lethal:
		ink += row.count(1)
	check(lethal.size() >= 9 and lethal.size() <= 12 and (lethal[0] as PackedByteArray).size() == 24 and ink > 60, "死斗: two 12-pixel glyphs, %d rows, %d pixels of ink" % [lethal.size(), ink])
	check(BattleModeTitle.mask_of("").is_empty() and BattleModeTitle.mask_of("͸").is_empty(), "nothing, or a glyph the face lacks: no mask")
	var title := BattleModeTitle.new()
	tree.root.add_child(title)
	check(title.present("切磋", CombatEncounterMode.Value.SPAR) and title.built() and title.block_count() > 40, "切磋 builds (%d blocks)" % title.block_count())
	check(not title.present("", -1) and not title.built(), "an empty word: nothing built (the Label shows)")
	title.queue_free()


# --- fixtures -------------------------------------------------------------------------------


## Two figures a unit and a half apart along z, each a box under an actor node (`people`: a
## real person), in a view that is only their holder (no map).
func _setup(tree: SceneTree, people: bool = false) -> void:
	_root = Node3D.new()
	_root.name = "SceneShowTest"
	tree.root.add_child(_root)
	_view = WorldVoxelView.new()
	for pair: Array in [[ME, Vector3(0, 0, 0)], [YOU, Vector3(0, 0, 1.5)]]:
		var actor := Node3D.new()
		actor.name = String(pair[0])
		actor.position = pair[1]
		_root.add_child(actor)
		_view.actors[pair[0]] = actor
		if people:
			var person := Person.new()
			person.name = "Model"
			person.configure({"coat": "397c87", "prop": "sword_waist"})
			actor.add_child(person)
			continue
		var model := Node3D.new()
		model.name = "Model"
		actor.add_child(model)
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		body.position = Vector3(0, 0.9, 0)
		model.add_child(body)
	_show = BattleSceneShow.new()
	_root.add_child(_show)


func _teardown(tree: SceneTree) -> void:
	if _root != null:
		_root.queue_free()
		_root = null
	if _view != null:
		_view.free()
		_view = null


func _model(id: StringName) -> Node3D:
	return _view.actors[id].get_child(0) as Node3D


func _ghost() -> Node3D:
	return _effect_named("Afterimage")


func _effect_named(name: String) -> Node3D:
	for effect: Node3D in _show._effects:
		if is_instance_valid(effect) and effect.name == name:
			return effect
	return null


static func _flash_colour(model: Node3D) -> Color:
	if not model.has_meta("battle_flash"):
		return Color.BLACK
	var overlay := model.get_meta("battle_flash") as StandardMaterial3D
	return overlay.albedo_color if overlay != null else Color.BLACK


static func _parts_overlaid(model: Node3D) -> int:
	var count: int = 0
	for part: GeometryInstance3D in BattleSceneShow._parts(model):
		if part.material_overlay != null:
			count += 1
	return count


static func _blow(outcome: int, tag: StringName, ring: int) -> BattleNarrationLine:
	return BattleNarrationLine.new("x", 10 if outcome == Outcome.HIT else -1).with_blow(ME, YOU, "招", outcome, BattleVitalityBar.Band.LIGHT).with_ring(tag, ring).with_beat(1, ME)


## A plain blow of `actor` at `target`, struck with the weapon of `skill`.
static func _strike(actor: StringName, target: StringName, outcome: int, skill: StringName) -> BattleNarrationLine:
	return BattleNarrationLine.new("x", 10 if outcome == Outcome.HIT else -1).with_blow(actor, target, "招", outcome, BattleVitalityBar.Band.LIGHT).with_ring(&"", 0).with_arms(skill, "瘀伤").with_beat(1, actor)


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append("battle scene show: " + message)
