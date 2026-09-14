class_name HockshopSellResult
extends RefCounted

enum Outcome { REJECTED, SOLD, AUTHORITY_FAILURE }
enum Stage { VALUATION, PAYOUT, ITEM_REMOVAL, FOOD_FORGET, LIQUID_FORGET, INDEX_FORGET, COMPLETE }
var outcome: Outcome = Outcome.REJECTED
var stage: Stage = Stage.VALUATION
var valuation: HockshopValuationResult
var payout: HockshopPayoutResult
var removal: ItemLifecycleResult
var food_forgotten: bool = false
var liquid_forgotten: bool = false
var index_forgotten: bool = false
