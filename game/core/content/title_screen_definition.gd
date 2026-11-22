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


## The silk ribbon through the foot of the lettering (TitleRibbon), in percent of the lettering's
## ink box: the height its middle runs at (0 the top, 100 the foot), where it starts and where it
## folds (0 the left, 100 the right), how wide it is against the ink's height, and the spans of
## the ink's width where the lettering lies over it, as pairs (the band lies over the rest).
class Ribbon:
	var y: int = 98
	var from: int = -3
	var fold: int = 96
	var band: int = 19
	var under: Array[int] = []


## By the menu button's name (NewGameButton, ContinueButton, …).
var choices: Dictionary[StringName, Choice] = {}
## Lettering masks (white = ink) by language code; "default" for any other language.
var logos: Dictionary[String, String] = {}
var seals: Dictionary[String, String] = {}
## The line spaced out under the title by language code ("default" for any other): the title
## in the other language.
var lines: Dictionary[String, String] = {}
## The line as a lettering mask (red = ink) where it is not set in a shipped font, by the same
## language codes as `lines`.
var line_masks: Dictionary[String, String] = {}
## The ribbon by language code ("default" for any other).
var ribbons: Dictionary[String, Ribbon] = {}
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


func line_for(language: String) -> String:
	return lines.get(language, lines.get("default", ""))


## The line's mask goes with the line: a language with a line of its own takes only its own mask.
func line_mask_for(language: String) -> String:
	return line_masks.get(language if lines.has(language) else "default", "")


func ribbon_for(language: String) -> Ribbon:
	return ribbons.get(language, ribbons.get("default", Ribbon.new()))


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
	definition.lines = reader.text_map("lines")
	definition.line_masks = reader.text_map("line_masks")
	var ribbons: ContentRecordReader = reader.child("ribbons")
	if ribbons != null:
		for language: String in ribbons.keys():
			var entry: ContentRecordReader = ribbons.child(language)
			var ribbon := Ribbon.new()
			ribbon.y = entry.integer("y", ribbon.y)
			ribbon.from = entry.integer("from", ribbon.from)
			ribbon.fold = entry.integer("fold", ribbon.fold)
			ribbon.band = entry.integer("band", ribbon.band)
			if entry.has("under"):
				ribbon.under = entry.integer_list("under")
			if ribbon.under.size() % 2 != 0 or ribbon.under.size() > 4:
				entry.fail("under", "expected up to two [from, to] pairs")
			if ribbon.band < 5 or ribbon.band > 60:
				entry.fail("band", "expected 5..60")
			if ribbon.fold <= ribbon.from:
				entry.fail("fold", "expected right of from")
			entry.finish()
			definition.ribbons[language] = ribbon
		ribbons.finish()
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
