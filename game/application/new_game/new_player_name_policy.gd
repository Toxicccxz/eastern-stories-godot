class_name NewPlayerNamePolicy
extends RefCounted

## logind.c::check_legal_name intent; Unicode code points, not legacy bytes.
## No trimming, replacement, account ID or multiplayer banned-name registry.
static func is_valid(value: String) -> bool:
	if value.length() < 1 or value.length() > 6:
		return false
	var han := RegEx.new()
	if han.compile("\\A\\p{Han}+\\z") != OK:
		return false
	return han.search(value) != null
