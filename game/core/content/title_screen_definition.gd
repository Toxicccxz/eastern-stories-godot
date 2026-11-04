class_name TitleScreenDefinition
extends RefCounted

## The title screen (data/common/title_screen.json; DECISIONS「标题画面」): which place of the
## 沙盘 each main-menu choice flies the camera to and whose weather drifts out of it, and the
## logo's baked ink masks per language. TitleScreen shows it.

const WEATHERS: Array[StringName] = [&"snow", &"petal", &"mote", &"needle", &"dust"]


class Choice:
	## The atlas place the camera settles on; "" = the place of the save 继续 would load.
	var place: StringName = &""
	var weather: StringName = &"snow"
	## The camera's zoom there, in percent of the 沙盘's own scale.
	var zoom_percent: int = 66


## By the menu button's name (NewGameButton, ContinueButton, …).
var choices: Dictionary[StringName, Choice] = {}
## Ink masks (white = ink) by language code; "default" for any other language.
var logos: Dictionary[String, String] = {}
var seals: Dictionary[String, String] = {}
## Where the sun stands and where the logo's middle stands, in percent of the screen.
var sun_percent: Array[int] = [28, 20]
var logo_percent: Array[int] = [28, 21]
## The logo's width in UI pixels.
var logo_width_px: int = 580
## Where a new journey begins: the camera dives there as the logo burns.
var new_game_place: StringName = &"snow.outdoor"


func choice(button_name: StringName) -> Choice:
	return choices.get(button_name)


## The mask for `language`, else the default one ("" when there is none).
func logo_for(language: String) -> String:
	return logos.get(language, logos.get("default", ""))


func seal_for(language: String) -> String:
	return seals.get(language, seals.get("default", ""))


static func from_record(reader: ContentRecordReader) -> TitleScreenDefinition:
	var definition := TitleScreenDefinition.new()
	for key: String in ["sun_percent", "logo_percent"]:
		if reader.has(key):
			var pair: Array[int] = reader.integer_list(key)
			if pair.size() != 2:
				reader.fail(key, "expected [x, y]")
			else:
				definition.set(key, pair)
	definition.logo_width_px = reader.integer("logo_width_px", definition.logo_width_px)
	definition.new_game_place = StringName(reader.text("new_game_place", definition.new_game_place))
	definition.logos = reader.text_map("logos")
	definition.seals = reader.text_map("seals")
	var choices: ContentRecordReader = reader.child("choices")
	if choices != null:
		for name: String in choices.keys():
			var entry: ContentRecordReader = choices.child(name)
			var choice := Choice.new()
			choice.place = StringName(entry.text("place"))
			choice.weather = StringName(entry.text("weather", "snow"))
			choice.zoom_percent = entry.integer("zoom_percent", choice.zoom_percent)
			if choice.weather not in WEATHERS:
				entry.fail("weather", "expected one of %s" % [WEATHERS])
			if choice.zoom_percent < 10 or choice.zoom_percent > 300:
				entry.fail("zoom_percent", "expected 10..300")
			entry.finish()
			definition.choices[StringName(name)] = choice
		choices.finish()
	if definition.logo_width_px < 64:
		reader.fail("logo_width_px", "must be at least 64")
	reader.finish()
	return definition
