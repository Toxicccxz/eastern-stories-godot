extends RefCounted

## The HUD's toasts at the bottom left (owner, 2026-10-06): a new message rises from
## below and pushes the older one up; past two, the oldest fades out upward (each read
## at least MIN_SHOWN_SECONDS first); they fade in order after a while. Lines that come
## while a panel that shows its own lines (打听, an NPC's panel) or a fight is open are
## not toasted; 背包 and the like let them through; 消息 keeps every line. Then the
## status card's bars and the toasts in a Snow session.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_component(tree)
	await _test_hud(tree)
	return {"assertions": _count, "failures": _failures}


func _test_component(tree: SceneTree) -> void:
	var host := Control.new()
	host.size = Vector2(800, 600)
	tree.root.add_child(host)
	var toasts := MessageToasts.new()
	host.add_child(toasts)
	toasts.set_process(false) # TEST-ONLY: the test drives the frames
	var area := Rect2(16, 16, 768, 568)
	toasts.place(area, 440, 3)
	var nodes: int = toasts.get_child_count()
	_check(nodes == MessageToasts.POOL and toasts.shown_texts().is_empty(), "a fixed pool, nothing shown")
	toasts.push("第一条")
	toasts.push("第二条", SharedGameplayUI.ALERT_COLOR, true)
	toasts.push("第三条")
	_check(toasts.latest_text() == "第三条" and toasts.shown_texts().is_empty(), "pushed messages wait for the next frames")
	toasts._process(0.01)
	_check(toasts.shown_texts() == ["第一条"], "one comes in at a time")
	var first: PanelContainer = _panel_of(toasts, "第一条")
	_check(first != null and first.modulate.a < 0.5, "it fades in")
	_frames(toasts, 0.05, 10) # 0.5 s: the second follows SPACING_SECONDS later
	_check(toasts.shown_texts() == ["第一条", "第二条"], "two show; the third waits: %s" % str(toasts.shown_texts()))
	_frames(toasts, 0.05, 10) # 1.0 s: the first not yet read long enough
	_check(toasts.shown_texts() == ["第一条", "第二条"], "the first stays MIN_SHOWN_SECONDS before it is pushed out")
	_frames(toasts, 0.05, 20) # 2.0 s
	_check(toasts.shown_texts() == ["第二条", "第三条"], "then the third pushes the first out: %s" % str(toasts.shown_texts()))
	var second: PanelContainer = _panel_of(toasts, "第二条")
	var third: PanelContainer = _panel_of(toasts, "第三条")
	_check(second != null and third != null and second.position.y + second.size.y <= third.position.y, "the older one stands above the newer")
	_check(third.position.y + third.size.y <= area.size.y - MessageToasts.RISE + 0.5, "the newest rests just above the bottom")
	_check(is_equal_approx(third.modulate.a, 1.0) or third.modulate.a > 0.95, "shown in full")
	_check((second.get_node("Text") as Label).get_theme_color("font_color") == SharedGameplayUI.ALERT_COLOR, "an ES2 colour stays (HIR red)")
	_check((third.get_node("Text") as Label).get_theme_color("font_color") == MessageToasts.PLAIN_TEXT, "a plain line stays plain")
	_check(first.visible == false or first.modulate.a < 0.05, "the first faded out")
	for panel: Node in toasts.get_children():
		if (panel as Control).visible:
			_check(Rect2(Vector2.ZERO, area.size).grow(0.5).encloses(Rect2((panel as Control).position, (panel as Control).size)), "every toast stays inside the area")
	toasts.push("一条很长的消息，" + "停留得也更久一些，".repeat(8))
	_frames(toasts, 0.25, 8) # the long one comes in
	_frames(toasts, 0.25, 20) # 7 s: 第二条 and 第三条 past their LINGER, oldest first
	_check(toasts.shown_texts().size() == 1 and toasts.shown_texts()[0].begins_with("一条很长的消息"), "they fade in order; the long one stays longer: %s" % str(toasts.shown_texts()))
	_frames(toasts, 0.25, 80) # 20 s: past LINGER_MAX
	_check(toasts.shown_texts().is_empty(), "read messages fade out after a while")
	toasts.push("在面板里说的话")
	toasts.set_suppressed(true)
	_check(not toasts.visible and toasts.latest() == null, "a panel opens: the toasts go")
	toasts.push("面板打开时的一行")
	toasts._process(0.5)
	_check(toasts.latest() == null and toasts.shown_texts().is_empty(), "lines while a panel shows are not toasted")
	toasts.set_suppressed(false)
	for index: int in 6:
		toasts.push("第%d行" % index)
	_frames(toasts, 0.05, 40)
	_check(toasts.shown_texts() == ["第4行", "第5行"], "a burst keeps its last MAX_WAITING and ends on its last two: %s" % str(toasts.shown_texts()))
	_check(toasts.get_child_count() == nodes, "messages never add or free nodes")
	host.free()
	await tree.process_frame


func _test_hud(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	for frame: int in range(5):
		await tree.process_frame
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(hud.player_name.text == player.facts.display_name and hud.world_title.text == tr(hud.location_name()), "the card's name and place")
	_check(hud.player_vitality.max_value == player.state.vitality.maximum and hud.player_vitality.value == player.state.vitality.current, "气's bar")
	_check(hud.player_essence.value == player.state.essence.current and hud.player_spirit.value == player.state.spirit.current, "精's and 神's bars")
	_check(hud.player_vitality_value.text == "%d/%d" % [player.state.vitality.current, player.state.vitality.effective], "气 current/effective")
	_check(not hud.player_vitality_text.visible, "no conditions line without a condition")
	var arrival: String = hud.log_lines().back()
	_check(arrival.begins_with("【") and hud.toasts().latest_text() == arrival.replace("\n", " "), "the room's text on arrival is a toast")
	hud.append_log_lines(["一句场景里的话"])
	_check(hud.toasts().latest_text() == "一句场景里的话", "a scene line is a toast")
	hud.open_inventory()
	await tree.process_frame
	_check(hud.inventory_is_open() and not hud.toasts().is_suppressed(), "背包 open: toasts still come (it shows no lines of its own)")
	hud.append_log_lines(["背包打开时的一句"])
	_check(hud.toasts().latest_text() == "背包打开时的一句", "a give's answer reads at once")
	hud.dismiss_current_panel()
	await tree.process_frame
	var form := VBoxContainer.new() # TEST-ONLY: an NPC's panel
	form.add_child(Label.new())
	hud._presentation_layout.holding.add_child(form)
	hud.open_business("测试", form, Callable())
	await tree.process_frame
	_check(hud.toasts().is_suppressed() and not hud.toasts().visible, "an NPC's panel open: no toasts")
	hud.append_log_lines(["对话框里的一句"])
	_check(hud.toasts().latest() == null and hud.log_lines().back() == "对话框里的一句", "a line while it shows stays in 消息 only")
	hud.dismiss_current_panel()
	for frame: int in range(3):
		await tree.process_frame
	hud.refresh_exploration()
	_check(not hud.toasts().is_suppressed(), "the panel closed: toasts again")
	hud.open_look()
	await tree.process_frame
	_check(not hud.toasts().is_suppressed(), "观察 lets toasts through too")
	hud.dismiss_current_panel()
	await tree.process_frame
	hud.show_combat_result("你赢了这场战斗。\n一行战斗描写")
	_check(hud.toasts().latest_text() == "你赢了这场战斗。" and hud.log_lines().back() == "你赢了这场战斗。\n一行战斗描写", "a fight's result: its first line as a toast, all of it in 消息")
	session.free()
	await tree.process_frame


func _panel_of(toasts: MessageToasts, text: String) -> PanelContainer:
	for node: Node in toasts.get_children():
		var panel := node as PanelContainer
		if panel != null and panel.visible and (panel.get_node("Text") as Label).text == text:
			return panel
	return null


func _frames(toasts: MessageToasts, delta: float, count: int) -> void:
	for index: int in count:
		toasts._process(delta)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
