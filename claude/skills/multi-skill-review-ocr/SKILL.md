---
name: multi-skill-review-ocr
description: Run the 5-dimension multi-skill review over the current branch diff via a Workflow, then write the findings to a JSON file in OpenCodeReview format (status/summary/comments) for apples-to-apples comparison against an OpenCodeReview run. Use when the user wants to benchmark their multi-skill review against OpenCodeReview, or asks for review output in OCR format.
argument-hint: "[base-branch] [out.json] [file ...]"
disable-model-invocation: true
allowed-tools: Task Workflow Write Bash(git diff:*) Bash(git rev-parse:*) Bash(git ls-files:*) Bash(date:*)
---

## Branch context

- Repo root: !`git rev-parse --show-toplevel`
- Current branch: !`git rev-parse --abbrev-ref HEAD`
- Changed files vs base (working tree + untracked, so this still works when the branch's work is entirely uncommitted; NEVER use `git merge-base` — a repo hook blocks the word "merge"): !`{ git diff --name-only "${ARGUMENTS:-main}" 2>/dev/null; git ls-files --others --exclude-standard; } | sort -u`

## Task

Run the `multi-skill-review-ocr` workflow and write its findings to disk in **OpenCodeReview JSON format**, so the result can be diffed directly against an OpenCodeReview run on the same files. This skill produces an artifact for comparison — it does NOT run the fix-selection loop (use `/multi-skill-review` for that).

1. Parse inputs from the context above and `$ARGUMENTS`:
   - `base`: first argument if it looks like a branch name, else `main`.
   - `out`: any argument ending in `.json` → the output path. Default: `<repoRoot>/multi-skill-review.json`.
   - `files`: explicit file paths in `$ARGUMENTS` (anything that's neither the base branch nor the `.json` out path); otherwise the changed-file list above.
   - `branch`, `repoRoot`: from the context above.
   - If the changed-file list is empty, tell the user there's nothing to review and stop.
   - If the user passed no explicit files and the list is large (>~15 files), list them and ask the user to narrow scope before running (each of the 5 skills reviews every file, so a big diff is expensive and dilutes findings).

2. Record wall-clock start, so `elapsed` can match OpenCodeReview's reporting:
   ```
   Bash: date +%s   →  capture as START
   ```

3. Call the **Workflow** tool with the saved script and the inputs as a real JSON object (NOT stringified — and verify the log doesn't say "No files passed", which means the file list silently fell back to a different repo):
   ```
   Workflow({
     scriptPath: "/Users/mateusz/.claude/workflows/multi-skill-review-ocr.js",
     args: { base, branch, repoRoot, files: [ ...changed files... ] }
   })
   ```
   It returns `{ status, summary: { files_reviewed, comments, output_tokens, note }, comments: [...], perSkill: [...] }`. The `comments` are already in OpenCodeReview shape (`path`, `content`, `suggestion_code?`, `existing_code`, `start_line`, `end_line`), deduped across the 5 dimensions with provenance noted in each `content`.

4. Record wall-clock end and compute elapsed:
   ```
   Bash: date +%s   →  capture as END
   ```
   `elapsed = END - START`, formatted as `<m>m<s>s` (e.g. 138s → `2m18s`; <60s → `<s>s`).

5. Assemble the final OpenCodeReview-format object and **Write** it to `out`:
   ```json
   {
     "status": "success",
     "summary": {
       "files_reviewed": <from workflow summary>,
       "comments": <from workflow summary>,
       "output_tokens": <from workflow summary>,
       "elapsed": "<computed in step 4>",
       "note": "<copy the workflow summary.note verbatim>"
     },
     "comments": [ <the workflow's comments array, verbatim> ]
   }
   ```
   - Match OpenCodeReview's top-level shape exactly: `status`, `summary`, `comments`. Keep the comments verbatim — do not re-summarize, re-order, or drop fields.
   - The `note` field is intentional and honest: this harness fans out to 5 parallel reviewers + 1 formatter, so `input_tokens`/`total_tokens`/`cache_*` are not exposed and are deliberately omitted. `output_tokens` and `elapsed` ARE measured. Do not fabricate the missing token counts.

6. Report back concisely:
   - The path you wrote.
   - One headline line per dimension from `perSkill` (`skill` — `summary`, with its `findingCount`).
   - Final counts: `comments` (after dedup), `output_tokens`, `elapsed`.
   - Remind the user this file is ready to diff against their OpenCodeReview run (e.g. `opus-review.json`), and that the original `/multi-skill-review` is the one to use for the interactive fix workflow.
