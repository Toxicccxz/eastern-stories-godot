class_name ApplicationSlotText
extends RefCounted

## What the slot list and the 回到上次自动存档 question say of a slot (GameSaveSlotSummary).


## The slot's own name.
static func slot_name(slot_id: StringName) -> String:
	if slot_id == GameSaveSnapshot.AUTO_SLOT_ID:
		return TranslationServer.translate("自动存档")
	# TRANSLATORS: a manual save slot's name; %d its number, 1 to 3.
	return TranslationServer.translate("手动存档 %d") % (GameSaveSnapshot.MANUAL_SLOT_IDS.find(slot_id) + 1)


## "老松岭 · 南坡林道" for the zone the save stands in, in the shown language.
static func place(zone_id: StringName) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone(zone_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	if region == null:
		return ""
	return "%s · %s" % [TranslationServer.translate(region.display_name), TranslationServer.translate(zone.display_name)]


## A row: the slot's name, then who, where, how long, when and what next. `heading` replaces the
## slot's name (上一份自动存档).
static func row(summary: GameSaveSlotSummary, heading: String = "") -> String:
	var title: String = slot_name(summary.slot_id) if heading.is_empty() else heading
	match summary.state:
		GameSaveSlotSummary.State.EMPTY:
			if summary.recoverable:
				# TRANSLATORS: a slot row: {slot} the slot's name; the save is lost but a backup lies beside it.
				return TranslationServer.translate("{slot}（主存档丢失，可以恢复）").format({"slot": title})
			# TRANSLATORS: a slot row: {slot} the slot's name, nothing saved in it.
			return TranslationServer.translate("{slot}（空）").format({"slot": title})
		GameSaveSlotSummary.State.UNREADABLE:
			# TRANSLATORS: a slot row: {slot} the slot's name, its file cannot be read.
			return TranslationServer.translate("{slot}（无法读取）").format({"slot": title})
		GameSaveSlotSummary.State.UNSUPPORTED:
			# TRANSLATORS: a slot row: {slot} the slot's name, its save is from another version.
			return TranslationServer.translate("{slot}（来自不兼容的版本）").format({"slot": title})
	var who: String = summary.display_name
	if summary.ghost:
		# TRANSLATORS: a slot row: {name} the character, saved as a ghost.
		who = TranslationServer.translate("{name}（鬼魂）").format({"name": who})
	var lines: Array[String] = [
		"%s    %s" % [title, who],
		# TRANSLATORS: a slot row: {place} where, {played} the time played, {saved} when it was saved.
		TranslationServer.translate("{place}    时长 {played}    {saved}").format({"place": place(summary.zone_id), "played": played(summary.played_seconds), "saved": saved_at(summary.saved_at_utc)}),
	]
	if not summary.objective.is_empty():
		# TRANSLATORS: a slot row: {next} the objective at the save.
		lines.append(TranslationServer.translate("目标：{next}").format({"next": TranslationServer.translate(summary.objective)}))
	return "\n".join(lines)


## "1:05" (hours:minutes played).
@warning_ignore("integer_division")
static func played(seconds: int) -> String:
	return "%d:%02d" % [seconds / 3600, seconds / 60 % 60]


## The save's time on this machine's clock: "2026-10-31 15:30".
static func saved_at(saved_at_utc: String) -> String:
	if saved_at_utc.is_empty():
		return ""
	var unix: int = Time.get_unix_time_from_datetime_string(saved_at_utc)
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%04d-%02d-%02d %02d:%02d" % [local["year"], local["month"], local["day"], local["hour"], local["minute"]]


## How long ago the save was made: "3 分钟前".
@warning_ignore("integer_division")
static func ago(saved_at_utc: String, now_unix: int = int(Time.get_unix_time_from_system())) -> String:
	var seconds: int = maxi(now_unix - Time.get_unix_time_from_datetime_string(saved_at_utc), 0)
	if seconds < 60:
		return TranslationServer.translate("不到一分钟前")
	if seconds < 3600:
		# TRANSLATORS: how long ago a save was made; %d minutes.
		return TranslationServer.translate("%d 分钟前") % (seconds / 60)
	# TRANSLATORS: how long ago a save was made; %d hours.
	return TranslationServer.translate("%d 小时前") % (seconds / 3600)
