extends SceneTree
## Bakes the title's lettering masks (DECISIONS「标题画面」): 东方故事 lettered in 云峰飞云体 (a
## rough, free brush hand) — every character its own size, set close and a little off the line,
## as a title is brushed and not typed — Eastern / Stories in two lines of the same hand's own
## Latin letters (owner 2026-11-22: the English title brushed like the others), and the seal's 侠
## in 霞鹜文楷.
## Each mask is rendered large and antialiased, padded for the shadow, with the ink in red and the
## same ink blurred wide in green (TitleLogo's shader soaks the ink in from the strokes' cores
## and casts the shadow with it). The game reads only these masks, so the brush font is not
## shipped.
## Windowed (it renders text):
##   <godot> --path game --script <abs>/tools/ui/bake_title_logo.gd -- <云峰飞云体.ttf>
## Writes game/assets/textures/title/logo_zh_CN.png, logo_en.png, seal_zh_CN.png.
## The Korean title, 동방이야기 in a Korean brush hand (추사 사랑체 Bold; the font is not shipped):
##   ... -- <font> ko [mask name]      writes logo_ko.png (or the name given)
## The Japanese title, 東方物語 in a Japanese brush hand (衡山毛筆フォント行書; 飞云体 has no 東
## or 語; the font is not shipped):
##   ... -- <font> ja [mask name]      writes logo_ja.png (or the name given)

const OUT: String = "res://assets/textures/title/"
const PLAIN: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
## 东方故事, character by character: [character, size in pixels, how far its left edge stands from
## the last one's (parts of the last one's size), how far its middle stands below the line's
## middle (pixels), its turn (degrees)].
const ZH: Array = [
	["东", 300, 0.0, 6, -2.0],
	["方", 244, 0.8, -16, 1.5],
	["故", 264, 0.84, 18, -1.0],
	["事", 316, 0.82, -4, 1.5],
]
## 동방이야기, the Korean title, set the same way (owner 2026-11-22: a Korean brush hand near
## 飞云体's, the line under it in English).
const KO: Array = [
	["동", 290, 0.0, 4, -2.0],
	["방", 236, 0.74, -14, 1.5],
	["이", 214, 0.72, 16, -1.0],
	["야", 248, 0.66, -6, 1.0],
	["기", 296, 0.72, 8, -1.5],
]
## 東方物語, the Japanese title (owner 2026-11-22: 故事 is an anecdote in Japanese), set the same
## way, the line under it in English.
const JA: Array = [
	["東", 300, 0.0, 6, -2.0],
	["方", 244, 0.8, -16, 1.5],
	["物", 270, 0.84, 18, -1.0],
	["語", 310, 0.82, -4, 1.5],
]
## The titles baked alone, by language: -- <font> <language> [mask name].
const OWN: Dictionary = {"ko": KO, "ja": JA}
## The English title's lines: their size, and how far the second stands below the first (parts
## of the size).
const EN_SIZE: int = 150
const EN_LINES: PackedStringArray = ["Eastern", "Stories"]
const EN_LEADING: float = 0.9
const SEAL_SIZE: int = 120
## Clear pixels round the ink, for the shadow and the soaking edge.
const PAD: int = 48
## The wide blur: the mask is shrunk by this and stretched back.
const BLUR: int = 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <云峰飞云体.ttf>")
		quit(1)
		return
	var brush := FontFile.new()
	if brush.load_dynamic_font(args[0]) != OK:
		printerr("cannot load ", args[0])
		quit(1)
		return
	var plain: FontFile = load(PLAIN) as FontFile
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if args.size() >= 2 and OWN.has(args[1]):
		_save(await _mask(_brushed(OWN[args[1]], brush)), args[2] if args.size() >= 3 else "logo_" + args[1])
		quit(0)
		return
	_save(await _mask(_brushed(ZH, brush)), "logo_zh_CN")
	var english: Array = []
	for r: int in EN_LINES.size():
		english.append([EN_LINES[r], brush, EN_SIZE, Vector2(0.0, EN_SIZE * EN_LEADING * r), 0.0, 0])
	_save(await _mask(english), "logo_en")
	_save(await _mask([["侠", plain, SEAL_SIZE, Vector2.ZERO, 0.0, 0]]), "seal_zh_CN")
	quit(0)


## A brushed title's characters ([character, size, step, drop, turn] rows) as _mask() pieces.
func _brushed(rows: Array, brush: Font) -> Array:
	var lettered: Array = []
	var x: float = 0.0
	var last: float = 0.0
	var tallest: float = 0.0
	for piece: Array in rows:
		tallest = maxf(tallest, float(piece[1]))
	for piece: Array in rows:
		x += last * float(piece[2])
		var size: float = float(piece[1])
		# A label's glyph sits about its own size tall from its top: middles on one line.
		lettered.append([piece[0], brush, int(size), Vector2(x, (tallest - size) * 0.62 + float(piece[3])), float(piece[4]), 0])
		last = size
	return lettered


func _save(mask: Image, file: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT + file + ".png")
	mask.save_png(path)
	print("BAKED %s %dx%d" % [path, mask.get_width(), mask.get_height()])


## The pieces ([text, font, size, where, turn in degrees, letter spacing]) in white on clear, all
## on one sheet, cropped to their ink and padded: red is the ink (its antialiased edge kept),
## green the ink blurred wide.
func _mask(pieces: Array) -> Image:
	var room := Vector2.ZERO
	for piece: Array in pieces:
		var size: int = piece[2]
		var reach: Vector2 = (piece[3] as Vector2) + Vector2((size + int(piece[5])) * String(piece[0]).length() + size, size * 2.2)
		room = room.max(reach)
	var paper := SubViewport.new()
	paper.transparent_bg = true
	paper.size = Vector2i(room) + Vector2i(200, 200)
	paper.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(paper)
	for piece: Array in pieces:
		var size: int = piece[2]
		var label := Label.new()
		label.text = piece[0]
		# Spacing on the font's own variation when it has one (a second layer would drop its weight).
		var font: Font = piece[1]
		var face: FontVariation = (font as FontVariation).duplicate() if font is FontVariation else FontVariation.new()
		if not font is FontVariation:
			face.base_font = font
		face.spacing_glyph = int(piece[5])
		label.add_theme_font_override("font", face)
		label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.position = Vector2(100, 100) + (piece[3] as Vector2)
		label.pivot_offset = Vector2(size, size) / 2.0
		label.rotation_degrees = float(piece[4])
		paper.add_child(label)
	for i: int in 4:
		await process_frame
	var image: Image = paper.get_texture().get_image()
	paper.queue_free()
	image = image.get_region(image.get_used_rect())
	var w: int = image.get_width() + PAD * 2
	var h: int = image.get_height() + PAD * 2
	var ink := Image.create_empty(w, h, false, Image.FORMAT_L8)
	ink.fill(Color.BLACK)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var a: float = image.get_pixel(x, y).a
			ink.set_pixel(x + PAD, y + PAD, Color(a, a, a))
	var wide: Image = ink.duplicate()
	wide.resize(maxi(1, w / BLUR), maxi(1, h / BLUR), Image.INTERPOLATE_LANCZOS)
	wide.resize(w, h, Image.INTERPOLATE_CUBIC)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y: int in h:
		for x: int in w:
			out.set_pixel(x, y, Color(ink.get_pixel(x, y).r, wide.get_pixel(x, y).r, 0.0))
	return out
