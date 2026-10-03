class_name VisibleTextScan
extends RefCounted

## TEST-ONLY: the text a player can see under `root`, as it is drawn (a Label or Button
## shows its auto-translated text, a RichTextLabel its parsed text), with tooltips and
## LineEdit placeholders. Hidden branches are skipped.


## {node path: shown text} for every visible text under `root`.
static func shown(root: Node) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	_collect(root, result)
	return result


## "path: text" for each shown text with something left untranslated under the pseudo-locale.
static func untranslated(root: Node, allowed: PackedStringArray = PackedStringArray()) -> Array[String]:
	var findings: Array[String] = []
	var texts: Dictionary[String, String] = shown(root)
	for path: String in texts:
		var rest: String = PseudoLocale.untranslated(texts[path], allowed)
		if not rest.is_empty():
			findings.append("%s: %s" % [path.get_file(), texts[path].c_escape()])
	return findings


static func _collect(node: Node, result: Dictionary[String, String]) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null and not item.is_visible_in_tree():
		return
	var window: Window = node as Window
	if window != null and not window.visible:
		return
	var control: Control = node as Control
	if control != null:
		var path: String = str(control.get_path())
		var text: String = _shown_text(control)
		if not text.strip_edges().is_empty():
			result[path] = text
		if not control.tooltip_text.is_empty():
			result[path + "#tooltip"] = _translated(control, control.tooltip_text)
	for child: Node in node.get_children():
		_collect(child, result)


static func _shown_text(control: Control) -> String:
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text()
	if control is LineEdit:
		var edit: LineEdit = control as LineEdit
		return _translated(control, edit.placeholder_text) if edit.text.is_empty() else ""
	if control is Label:
		return _translated(control, (control as Label).text)
	if control is Button:
		return _translated(control, (control as Button).text)
	return ""


static func _translated(control: Control, text: String) -> String:
	return control.atr(text) if control.can_auto_translate() else text
