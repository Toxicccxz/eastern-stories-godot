class_name PourDefinition
extends RefCounted

## A powder one pours into a drink (`pour <powder> in <container>`): what drinking it
## does afterwards, on every sip until the container is filled again. `condition` grows
## by `dose` (slumber_drug.c's drink_drug(): 100), or by what the liquid's
## slumber_effect holds when `dose` is 0 (poison_dust.c's drink_drug()); each pour adds
## `adds_to_liquid` to that (poison_dust.c: 100).
var condition: StringName
var dose: int
var adds_to_liquid: int


func _init(p_condition: StringName = &"", p_dose: int = 0, p_adds_to_liquid: int = 0) -> void:
	condition = p_condition
	dose = p_dose
	adds_to_liquid = p_adds_to_liquid


## How much one sip adds to `condition` from a liquid this powder was poured into.
func dose_from(liquid: LiquidState) -> int:
	return dose if dose > 0 else liquid.slumber_effect


static func from_record(reader: ContentRecordReader) -> PourDefinition:
	var pour := PourDefinition.new(
		StringName(reader.required_text("condition")), reader.integer("dose"), reader.integer("adds_to_liquid"),
	)
	reader.finish()
	if pour.dose < 0 or pour.adds_to_liquid < 0 or (pour.dose > 0) == (pour.adds_to_liquid > 0):
		reader.fail("", "needs exactly one of a positive dose and a positive adds_to_liquid")
	return pour
