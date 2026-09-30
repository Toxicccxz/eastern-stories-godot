# Repository Policy

`main` is the stable integration line. Normal development does not happen directly on `main`.

## Branches and PRs

```text
green main -> phase/<slug> branch -> focused commits -> full verify.py -> ready PR
  -> four CI jobs green on the final commit -> owner merges -> main CI runs again
```

* Start from the latest `main` whose post-merge CI is green (`git switch main`,
  `git pull --ff-only`, `git switch -c phase/<slug>`).
* One content package, or a few small related ones, per branch and PR. Multiple focused commits are
  expected; squashing is not required.
* Pushing a branch without a PR is fine for backup and does not run the expensive CI.
* The agent commits, pushes branches and opens PRs. **Only the owner merges.**
* Draft PRs skip the expensive jobs until marked ready.

## CI

The four required jobs are `Godot Verify`, `Windows Release Build`, `Android Release Build` and
`iOS Build Validation`. They run when a ready PR to `main` is opened, reopened, synchronized or
marked ready, on every push to `main`, and on manual `workflow_dispatch`.

If PR CI fails, fix it on the same branch. If post-merge `main` CI fails, fix it first on a narrow
`hotfix/<issue>` branch from `main` before other work. Never weaken or skip the gate to get green.

Recommended remote setting (not enforced by this repository): require a PR and the four checks
before merging into `main`.

## Not allowed without explicit owner instruction

Merging, force-pushing or rewriting published history, deleting remote branches/tags, changing
repository settings/rulesets/secrets/permissions, publishing releases or deploying to any store.

## Content boundaries

Generated binaries, export templates, temporary release projects, logs and signing keys stay
untracked (see `.gitignore`). `reference/es2/` is read-only. `docs/migration/DECISIONS.md` records
only real gameplay deviations and global compatibility rules.
