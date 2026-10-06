class_name HockshopPayoutResult
extends RefCounted

enum Outcome { COMPLETE, AUTHORITY_FAILURE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var requested_value: int = 0
## Transfer-admitted value, even if a subsequent merge/index authority fails.
var delivered_value: int = 0
var attempts: Array[HockshopPayoutAttempt] = []
