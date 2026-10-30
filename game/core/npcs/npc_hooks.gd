class_name NpcHooks
extends RefCounted

## An NPC's own functions that the game runs as data (d/choyin/npc/oldman.c's 采药老者,
## daemon/class/scholar/sword_soul.c's 风泉剑灵). Each is null when the NPC has none.
## - `receive_damage` (oldman.c): after a blow took kee from it, one above max_kee / `hurt_divisor`
##   says `hurt_say` and, when random(kee) is below the blow, walks out of the fight
##   (random_move()); then, while it has pills and its gin, kee or sen is below `pill_below`,
##   it says `pill_line` (in `pill_color`; say() lines, the NPC's name written in them), its gin, kee and sen come back to their eff_ and one
##   of its `pills` is gone. The pills are counted anew at its room's reset and when it wakes.
## - `kill_ob` (oldman.c): one who attacks it (kill.c's obj->kill_ob(me)) reads `lines`
##   ($N themselves) instead of a fight, and the NPC is gone (destruct()) until its room
##   makes a new one.
## - `revive` (oldman.c): when it wakes, combat_exp grows by a third (`exp_divisor`) and
##   `exp_plus`, and its reset() runs: the pills again, and the potential it gained since
##   the last time, a third each to apply/attack, apply/dodge and apply/damage.
## - `defeated_enemy` (oldman.c, combatd.c winner_reward() from damage.c unconcious()): what
##   it says when the player falls with it the last to hurt them.
## - `chant` (sword_soul.c chant()): from the moment it is made, `stages` follow one another,
##   each `after` seconds of world time: its say (and a line, $N itself) and combat_exp it
##   gains; after the last the first comes again `repeat_after` seconds later.
## - `ghost` (d/choyin/npc/ghost.c, shadow.c is_ghost()): char.c visible() hides it from one
##   who is no ghost: it is not drawn nor picked, and who fights it may miss their turn
##   (combatd.c fight(): random(100 + perception) < 100); chard.c make_corpse() leaves no
##   corpse, what it carried falls where it died.
## - `die_carries` (d/choyin/npc/lion.c die()): the `item` new()'d into it as it dies, so its
##   corpse holds it; with `master` it records its killer (set("master_id")): the item's
##   master form when the player struck last (ItemContentDefinition.MASTER_SUFFIX).
## - `die_marks_killer` (d/chuenyu/xiaojuan2.c die()): its killer, the player, gets that mark
##   (query_temp("last_damage_from")->set("marks/<mark>", 1)).
## - `calls` (xiaojuan2.c, chuenyu.c init()): the call_outs its init() starts when the player
##   comes into its room, each `after` seconds (0: at once, as a plain init()) and started anew
##   by every arrival (remove_call_out()); when due it acts (a ScriptedAct, its conditions and
##   steps) if the player is still there and it is for them. `calls_hold` (owner, 鬼门关 plan
##   Q2): while they are pending it does not wander (npc.c random_move()), so the white
##   gargoyle's five lines are not cut short by his own walk. A call with `reaction` true
##   answers the player's arrival and comes within pacing.json's reaction beat (小娟's cry);
##   one with `hurry` true is a line of a told sequence the player may hurry (继续: the
##   gargoyles' lines), DECISIONS「响应性」.
## - `moods` (d/village/npc/oldliu.c killhim()): {name: NpcMood}, put on by an act's `npc_mood`.
## - `attack_ask` with `attack_choice` (owner, 黑松山 plan F3): 攻击 asks this first (小娟, a
##   breath from death, whose death her father avenges).
## - `follows_every_way` (owner, F2): following the player (team.c set_leader()) it goes along
##   every way they lead, climbs, falls and other maps too; go.c follow_me() only took exits.
var hurt_divisor: int = 0
var hurt_say: String = ""
var hurt_color: StringName = ColoredLine.PLAIN
var pills: int = 0
var pill_below: int = 0
var pill_line: String = ""
var pill_color: StringName = ColoredLine.PLAIN
var kill_ob_lines: Array[NpcLine] = []
var revive_exp_divisor: int = 0
var revive_exp_plus: int = 0
var revive_apply_divisor: int = 0
var defeated_say: String = ""
var defeated_color: StringName = ColoredLine.PLAIN
var chant_stages: Array[Stage] = []
var chant_repeat_after: int = 0
var ghost: bool = false
var die_item_id: StringName = &""
var die_item_master: bool = false
var die_marks_killer: String = ""
var calls: Array[Call] = []
var calls_hold: bool = false
## Native (主线 A; DECISIONS「剧情演出」): `spared` {mood?, mark?}: 放过 as it lay puts it in
## that mood of its own (lasting or not, as the mood says) and marks the player (刘安禄
## spared: he talks; the 黑衣道士 spared: gone).
var spared_mood: String = ""
var spared_mark: String = ""
## `spared.leave`: once the fight is over it is gone for good (fled), with `spared.line` told.
var spared_leave: bool = false
var spared_line: String = ""
## Native (逆灵宫 C; DECISIONS「逆灵宫 C」): `spared.drop`: an item (by definition) let fall where it
## lies as it is spared (玄冥子's 残卷, the jailer's key) — the spared keep nothing from the player.
var spared_drop: StringName = &""
## Native (逆灵宫 C): `vanishes` {line?}: it leaves no corpse when it dies (chard.c make_corpse()
## of a ghost: what it carried falls where it fell), the line told (鬼卒 散成黑烟). It is no ghost:
## it is seen and fought as anyone.
var vanishes: bool = false
var vanish_line: String = ""
## Native (主线 C; DECISIONS「刘安禄放过后开口」): `spared.only_in_mood`: 放过 changes it only
## while it is in that mood of its own (刘安禄 revealed as 血手刘三; the 门房 beaten for
## nothing and spared stays the 门房).
var spared_only_in_mood: String = ""
## Native (主线 A; DECISIONS「剧情演出」): the mark set on the player the moment its scene
## begins (its scene calls' `not_mark`): a scene cut short is not played again.
var scene_mark: String = ""
var moods: Dictionary[String, NpcMood] = {}
var attack_ask: String = ""
var attack_choice: String = ""
var follows_every_way: bool = false


## One of init()'s call_outs (`calls`): when, and what it does.
class Call:
	extends RefCounted
	var after: float = 0.0
	var act: ScriptedAct
	## It answers the player's arrival: pacing.json's reaction beat at most.
	var reaction: bool = false
	## A line of a told sequence: 继续 brings it now.
	var hurry: bool = false
	## Native (主线 A; DECISIONS「剧情演出」): one of the NPC's scene. Its conditions are
	## judged once, when the player comes in and the scene begins; while any scene call is
	## still to come the player stands and watches (WorldMapNpcLife: the camera on whoever
	## speaks, E as 继续), and it comes whatever changed. A scene call is a told line (hurry).
	var scene: bool = false


class Stage:
	extends RefCounted
	var after: int = 0
	var say: String = ""
	var line: String = ""
	var combat_exp: int = 0


func has_receive_damage() -> bool:
	return hurt_divisor > 0 or pills > 0


func has_kill_ob() -> bool:
	return not kill_ob_lines.is_empty()


func has_revive() -> bool:
	return revive_exp_divisor > 0


func has_chant() -> bool:
	return not chant_stages.is_empty()


## receive_damage: a blow of `damage` kee says the hurt line.
func hurts(damage: int, max_kee: int) -> bool:
	@warning_ignore("integer_division")
	return hurt_divisor > 0 and damage > max_kee / hurt_divisor


## receive_damage: with `left` pills and gin, kee or sen below `pill_below`, it swallows one:
## all three come back to their eff_. True when it did (the caller counts the pill).
func takes_pill(state: CharacterState, left: int) -> bool:
	if left <= 0 or not (state.vitality.current < pill_below or state.essence.current < pill_below or state.spirit.current < pill_below):
		return false
	state.essence.current = state.essence.effective
	state.vitality.current = state.vitality.effective
	state.spirit.current = state.spirit.effective
	return true


## revive: combat_exp grows by a third and `exp_plus`; reset() gives the potential gained
## since the last time, a third each to apply/attack, apply/dodge and apply/damage.
func revive_growth(state: CharacterState) -> void:
	var progression: CharacterProgressionState = state.progression
	@warning_ignore("integer_division")
	progression.combat_experience += progression.combat_experience / revive_exp_divisor + revive_exp_plus
	var learn: int = progression.potential - progression.potential_spent
	if learn <= 0:
		return
	@warning_ignore("integer_division")
	var share: int = learn / revive_apply_divisor
	for key: String in ["attack", "dodge", "damage"]:
		state.applies[key] = int(state.applies.get(key, 0)) + share
	progression.potential_spent += share * revive_apply_divisor


static func _color(reader: ContentRecordReader, key: String) -> StringName:
	var color := StringName(reader.text(key))
	if color != ColoredLine.PLAIN and not ColoredLine.COLORS.has(color):
		reader.fail(key, "expected one of %s" % ", ".join(ColoredLine.COLORS))
	return color


## The NPC record's `receive_damage` {hurt?: {divisor, line, color?}, pills?: {count, below,
## line, color?}}, `kill_ob` {lines}, `revive` {exp_divisor, exp_plus, apply_divisor},
## `defeated_enemy` {line, color?} (each line as say() prints it, the NPC's name in it), `chant` {stages: [{after, say, line?, combat_exp?}],
## repeat_after}, `ghost` true, `die_carries` {item, master?}, `die_marks_killer` a mark, `calls`
## [{after, ...ScriptedAct}], `calls_hold` true, `moods` {name: NpcMood}, `attack_ask` with `attack_choice` and
## `follows_every_way` true; null when it has none of them.
static func from_record(reader: ContentRecordReader) -> NpcHooks:
	var hooks := NpcHooks.new()
	var found: bool = false
	var damage: ContentRecordReader = reader.child("receive_damage")
	if damage != null:
		found = true
		var hurt: ContentRecordReader = damage.child("hurt")
		if hurt != null:
			hooks.hurt_divisor = hurt.required_integer("divisor")
			hooks.hurt_say = hurt.required_text("line")
			hooks.hurt_color = _color(hurt, "color")
			hurt.finish()
			if hooks.hurt_divisor <= 0:
				damage.fail("hurt", "divisor must be positive")
		var pills: ContentRecordReader = damage.child("pills")
		if pills != null:
			hooks.pills = pills.required_integer("count")
			hooks.pill_below = pills.required_integer("below")
			hooks.pill_line = pills.required_text("line")
			hooks.pill_color = _color(pills, "color")
			pills.finish()
			if hooks.pills <= 0 or hooks.pill_below <= 0:
				damage.fail("pills", "count and below must be positive")
		damage.finish()
		if not hooks.has_receive_damage():
			reader.fail("receive_damage", "needs hurt or pills")
	var killed: ContentRecordReader = reader.child("kill_ob")
	if killed != null:
		found = true
		for line: ContentRecordReader in killed.children("lines"):
			var parsed: NpcLine = NpcLine.from_record(line, true)
			line.finish()
			if parsed != null:
				hooks.kill_ob_lines.append(parsed)
		killed.finish()
		if hooks.kill_ob_lines.is_empty():
			reader.fail("kill_ob", "says what happens")
	var revive: ContentRecordReader = reader.child("revive")
	if revive != null:
		found = true
		hooks.revive_exp_divisor = revive.required_integer("exp_divisor")
		hooks.revive_exp_plus = revive.required_integer("exp_plus")
		hooks.revive_apply_divisor = revive.required_integer("apply_divisor")
		revive.finish()
		if hooks.revive_exp_divisor <= 0 or hooks.revive_apply_divisor <= 0:
			reader.fail("revive", "divisors must be positive")
	var defeated: ContentRecordReader = reader.child("defeated_enemy")
	if defeated != null:
		found = true
		hooks.defeated_say = defeated.required_text("line")
		hooks.defeated_color = _color(defeated, "color")
		defeated.finish()
	var chant: ContentRecordReader = reader.child("chant")
	if chant != null:
		found = true
		for record: ContentRecordReader in chant.children("stages"):
			var stage := Stage.new()
			stage.after = record.required_integer("after")
			stage.say = record.required_text("say")
			stage.line = record.text("line")
			stage.combat_exp = record.integer("combat_exp", 0)
			record.finish()
			if stage.after <= 0 or stage.combat_exp < 0:
				chant.fail("stages", "after is positive, combat_exp not negative")
			hooks.chant_stages.append(stage)
		hooks.chant_repeat_after = chant.required_integer("repeat_after")
		chant.finish()
		if hooks.chant_stages.is_empty() or hooks.chant_repeat_after <= 0:
			reader.fail("chant", "needs stages and a positive repeat_after")
	if reader.has("ghost"):
		found = true
		hooks.ghost = reader.boolean("ghost", false)
		if not hooks.ghost:
			reader.fail("ghost", "only a ghost says so")
	var dies: ContentRecordReader = reader.child("die_carries")
	if dies != null:
		found = true
		hooks.die_item_id = StringName(dies.required_text("item"))
		hooks.die_item_master = dies.boolean("master", false)
		dies.finish()
	if reader.has("die_marks_killer"):
		found = true
		hooks.die_marks_killer = reader.required_text("die_marks_killer")
	for record: ContentRecordReader in reader.children("calls"):
		found = true
		var call := Call.new()
		call.after = float(record.integer("after", 0))
		if call.after < 0.0:
			record.fail("after", "must not be negative")
		call.reaction = record.boolean("reaction", false)
		call.hurry = record.boolean("hurry", false)
		call.scene = record.boolean("scene", false)
		if call.scene:
			call.hurry = true
		if call.reaction and call.hurry:
			record.fail("hurry", "a reaction is no told line")
		call.act = ScriptedAct.from_record(record)
		hooks.calls.append(call)
	if reader.has("calls_hold"):
		hooks.calls_hold = reader.boolean("calls_hold", false)
		if not hooks.calls_hold or hooks.calls.is_empty():
			reader.fail("calls_hold", "only an NPC with calls holds still for them")
	var moods: ContentRecordReader = reader.child("moods")
	if moods != null:
		found = true
		for mood_name: String in moods.keys():
			hooks.moods[mood_name] = NpcMood.from_record(mood_name, moods.child(mood_name))
		moods.finish()
	if reader.has("attack_ask") or reader.has("attack_choice"):
		found = true
		hooks.attack_ask = reader.required_text("attack_ask")
		hooks.attack_choice = reader.required_text("attack_choice")
	if reader.has("follows_every_way"):
		found = true
		hooks.follows_every_way = reader.boolean("follows_every_way", false)
		if not hooks.follows_every_way:
			reader.fail("follows_every_way", "only one that does says so")
	var spared: ContentRecordReader = reader.child("spared")
	if spared != null:
		found = true
		hooks.spared_mood = spared.text("mood")
		hooks.spared_mark = spared.text("mark")
		hooks.spared_leave = spared.boolean("leave", false)
		hooks.spared_line = spared.text("line")
		hooks.spared_only_in_mood = spared.text("only_in_mood")
		hooks.spared_drop = StringName(spared.text("drop"))
		spared.finish()
		if hooks.spared_mood.is_empty() and hooks.spared_mark.is_empty() and not hooks.spared_leave and hooks.spared_drop.is_empty():
			reader.fail("spared", "names a mood of the NPC's, a mark for the player, leave or drop, or several")
		if not hooks.spared_line.is_empty() and not hooks.spared_leave:
			reader.fail("spared", "line goes with leave")
		if not hooks.spared_mood.is_empty() and not hooks.moods.has(hooks.spared_mood):
			reader.fail("spared", "mood '%s' is none of its moods" % hooks.spared_mood)
		if not hooks.spared_only_in_mood.is_empty() and not hooks.moods.has(hooks.spared_only_in_mood):
			reader.fail("spared", "only_in_mood '%s' is none of its moods" % hooks.spared_only_in_mood)
	var vanishes: ContentRecordReader = reader.child("vanishes")
	if vanishes != null:
		found = true
		hooks.vanishes = true
		hooks.vanish_line = vanishes.text("line")
		vanishes.finish()
	if reader.has("scene_mark"):
		found = true
		hooks.scene_mark = reader.required_text("scene_mark")
		if not hooks.calls.any(func(call: Call) -> bool: return call.scene):
			reader.fail("scene_mark", "only an NPC with a scene marks its beginning")
	return hooks if found else null


## Whether 放过 changes anything of it (`spared`).
func has_spared() -> bool:
	return not spared_mood.is_empty() or not spared_mark.is_empty() or spared_leave or not spared_drop.is_empty()
