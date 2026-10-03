class_name WorldService
extends Node

## Runtime half of a data-defined room service (ServiceDefinition). The map
## creates one per WorldServicePoint; a subclass per kind holds the kind's rules
## and panel. NpcService is the same for what an NPC offers from its body. Panels live on this node's own CanvasLayer until the shared UI
## borrows them (SharedGameplayUI.open_business).
var map: WorldMapController
var definition: ServiceDefinition
var point: WorldServicePoint
var _ui: CanvasLayer


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	map = p_map
	definition = p_definition
	point = p_point
	name = String(definition.service_id).replace(".", "_")


func service_id() -> StringName:
	return definition.service_id


## The name before the verb in the context button, e.g. 钱庄.
func display_name() -> String:
	return definition.display_name


## Kind verb shown after the service name, e.g. 钱庄 · 兑换.
func verb() -> String:
	return ""


## Services that ES2 gates on an idle, non-fighting player (busy blocks them).
func requires_idle() -> bool:
	return false


func in_reach() -> bool:
	return (
		map != null
		and map.can_act(requires_idle())
		and map.player_near([definition.zone_id], point.global_position, definition.reach)
	)


func context_title() -> String:
	return "%s · %s" % [display_name(), verb()] if in_reach() else ""


## Where the service is, for picking the nearest thing the context button acts on.
func anchor() -> Vector2:
	return point.global_position


func interact() -> void:
	pass


## Back/Escape while this service's panel is open. True when handled here.
func dismiss(_content: Control) -> bool:
	return false


func ui_layer() -> CanvasLayer:
	if _ui == null:
		_ui = CanvasLayer.new()
		_ui.name = "UI"
		_ui.layer = 12
		add_child(_ui)
	return _ui


func open_panel(title: String, panel: Control) -> void:
	if map.session == null or ExplorationPresentationBlocker.is_blocked(get_tree()):
		return
	map.session.shared_ui().open_business(title, panel, in_reach)
	map.player_body.quarantine_current_movement_input()
