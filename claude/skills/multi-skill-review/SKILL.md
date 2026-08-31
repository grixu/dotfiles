---
name: multi-skill-review
description: Run 5 specialized code-review skills (code-review-excellence, comment-review, quality-review, self-code-review-checklist, hookify-review-changes) in parallel over the current branch diff via a Workflow, then report merged structured findings. Use when the user wants a thorough multi-angle self-review of their branch changes before opening a PR.
argument-hint: "[base-branch] [file ...]"
disable-model-invocation: true
allowed-tools: Task Workflow AskUserQuestion Bash(git diff:*) Bash(git rev-parse:*) Bash(git ls-files:*)
---

## Branch context

- Repo root: !`git rev-parse --show-toplevel`
- Current branch: !`git rev-parse --abbrev-ref HEAD`
- Changed files vs base (working tree + untracked, so this still works when the branch's work is entirely uncommitted; NEVER use `git merge-base` — a repo hook blocks the word "merge"): !`{ git diff --name-only "${ARGUMENTS:-main}" 2>/dev/null; git ls-files --others --exclude-standard; } | sort -u`

## Task

Run the `multi-skill-review` workflow to review this branch's diff across 5 review dimensions in parallel.

1. Determine the inputs from the context above and `$ARGUMENTS`:
   - `base`: first argument if it looks like a branch name, else `main`.
   - `files`: the changed-file list above. If the user passed explicit file paths in `$ARGUMENTS`, use those instead.
   - `branch`, `repoRoot`: from the context above.
   - If the changed-file list is empty, tell the user there's nothing to review and stop.
   - If the user passed no explicit files and the changed-file list is large (more than ~15 files), do NOT blindly review all of them — list them, and ask the user to narrow the scope to the files that matter (or confirm they really want the full set). Each of the 5 skills reviews every file, so a 100-file diff is 5× expensive and dilutes findings.
2. Call the **Workflow** tool with the saved script and these inputs as `args`:
   ```
   Workflow({
     scriptPath: "/Users/mateusz/.claude/workflows/multi-skill-review.js",
     args: { base, branch, repoRoot, files: [ ...changed files... ] }
   })
   ```
   (The script is also registered as the named workflow `multi-skill-review`; `scriptPath` is the robust way to invoke it.) Pass `args` as a real JSON object — NOT a stringified one — and double-check the workflow log doesn't say "No files passed": if `files` arrives empty the agents silently fall back to diffing a different/default repo, which is exactly the failure mode to avoid.
3. The workflow returns `{ base, branch, reviewedFiles, results: [{ skill, summary, findings[], skipped[] }] }`. Present a merged report:
   - One headline line per skill (its `summary`).
   - Assign every finding a stable ID (`F1`, `F2`, … sequential across the whole report) so the user can point to them in the next step. Group findings by **severity** (critical → high → medium → low → nit → info); render each as: `[Fn]` · `severity` · `file:lines` · `title` — `description`; then its `suggestedFix` and originating `skill`/`rule`.
   - De-duplicate findings that multiple skills raised on the same file+line into a single ID, and call out the agreement — independent skills converging on the same line is a strong confidence signal worth surfacing.
   - You may add a short, explicitly-advisory triage ("if it were me, I'd fix Fn and Fm first, because…"). Frame it as a recommendation that feeds the user's decision in the next step. Do NOT close the review with a self-made verdict like "no blockers / ready for PR — want me to fix any?". Whether a finding is worth fixing is the user's call, not yours; your job is to surface and triage, not to unilaterally decide nothing needs doing.
4. Hand the fix/no-fix decision to the user — this is the whole point of the skill, and it happens on **every** run that produced findings, no matter how minor they look. A branch whose only findings are nits still deserves the user's explicit choice on whether to sweep them.
   - **The one exception:** if all five skills returned **zero findings**, there's genuinely nothing to decide — say the branch is clean and stop.
   - Otherwise, ALWAYS ask via **`AskUserQuestion`** (a blocking prompt forces the decision instead of letting the turn drift to "done"), and make **every finding individually selectable**. Do NOT offer coarse batches like "fix all HIGH" or "high + medium" — bundling distinct fixes into one option takes the choice away from the user, who may want F3 fixed but not F4. Each option is ONE finding.
   - Fit the findings to the tool's real shape: a single `AskUserQuestion` call holds 1–4 questions, each question 2–4 options, and `multiSelect: true` turns a question into a checklist. So make each **option a single finding** — label `F3 — <short title>`, description `<file:line> · <severity> · <one-line fix>` — and group the findings into `multiSelect` questions by severity (one tier per question), splitting a tier across questions when it has more than 4 findings. One call covers up to 16 findings (4 questions × 4 options); if a review has more, issue additional `AskUserQuestion` calls until every finding has been offered individually. The auto-added "Other" is there for anything bespoke; leaving boxes unchecked means fix nothing.
   - Mind two limits of the tool: every question needs ≥2 options, so fold a lone finding into an adjacent tier's question rather than asking a one-option question; and if the whole report has exactly one finding, ask a single yes/no question instead ("Fix F1 — <title>?" → "Yes, fix it" / "No, leave it").
5. Apply exactly the findings the user ticked — nothing they didn't. If they ticked none, stop. This is a review, so don't fix anything before they choose, and don't silently re-run the review.
