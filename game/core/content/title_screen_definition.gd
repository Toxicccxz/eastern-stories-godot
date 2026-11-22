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


## The silk ribbon through the lettering (TitleRibbon), in percent of the lettering's ink box (x
## parts of its width, y parts of its height): the points its middle runs through, three numbers
## each — x, y, and 1 in front of the lettering or 0 behind it (the band changes sides halfway
## between two points that differ); which two points it is held between (before and after them its
## loose ends stream in the wind); its width (parts of the ink's height); the points the words sit
## on (one, or one a word); the point its seal is stamped on; where it flies in from and drifts off
## toward.
class Ribbon:
	var path: Array[int] = [-14, 92, 1, -3, 74, 1, 11, 62, 1, 33, 70, 0, 56, 62, 1, 82, 56, 0, 104, 66, 1, 118, 86, 1, 136, 94, 1]
	var held: Array[int] = [1, 6]
	var band: int = 16
	var text: Array[int] = [2, 4]
	var seal: int = 6
	var from: Array[int] = [-60, 160]
	var to: Array[int] = [240, -70]

	func points() -> int:
		return path.size() / 3


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
			for key: String in ["path", "held", "text", "from", "to"]:
				if entry.has(key):
					ribbon.set(key, entry.integer_list(key))
			ribbon.band = entry.integer("band", ribbon.band)
			ribbon.seal = entry.integer("seal", ribbon.seal)
			var count: int = ribbon.points()
			if ribbon.path.size() % 3 != 0 or count < 4:
				entry.fail("path", "expected at least four [x, y, in front] points")
			if ribbon.held.size() != 2 or ribbon.held[0] < 1 or ribbon.held[1] > count - 2 or ribbon.held[0] >= ribbon.held[1]:
				entry.fail("held", "expected two points with a loose end beyond each")
			for point: int in ribbon.text + [ribbon.seal]:
				if point < 0 or point >= count:
					entry.fail("text", "expected points of the path")
			for key: String in ["from", "to"]:
				if (ribbon.get(key) as Array).size() != 2:
					entry.fail(key, "expected [x, y]")
			if ribbon.band < 5 or ribbon.band > 60:
				entry.fail("band", "expected 5..60")
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
