extends RefCounted
## Text that wrapping has stood on end: a visible Label or RichTextLabel that wraps into a column
## of one or two characters a line, as 设置's 总音量 did ("80%" as "8 / 0 / %", 2026-11-21) — a
## wrapping label in a row gets only the width its siblings leave it, and a non-expanding one
## none at all. `under(root)` describes each such label under `root`; an empty list is a pass.

## Lines this narrow (in glyphs of the label's own font size), or with fewer characters than this
## on average, read as a column of single characters.
const LEAST_GLYPHS: float = 2.5


static func under(root: Node) -> Array[String]:
	var found: Array[String] = []
	_collect(root, found)
	return found


static func _collect(node: Node, found: Array[String]) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label or node is RichTextLabel:
		var finding: String = describe(node as Control)
		if not finding.is_empty():
			found.append(finding)
	for child: Node in node.get_children():
		_collect(child, found)


## Why `control` (a Label or RichTextLabel) reads as a column of characters, or "".
static func describe(control: Control) -> String:
	var text: String
	var lines: int
	var font_size: int
	var mode: int
	if control is Label:
		var label: Label = control as Label
		text = label.text
		lines = label.get_line_count()
		font_size = label.get_theme_font_size(&"font_size")
		mode = label.autowrap_mode
	elif control is RichTextLabel:
		var rich: RichTextLabel = control as RichTextLabel
		text = rich.get_parsed_text()
		lines = rich.get_line_count()
		font_size = rich.get_theme_font_size(&"normal_font_size")
		mode = rich.autowrap_mode
	else:
		return ""
	text = text.strip_edges()
	# Only wrapping counts: lines the text breaks itself are authored.
	if mode == TextServer.AUTOWRAP_OFF or text.length() < 2 or lines <= text.count("\n") + 1:
		return ""
	var room: float = control.size.x / maxf(1.0, float(font_size))
	var per_line: float = float(text.replace("\n", "").length()) / float(lines)
	if room >= LEAST_GLYPHS and per_line >= LEAST_GLYPHS:
		return ""
	return "%s '%s' is %.0f wide in %d lines" % [control.get_path(), text.substr(0, 24), control.size.x, lines]
