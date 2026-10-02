class_name ChineseNumber
extends RefCounted

## adm/daemons/chinesed.c chinese_number(): 十, 一百零五, 三千零二十.
const DIGITS: Array[String] = ["零", "十", "百", "千", "万", "亿", "兆"]
const NUMBERS: Array[String] = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]


@warning_ignore("integer_division")
static func of(i: int) -> String:
	if i < 0:
		return "负" + of(-i)
	if i < 11:
		return NUMBERS[i]
	if i < 20:
		return NUMBERS[10] + NUMBERS[i - 10]
	if i < 100:
		return NUMBERS[i / 10] + DIGITS[1] + (NUMBERS[i % 10] if i % 10 != 0 else "")
	if i < 1000:
		if i % 100 == 0:
			return NUMBERS[i / 100] + DIGITS[2]
		if i % 100 < 10:
			return NUMBERS[i / 100] + DIGITS[2] + NUMBERS[0] + of(i % 100)
		if i % 100 < 20:
			return NUMBERS[i / 100] + DIGITS[2] + NUMBERS[1] + of(i % 100)
		return NUMBERS[i / 100] + DIGITS[2] + of(i % 100)
	if i < 10000:
		if i % 1000 == 0:
			return NUMBERS[i / 1000] + DIGITS[3]
		if i % 1000 < 100:
			return NUMBERS[i / 1000] + DIGITS[3] + DIGITS[0] + of(i % 1000)
		return NUMBERS[i / 1000] + DIGITS[3] + of(i % 1000)
	return _large(i, 10000, 4) if i < 100000000 else (_large(i, 100000000, 5) if i < 1000000000000 else _large(i, 1000000000000, 6))


@warning_ignore("integer_division")
static func _large(i: int, unit: int, digit: int) -> String:
	if i % unit == 0:
		return of(i / unit) + DIGITS[digit]
	if i % unit < unit / 10:
		return of(i / unit) + DIGITS[digit] + DIGITS[0] + of(i % unit)
	return of(i / unit) + DIGITS[digit] + of(i % unit)
