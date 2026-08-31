# Repository Policy

Recommended flow:

```text
main -> feature/phase branch -> focused implementation/tests -> formal audit -> complete suite -> PR -> CI -> merge
```

Recommended `main` branch protection:

- require a pull request;
- require `Godot Verify`;
- require `Windows Release Build`;
- require `Android Release Build`;
- require `iOS Build Validation`;
- prevent merge while a required check is failing.

For a solo repository, no arbitrary reviewer count is recommended. Phase 10A documents this policy
but does not modify remote GitHub settings.

Generated binaries, export templates, temporary production projects, Xcode output, manifests, and
ephemeral signing keys must remain untracked. Gameplay migration PRs should keep
`reference/es2/` read-only, cite authoritative source paths, and update
`docs/migration/DECISIONS.md` only for real compatibility substitutions.
