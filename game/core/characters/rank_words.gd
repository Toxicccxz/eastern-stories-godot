class_name RankWords
extends RefCounted

## adm/daemons/rankd.c: how a character calls itself (query_self) and how others
## address it politely (query_respect), with the rude forms ask.c uses, from gender,
## age and class. Of the rank_info/* overrides only respect is authored so far
## (店小二 小二哥, 柳淳风 柳馆主).


static func query_self(gender: StringName, age: int, class_id: StringName) -> String:
	if gender == CharacterState.GENDER_FEMALE:
		if class_id == &"bonze":
			return "贫尼" if age < 50 else "老尼"
		return "小女子" if age < 30 else "妾身"
	match class_id:
		&"bonze":
			return "贫僧" if age < 50 else "老纳"
		&"taoist":
			return "贫道"
	return "在下" if age < 50 else "老头子"


## rankd.c query_rank() for a player (score.c's first line): by class and gender.
## Not here: the ghost's (a dead player reincarnates at once), 杀人魔 (other players
## killed: none in single player) and 惯窃 (the player does not steal yet).
static func query_rank(gender: StringName, class_id: StringName) -> String:
	var female: bool = gender == CharacterState.GENDER_FEMALE
	match class_id:
		&"bonze":
			return "【 尼  姑 】" if female else "【 僧  人 】"
		&"taoist":
			return "【 女  冠 】" if female else "【 道  士 】"
		&"bandit":
			return "【 女飞贼 】" if female else "【 盗  贼 】"
		&"dancer":
			return "【 舞  妓 】" if female else "【 平  民 】"
		&"scholar":
			return "【 才  女 】" if female else "【 书  生 】"
		&"officer":
			return "【 女  官 】" if female else "【 官  差 】"
		&"fighter":
			return "【 女武者 】" if female else "【 武  者 】"
		&"swordsman":
			return "【 女剑士 】" if female else "【 剑  士 】"
		&"alchemist":
			return "【 方  士 】"
		&"shaman":
			return "【 巫  医 】"
		&"beggar":
			return "【 叫化子 】"
	return "【 平  民 】"


## `rank_info` is the addressed character's rank_info/respect, which rankd.c returns first.
static func query_respect(gender: StringName, age: int, class_id: StringName, rank_info: String = "") -> String:
	if not rank_info.is_empty():
		return rank_info
	if gender == CharacterState.GENDER_FEMALE:
		match class_id:
			&"bonze":
				return "小师太" if age < 18 else "师太"
			&"taoist":
				return "小仙姑" if age < 18 else "仙姑"
		if age < 18:
			return "小姑娘"
		return "姑娘" if age < 50 else "婆婆"
	match class_id:
		&"bonze":
			return "小师父" if age < 18 else "大师"
		&"taoist":
			return "道兄" if age < 18 else "道长"
		&"fighter", &"swordsman":
			if age < 18:
				return "小老弟"
			return "壮士" if age < 50 else "老前辈"
	if age < 20:
		return "小兄弟"
	return "壮士" if age < 50 else "老爷子"


## How a character calls someone it means to insult (ask.c: an aggressive NPC asked its name).
static func query_rude(gender: StringName, age: int, class_id: StringName) -> String:
	if gender == CharacterState.GENDER_FEMALE:
		match class_id:
			&"bonze":
				return "贼尼"
			&"taoist":
				return "妖女"
		return "小贱人" if age < 30 else "死老太婆"
	match class_id:
		&"bonze":
			return "死秃驴" if age < 50 else "老秃驴"
		&"taoist":
			return "死牛鼻子"
	if age < 20:
		return "小王八蛋"
	return "臭贼" if age < 50 else "老匹夫"


## How a character calls itself when rude (ask.c: an aggressive or heroic NPC's name).
static func query_self_rude(gender: StringName, age: int, class_id: StringName) -> String:
	if gender == CharacterState.GENDER_FEMALE:
		if class_id == &"bonze":
			return "贫尼" if age < 50 else "老尼"
		return "本姑娘" if age < 30 else "老娘"
	match class_id:
		&"bonze":
			return "大和尚我" if age < 50 else "老和尚我"
		&"taoist":
			return "本山人"
	return "大爷我" if age < 50 else "老子"
