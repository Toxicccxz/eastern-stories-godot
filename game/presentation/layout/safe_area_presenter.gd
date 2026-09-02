class_name SafeAreaPresenter
extends Node

signal metrics_changed(metrics: SafeAreaMetrics)

var _capability: SafeAreaCapability = GodotSafeAreaCapability.new()
var _metrics: SafeAreaMetrics
var _elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	# One presentation sampler catches content-transform / 180-degree safe-area changes
	# that do not resize the viewport. No lifecycle or input policy belongs here.
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()


func set_capability(capability: SafeAreaCapability) -> void:
	if capability == null:
		return
	_capability = capability
	if is_inside_tree():
		refresh()


func current_metrics() -> SafeAreaMetrics:
	return _metrics


func refresh() -> void:
	var next: SafeAreaMetrics = _capability.measure(get_viewport())
	if next == null:
		next = SafeAreaCapability.new().measure(get_viewport())
	if next.equivalent(_metrics):
		return
	_metrics = next
	metrics_changed.emit(_metrics)


static func find_or_create(consumer: Node) -> SafeAreaPresenter:
	var ancestor: Node = consumer
	while ancestor != null:
		var candidate: SafeAreaPresenter = ancestor.get_node_or_null("SafeAreaPresentation") as SafeAreaPresenter
		if candidate != null:
			return candidate
		ancestor = ancestor.get_parent()
	# Standalone production-map/test consumers still use the same capability, not a Session service.
	var presenter: SafeAreaPresenter = SafeAreaPresenter.new()
	presenter.name = "SafeAreaPresentation"
	consumer.add_child(presenter)
	return presenter
