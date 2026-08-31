# Repository Policy

Recommended flow:

```text
main -> feature/phase branch -> focused implementation/tests -> formal audit -> complete suite -> PR -> merge -> CI
```

Recommended `main` branch protection:

- require a pull request;
- do not configure the post-merge `Godot Verify`, `Windows Release Build`, `Android Release Build`,
  or `iOS Build Validation` jobs as required pre-merge checks;
- treat a failed post-merge workflow as a broken `main` that should be diagnosed and repaired
  promptly.

The cross-platform workflow runs automatically only when a pull request is actually merged into
`main`; branch pushes, direct pushes to `main`, and updates to open pull requests do not run it.
Manual dispatch remains available when an explicit pre-merge or diagnostic run is needed.

For a solo repository, no arbitrary reviewer count is recommended. Phase 10A documents this policy
but does not modify remote GitHub settings.

Generated binaries, export templates, temporary production projects, Xcode output, manifests, and
ephemeral signing keys must remain untracked. Gameplay migration PRs should keep
`reference/es2/` read-only, cite authoritative source paths, and update
`docs/migration/DECISIONS.md` only for real compatibility substitutions.
