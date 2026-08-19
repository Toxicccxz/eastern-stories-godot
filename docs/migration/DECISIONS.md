# Migration Decisions

## Condition update order

**Decision:** A single native condition update uses a snapshot of active condition IDs sorted by stable ID string in ascending order.

**Reason:** `feature/condition.c` obtains `keys(conditions)` from an LPC mapping and iterates that array backwards. The mudlib does not define mapping key order as gameplay data, yet multiple conditions can mutate the same resource and therefore need a deterministic native order. Stable ID order is independent of insertion order, hash layout, and save/restore behavior.

**Compatibility impact:** Multiple simultaneous conditions may resolve in a different order from a particular MudOS/FluffOS process. Individual condition formulas, flag aggregation, snapshot behavior, and post-update removal semantics remain unchanged. Source: `reference/es2/mudlib/feature/condition.c`.
