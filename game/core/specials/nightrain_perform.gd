class_name NightrainPerform
extends RainpressPerform

## 封山剑法's 「夜雨」 (perform nightrain; 师娘彩蛋 B, DECISIONS「师娘彩蛋 B」): 沈疏雨's 「雨」 as the one who
## stayed the night learned it — the same move as 「听雨」 (RainpressPerform), its numbers that one's
## (`perform_rules.rainpress.numbers`), its cost the same; only its name, its lines and its colour
## are its own. One player has one of the two: the night's choice gives one mark or the other.


func _init() -> void:
	id = &"nightrain"
	label = "「夜雨」"
	number_keys = []


func _not_fighting_line() -> String:
	return "「夜雨」只能对战斗中的对手使用。"


func _short_line() -> String:
	return "你的内力不够，使不出「夜雨」。"


func _strike_line() -> String:
	return "$N剑势一沉，使出「夜雨」，剑尖细细密密地压向$n，像檐下落了一夜的雨，逼得$p非接不可！"


func _open_line() -> String:
	return "$n接得一乱，身前空了一块。"


func _color() -> StringName:
	return ColoredLine.HIB
