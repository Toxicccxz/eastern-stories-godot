class_name InventorySections
extends RefCounted
## The 背包's sections along its top (owner, 2026-11-04): what a carried thing is listed
## under, read off its definition, so a new item needs nothing but its data. Coins are
## in none: they are the 钱袋 under the list.

enum Section { ALL, GEAR, SUPPLIES, BOOKS, QUEST, MISC }

const TITLES: Array[String] = ["全部", "装备", "补给", "书籍", "任务", "杂物"]
# TRANSLATORS: the 背包 when a section has nothing in it.
const EMPTY_LINES: Array[String] = [
	"身上空无一物。",
	"没有带着兵器或衣甲。",
	"没有带着吃的、喝的或伤药。",
	"没有带着书。",
	"没有带着要紧的东西。",
	"没有别的杂物。",
]


## Weapons and armour are 装备; food, drink and what heals (apply) 补给; a thing a story
## turns on (`quest`) 任务; anything one reads to learn (study) 书籍; the rest 杂物.
static func of(content: ItemContentDefinition) -> int:
	if content == null:
		return Section.MISC
	match content.category:
		ItemContentDefinition.CATEGORY_WEAPON, ItemContentDefinition.CATEGORY_ARMOR:
			return Section.GEAR
		ItemContentDefinition.CATEGORY_FOOD, ItemContentDefinition.CATEGORY_LIQUID:
			return Section.SUPPLIES
	if content.quest_item:
		return Section.QUEST
	if not content.apply.is_empty():
		return Section.SUPPLIES
	if content.study != null:
		return Section.BOOKS
	return Section.MISC


static func is_money(content: ItemContentDefinition) -> bool:
	return content != null and content.category == ItemContentDefinition.CATEGORY_CURRENCY


## Whether a thing of `content` shows under `section` (全部 shows all but the coins).
static func shows(section: int, content: ItemContentDefinition) -> bool:
	if is_money(content):
		return false
	return section == Section.ALL or of(content) == section
