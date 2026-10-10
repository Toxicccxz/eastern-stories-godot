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
## repeat_after}, `ghost` true and `die_carries` {item, master?}; null when it has none of them.
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
	return hooks if found else null
