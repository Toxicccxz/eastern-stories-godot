class_name ApplicationActivity
extends RefCounted

enum Event { PAUSED, RESUMED, FOCUS_OUT, FOCUS_IN }
enum Change { NONE, INTERACTION_LOST, REACTIVATING }
enum ResumeGate { NORMAL, EXPLICIT_AFTER_LIFECYCLE }

var _foreground: bool = true
var _focused: bool = true
var _presentation_ready: bool = true
var _resume_gate: ResumeGate = ResumeGate.NORMAL


func interaction_allowed() -> bool:
	return _foreground and _focused and _presentation_ready


func foreground() -> bool:
	return _foreground


func focused() -> bool:
	return _focused


func resume_gate() -> ResumeGate:
	return _resume_gate


func require_explicit_resume() -> void:
	_resume_gate = ResumeGate.EXPLICIT_AFTER_LIFECYCLE


func clear_resume_gate() -> void:
	_resume_gate = ResumeGate.NORMAL


func receive(event: Event) -> Change:
	var was_active: bool = _foreground and _focused
	match event:
		Event.PAUSED: _foreground = false
		Event.RESUMED: _foreground = true
		Event.FOCUS_OUT: _focused = false
		Event.FOCUS_IN: _focused = true
	var now_active: bool = _foreground and _focused
	if was_active == now_active:
		return Change.NONE
	_presentation_ready = false
	return Change.REACTIVATING if now_active else Change.INTERACTION_LOST


func finish_reactivation() -> bool:
	# Measurement and deferred layout must settle before another contact is accepted.
	if not _foreground or not _focused or _presentation_ready:
		return false
	_presentation_ready = true
	return true
