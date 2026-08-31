# Repository Policy

`main` is the stable integration line and represents the latest integrated major phase. Normal
development does not happen directly on `main`.

## One major phase, one branch, one final PR

A major development phase is the highest planned implementation milestone intended to culminate in
one integration PR. The project plan, not numbering syntax alone, defines this boundary:

```text
one planned integration milestone = one phase branch = one final PR
```

Start a new major phase from the latest `main` whose post-merge CI is green:

```text
git switch main
git pull --ff-only
git switch -c phase/<phase>-<slug>
```

Use the repository/tool-required branch prefix when applicable. For example, Phase 10B may use
`phase/10b-native-save-load` or `codex/phase-10b-native-save-load`. That one branch may contain 10B
analysis, 10B1, 10B2, 10B3, focused implementation commits, and formal-audit corrections. It does
not imply that every phase has exactly three slices. Sub-slices receive separate branches/PRs only
when the plan explicitly promotes them to independent major integration milestones.

Do not start a phase from an unfinished previous phase. Do not use `main` as a scratch branch.
Pushing the phase branch for backup, collaboration, or continuation is allowed and does not run the
full cross-platform CI before a PR exists.

## Integration lifecycle

```text
green main
  -> create one major-phase branch
  -> keep every subordinate slice and audit fix on that branch
  -> run focused tests throughout
  -> complete the major phase's local formal audit and required local validation
  -> create one final ready-for-review PR to main
  -> run all four PR CI jobs
  -> fix failures on the same branch and synchronize the PR until green
  -> merge only after all four jobs pass for the same final PR commit
  -> run all four jobs again on the resulting main push
  -> declare the phase fully integrated only after main CI is green
  -> delete the phase branch when no longer needed
  -> start the next major phase
```

Do not open the integration PR at the beginning of routine development. A draft PR is exceptional
and should be explicitly requested for collaboration/review; expensive jobs remain skipped until it
is ready for review. Development commits do not need to be squashed into one commit.

A major phase may progress through `IMPLEMENTATION COMPLETE`, `LOCAL FORMAL AUDIT PASSED`, `PR CI
PASSED`, and `MERGED TO MAIN`. For future phases, formal project integration closure additionally
requires green post-merge main CI. Historical migration records are not rewritten to use this newer
terminology.

Keep the phase branch until merge and post-merge CI are both complete. Codex may prepare and verify a
merge but does not perform it without explicit user authorization.

## CI event and cost contract

The four stable jobs are:

- `Godot Verify`;
- `Windows Release Build`;
- `Android Release Build`;
- `iOS Build Validation`.

Expected events:

| Event | Full CI |
| --- | --- |
| Local commit | No |
| Push ordinary phase branch without a PR | No |
| Open/reopen a ready PR targeting `main` | Yes |
| Push another commit to that open PR (`synchronize`) | Yes |
| Mark a draft PR ready for review | Yes |
| Update a draft PR while it remains draft | Skipped |
| Close a PR without merging | No main-push run |
| Merge the PR into `main` | Yes, again on `push: main` |
| Manual `workflow_dispatch` | Yes |

This model exists because the complete matrix uses Linux, Windows, Android, and macOS resources.
Focused/local validation supports ongoing development; expensive remote CI validates the final
integration candidate before merge and the integrated `main` result afterward. Workflow event
presence is not itself proof of success: reports must cite actual job results.

## Main protection and failures

Recommended GitHub branch protection/ruleset for `main`:

- require a pull request before merging;
- block normal direct pushes;
- require all four stable PR checks for the same final commit;
- permit only intentional administrative/emergency override if the repository owner wants one.

**RECOMMENDED / NOT YET ENFORCED REMOTELY:** this repository documents the desired settings but this
policy update does not modify remote GitHub configuration. The `push: main` workflow intentionally
runs after every main push; it does not inspect commit messages to guess whether a push was a merge.
PR-only integration must be enforced by the remote ruleset.

If PR CI fails, do not merge. Fix the problem on the same phase branch and let PR synchronization
rerun CI. If green PR CI is followed by failed post-merge main CI, do not start the next major phase
and do not weaken the gate. Stabilize current `main` through a narrow `hotfix/<issue>` (or equivalent)
branch, then follow branch -> PR -> CI -> merge -> main CI. A real hotfix is the naming exception to
the major-phase branch rule; routine direct main commits are not.

## Standing authorization for CI stabilization

The repository owner has granted Codex standing authorization for the minimum external-write workflow
needed to restore this repository's existing required CI gates when the latest `main` post-merge CI
is not fully green. This avoids stopping solely to ask for routine stabilization permission.

Within `Toxicccxz/eastern-stories-godot`, Codex may inspect Actions logs, rerun failed jobs/runs,
create one narrow `hotfix/...` or `stabilization/...` branch from current `main`, make the smallest
necessary CI/build/test fix, commit and push that branch, create/update a PR to `main`, and continue
narrow fixes on the same branch until the required checks are green.

This standing authorization does **not** permit Codex to merge into `main`, force-push, rewrite
published history, delete remote branches/tags, change repository settings/rulesets/branch
protection/secrets/permissions/Actions credentials, publish releases, deploy to stores/services,
modify unrelated repositories, or expand a CI hotfix into unrelated gameplay/content/refactor work.
Those actions still require separate explicit authorization where applicable.

Once the stabilization PR is green, Codex stops before merge and reports the result. A single green
retry after a nondeterministic failure demonstrates that the commit can pass, but repeated flakes
should be investigated rather than hidden by endless reruns.

## Repository content boundaries

Generated binaries, export templates, temporary production projects, Xcode output, manifests, and
ephemeral signing keys remain untracked. Gameplay migration work keeps `reference/es2/` read-only,
cites authoritative LPC paths, and updates `docs/migration/DECISIONS.md` only for real gameplay
compatibility substitutions.
