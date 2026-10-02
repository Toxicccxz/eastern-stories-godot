extends RefCounted

## std/char/npc.c accept_fight(), per-NPC accept_fight() rules and rankd.c words.
var assertions: int = 0
var failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_rank_words()
	_default_attitudes()
	_health_gate()
	_fighting_npc()
	_own_rules()
	_rule_loading()
	return {"assertions": assertions, "failures": failures}


func _rank_words() -> void:
	var male: StringName = CharacterState.GENDER_MALE
	var female: StringName = CharacterState.GENDER_FEMALE
	check(RankWords.query_self(male, 14, &"") == "在下" and RankWords.query_self(male, 60, &"") == "老头子", "query_self: 在下 under 50, else 老头子")
	check(RankWords.query_self(female, 20, &"") == "小女子" and RankWords.query_self(female, 30, &"") == "妾身", "query_self: 小女子 under 30, else 妾身")
	check(RankWords.query_self(male, 30, &"bonze") == "贫僧" and RankWords.query_self(male, 30, &"taoist") == "贫道", "query_self by class")
	check(RankWords.query_respect(male, 14, &"") == "小兄弟" and RankWords.query_respect(male, 20, &"") == "壮士" and RankWords.query_respect(male, 50, &"") == "老爷子", "query_respect default: 20 and 50 are the steps")
	check(RankWords.query_respect(male, 17, &"swordsman") == "小老弟" and RankWords.query_respect(male, 18, &"swordsman") == "壮士", "query_respect for swordsmen steps at 18")
	check(RankWords.query_respect(female, 17, &"") == "小姑娘" and RankWords.query_respect(female, 50, &"") == "婆婆", "query_respect for women")


func _default_attitudes() -> void:
	var asker := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 14, &"", &"")
	var friendly: NpcSparConsent = NpcSparConsent.decide(_npc(NpcDefinition.Attitude.FRIENDLY), asker)
	check(not friendly.accepted and _said(friendly) == ["旅客说道：在下怎麽可能是小兄弟的对手？"], "friendly refuses: npc.c's line with rankd.c words")
	var peaceful: NpcSparConsent = NpcSparConsent.decide(_npc(NpcDefinition.Attitude.PEACEFUL), asker)
	check(peaceful.accepted and _said(peaceful) == ["旅客说道：既然小兄弟赐教，在下只好奉陪。"], "no attitude (or peaceful) accepts")
	var heroism: NpcSparConsent = NpcSparConsent.decide(_npc(NpcDefinition.Attitude.HEROISM), asker)
	check(heroism.accepted and _said(heroism) == ["旅客说道：既然小兄弟赐教，在下只好奉陪。"], "heroism accepts like the default")
	var aggressive: NpcSparConsent = NpcSparConsent.decide(_npc(NpcDefinition.Attitude.AGGRESSIVE), asker)
	check(aggressive.accepted and _said(aggressive) == ["旅客说道：哼！出招吧！"], "aggressive: 哼！出招吧！")


func _health_gate() -> void:
	var asker := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 14, &"", &"")
	var hurt: NpcRuntimeState = _npc(NpcDefinition.Attitude.PEACEFUL)
	hurt.character_state.vitality.current = 179
	var refused: NpcSparConsent = NpcSparConsent.decide(hurt, asker)
	check(not refused.accepted and _said(refused).is_empty(), "kee 179/200 (89%) refuses without a word")
	hurt.character_state.vitality.current = 180
	check(NpcSparConsent.decide(hurt, asker).accepted, "kee 180/200 (90%) accepts")
	hurt.character_state.essence.current = 0
	check(not NpcSparConsent.decide(hurt, asker).accepted, "gin counts as well")


func _fighting_npc() -> void:
	var asker := NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 14, &"", &"")
	var busy: NpcRuntimeState = _npc(NpcDefinition.Attitude.PEACEFUL)
	busy.relationship.add_opponent(&"someone")
	var refused: NpcSparConsent = NpcSparConsent.decide(busy, asker)
	check(not refused.accepted and _said(refused) == ["旅客说道：想倚多为胜，这不是欺人太甚吗！"], "already fighting: only heroism goes on")
	var hero: NpcRuntimeState = _npc(NpcDefinition.Attitude.HEROISM)
	hero.relationship.add_opponent(&"someone")
	var accepted: NpcSparConsent = NpcSparConsent.decide(hero, asker)
	check(accepted.accepted and _said(accepted) == ["旅客说道：哼！出招吧！"], "a fighting heroism NPC: 哼！出招吧！ and no second line")


func _own_rules() -> void:
	var rules: Array[NpcFightRule] = [
		NpcFightRule.new(&"family.fonxan", &"", "点了点头。", "进招吧。", true),
		NpcFightRule.new(&"", &"", "", "$RESPECT，$SELF不和客人过招。", false),
	]
	var trainer: NpcRuntimeState = _npc(NpcDefinition.Attitude.HEROISM, rules)
	trainer.character_state.vitality.current = 1
	var member: NpcSparConsent = NpcSparConsent.decide(trainer, NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 14, &"", &"family.fonxan"))
	check(member.accepted and _said(member) == ["旅客点了点头。", "旅客说道：进招吧。"], "own rule: family members are accepted, even hurt")
	var guest: NpcSparConsent = NpcSparConsent.decide(trainer, NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 25, &"", &""))
	check(not guest.accepted and _said(guest) == ["旅客说道：壮士，在下不和客人过招。"], "own rule: $RESPECT and $SELF from rankd.c")
	var none: NpcRuntimeState = _npc(NpcDefinition.Attitude.PEACEFUL, [NpcFightRule.new(&"family.fonxan", &"", "", "进招吧。", true)])
	var fell_through: NpcSparConsent = NpcSparConsent.decide(none, NpcSparConsent.Challenger.new(CharacterState.GENDER_MALE, 14, &"", &""))
	check(not fell_through.accepted and _said(fell_through).is_empty(), "no rule matches: accept_fight() returns 0")


func _rule_loading() -> void:
	var trainer: NpcDefinition = GameContent.catalog().npc(&"snow.npc.fist_trainer")
	var scavenger: NpcDefinition = GameContent.catalog().npc(&"snow.npc.scavenger")
	var dog: NpcDefinition = GameContent.catalog().npc(&"snow.npc.dog")
	check(trainer.fight_rules().size() == 2 and trainer.fight_rules()[0].family_id == &"family.fonxan" and trainer.fight_rules()[0].accept, "李火狮 spars with 封山剑派 members")
	check(scavenger.fight_rules().size() == 1 and not scavenger.fight_rules()[0].accept and scavenger.fight_rules()[0].say.begins_with("$RESPECT"), "收破烂的 begs and refuses")
	check(GameContent.catalog().npc(&"snow.npc.trainee").fight_rules().is_empty(), "武馆弟子 uses npc.c")
	check(trainer.can_speak() and not dog.can_speak(), "humans speak (race/human.c can_speak); beasts do not")


## The sentences the runtime prints, as spar_selected() builds them (untranslated).
func _said(consent: NpcSparConsent) -> Array[String]:
	var result: Array[String] = []
	for line: NpcSparConsent.Line in consent.lines:
		var text: String = line.text.replace("$RESPECT", consent.respect).replace("$SELF", consent.npc_self)
		result.append("旅客" + text if line.emote else "旅客说道：" + text)
	return result


func _npc(attitude: int, rules: Array[NpcFightRule] = []) -> NpcRuntimeState:
	var definition := NpcDefinition.new(&"test.npc.traveller", "d/snow/npc/traveller.c", "旅客", [&"traveller"], NpcCharacterStateFactory.HUMAN_RACE_ID, true, CharacterState.GENDER_MALE, true, 25, null, null, 0, 0, attitude)
	definition.with_fight_rules(rules)
	var state := CharacterState.new()
	state.gender = CharacterState.GENDER_MALE
	state.essence = CharacterResourceState.new(100, 100, 100)
	state.vitality = CharacterResourceState.new(200, 200, 200)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	return NpcRuntimeState.new(&"test.traveller.character", definition, &"test.spawn", &"test.point", state, CombatRelationshipState.new(&"test.traveller.character"), ActionBusyState.new(), ArmorState.new(), WorldLocationState.new(&"r", &"m", &"z", &"c"), CharacterRuntimeLifeStatus.Value.ACTIVE, true, true, 25)


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("spar consent: " + label)
