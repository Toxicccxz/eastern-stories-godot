extends RefCounted

## Controlled numeric opponent, NOT a production player buff/loadout/spawn.
## Serpent uses the real BF1 definition/factory and the production binding seam.
var inventory: InventoryState = InventoryState.new()
var stacks: CombinedStackCollection = CombinedStackCollection.new()
var npc: NpcRuntimeState
var serpent: CombatSliceCharacterBinding
var human: CombatSliceCharacterBinding
var effects: SkillImprovementEffectRegistry = SkillImprovementEffectRegistry.new()


func _init() -> void:
	npc = NpcCharacterStateFactory.new().create_one(
		OldPineNpcDefinitions.serpent_definition(), &"test.serpent", &"test.spawn", &"test.point",
		WorldLocationState.new(&"test.region", &"test.map", &"test.zone", &"test.combat"),
		inventory, stacks, ScriptedNpcInitializationRandomSource.new([0, 0, 0]), [],
	)
	serpent = WorldCombatBindingAdapter.from_npc(npc, CombatSliceContentProfile.new())
	var state: CharacterState = CharacterState.new(
		CharacterBaseAttributes.new(20, 20, 20, 20, 20, 20, 20, 20),
		CharacterResourceState.new(1000, 1000, 1000),
		CharacterResourceState.new(1000, 1000, 1000),
		CharacterResourceState.new(1000, 1000, 1000),
	)
	state.progression.combat_experience = 1000
	human = CombatSliceCharacterBinding.new(
		&"test.human", state, CombatRelationshipState.new(&"test.human"),
		ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(),
		&"test.combat", true, CombatSliceLifeStatus.Value.ACTIVE, true,
	)
	effects.register_legacy_defaults()
	CombatSliceOpportunityExecutor.initiate_lethal_combat(serpent, human)


func execute(actor: CombatSliceCharacterBinding, rng: CombatRandomSource) -> CombatSliceOpportunityResult:
	var target: CombatSliceCharacterBinding = human if actor == serpent else serpent
	# Explicit target uses the existing specific-opponent seam, not random discovery.
	return CombatSliceOpportunityExecutor.execute_opportunity(
		actor, [serpent, human], rng, effects, target.character_id,
	)


func project(actor: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding) -> CombatAttackInput:
	return CombatSliceProjectionBuilder.build_attack_input(
		actor, target, actor.content.attack_template_for(actor.state.equipment.primary_weapon()),
	)


func reverse(actor: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding) -> CombatReverseAttackProjection:
	return CombatSliceProjectionBuilder.build_reverse_projection(actor, target,
		CombatRiposteRequest.new(true, actor.character_id, target.character_id,
			CombatAttackType.Value.QUICK, &"test.forward", 0, 20, 0))
