---
name: landing-prs
description: Land completed Bruce changes on main. Push directly by default; use the PR merge queue only when explicitly requested.
---

# Land Changes

Follow [the shared workflow guide](../../../guides/AI_WORKFLOW_GUIDE.md). Complete required
checks and reviewer cycles, commit the intended changes, fetch and integrate `origin/main`,
then push with `git push origin HEAD:main`. Never force-push `main`. Verify the remote contains
the intended commit and monitor CI before reporting success. A main push also starts the
automatic RC release workflow; report its result separately from the source landing.

Do not create a pull request or use the merge queue unless the user explicitly requests it.

## Explicitly requested pull requests

For a user-requested PR landing, use:

```sh
.agents/skills/landing-prs/scripts/land-pr.sh <PR>
```

The script enables auto-merge for a PR targeting `main`. A stacked PR waits for its parent to
merge before retargeting to `main` and enabling auto-merge. Never enable auto-merge on a child
while it still targets its parent's feature branch.

The launcher starts a background watcher and writes `.agent-tmp/landing-prs/watch-<PR>.log`.
Monitor that log until `mergedAt` is present or a fix-required terminal state occurs; launcher
success only means the watcher started. The scripts accept `--repo OWNER/REPO` when run outside
the checkout and require authenticated `gh` and `jq`.

Remove temporary worktrees only after confirmed landing, when clean and all changes are
recoverable. Never force-remove a dirty worktree.
