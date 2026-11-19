extends SceneTree
## Bakes the title's lettering masks (DECISIONS「标题画面」): 东方故事 in 马善政 (a brush hand),
## EASTERN STORIES in Cinzel Bold (an incised Roman), and the seal's 侠 in 霞鹜文楷 — rendered large,
## antialiased (the mask keeps its grey edge) and padded for the shadow, so TitleLogo can gild
## them smoothly at any size. The game reads only these masks, so the brush font is not shipped.
## Windowed (it renders text):
##   <godot> --path game --script <abs>/tools/ui/bake_title_logo.gd -- <MaShanZheng-Regular.ttf>
## Writes game/assets/textures/title/logo_zh_CN.png, logo_en.png, seal_zh_CN.png.

const OUT: String = "res://assets/textures/title/"
const PLAIN: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
const ROMAN: String = "res://assets/fonts/Cinzel-VariableFont_wght.ttf"
## Cinzel's weight axis: Bold.
const ROMAN_WEIGHT: int = 700
## Glyph sizes in pixels, and the spacing added between letters (pixels).
const ZH_SIZE: int = 240
const EN_SIZE: int = 150
const EN_SPACING: int = 12
const SEAL_SIZE: int = 120
## Clear pixels round the ink, for the shadow and the glow.
const PAD: int = 40


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <MaShanZheng-Regular.ttf>")
		quit(1)
		return
	var brush := FontFile.new()
	if brush.load_dynamic_font(args[0]) != OK:
		printerr("cannot load ", args[0])
		quit(1)
		return
	var plain: FontFile = load(PLAIN) as FontFile
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(await _mask("东方故事", brush, ZH_SIZE, 0), "logo_zh_CN")
	var roman := FontVariation.new()
	roman.base_font = load(ROMAN) as FontFile
	roman.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): ROMAN_WEIGHT}
	_save(await _mask("EASTERN STORIES", roman, EN_SIZE, EN_SPACING), "logo_en")
	_save(await _mask("侠", plain, SEAL_SIZE, 0), "seal_zh_CN")
	quit(0)


func _save(mask: Image, file: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT + file + ".png")
	mask.save_png(path)
	print("BAKED %s %dx%d" % [path, mask.get_width(), mask.get_height()])


## The text in white on clear, cropped to its ink and padded, as an 8-bit grey mask: 255 is ink,
## the antialiased edge kept.
func _mask(text: String, font: Font, size: int, spacing: int) -> Image:
	var paper := SubViewport.new()
	paper.transparent_bg = true
	paper.size = Vector2i((size + spacing) * text.length() + size, int(size * 2.2))
	paper.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(paper)
	var label := Label.new()
	label.text = text
	# Spacing on the font's own variation when it has one (a second layer would drop its weight).
	var face: FontVariation = (font as FontVariation).duplicate() if font is FontVariation else FontVariation.new()
	if not font is FontVariation:
		face.base_font = font
	face.spacing_glyph = spacing
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(size * 0.3, size * 0.4)
	paper.add_child(label)
	for i: int in 4:
		await process_frame
	var image: Image = paper.get_texture().get_image()
	paper.queue_free()
	image = image.get_region(image.get_used_rect())
	var grey := Image.create_empty(image.get_width() + PAD * 2, image.get_height() + PAD * 2, false, Image.FORMAT_L8)
	grey.fill(Color.BLACK)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var a: float = image.get_pixel(x, y).a
			grey.set_pixel(x + PAD, y + PAD, Color(a, a, a))
	return grey
