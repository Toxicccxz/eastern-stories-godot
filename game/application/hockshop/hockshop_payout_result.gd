class_name HockshopPayoutResult
extends RefCounted

enum Outcome { COMPLETE, AUTHORITY_FAILURE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var requested_value: int = 0
## Transfer-admitted value, even if a subsequent merge/index authority fails.
var delivered_value: int = 0
var attempts: Array[HockshopPayoutAttempt] = []
## Money that did not fit and lies on the `overflow` floor instead.
var overflow_item_ids: Array[StringName] = []
