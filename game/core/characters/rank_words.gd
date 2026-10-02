class_name RankWords
extends RefCounted

## adm/daemons/rankd.c: how a character calls itself (query_self) and how others
## address it politely (query_respect), with the rude forms ask.c uses, from gender,
## age and class. The rank_info/* overrides are not modelled yet.


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


static func query_respect(gender: StringName, age: int, class_id: StringName) -> String:
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
