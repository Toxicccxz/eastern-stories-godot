class_name SessionItemIdScopeFactory
extends RefCounted

const OLD_PINE_PREFIX: String = "oldpine-session-"
const ENTROPY_BYTE_COUNT: int = 16


## New-game scope identity uses platform cryptographic entropy. This source is
## deliberately separate from every gameplay RNG stream and is persisted
## verbatim by the save snapshot after creation.
static func create_old_pine_scope() -> StringName:
	return old_pine_scope_from_entropy(
		Crypto.new().generate_random_bytes(ENTROPY_BYTE_COUNT)
	)


## Deterministic validation seam for the scope format; production calls the
## platform-backed source above.
static func old_pine_scope_from_entropy(entropy: PackedByteArray) -> StringName:
	if entropy.size() != ENTROPY_BYTE_COUNT:
		return &""
	return StringName(OLD_PINE_PREFIX + entropy.hex_encode())
