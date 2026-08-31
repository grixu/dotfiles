export const meta = {
  name: 'multi-skill-review-ocr',
  description: 'Run the 5 multi-skill review dimensions in parallel, then emit findings in OpenCodeReview JSON format for apples-to-apples comparison',
  phases: [
    { title: 'Review', detail: 'one agent per review skill, in parallel' },
    { title: 'Format', detail: 'merge + dedup findings, map to OpenCodeReview comment shape' },
  ],
}

// args (supplied by the /multi-skill-review-ocr skill):
//   files:    string[] of changed files to review (relative to repoRoot). If empty, agents derive the diff themselves.
//   base:     base branch to diff against (default 'main')
//   branch:   current branch name (context only)
//   repoRoot: absolute repo root (required)
// AGENTS-NOTE: args sometimes arrives as a JSON-encoded string instead of an object; a naive typeof check
// then drops the whole payload, which would leave the agents reviewing whatever worktree they land in.
let a = {}
if (args && typeof args === 'object') a = args
else if (typeof args === 'string') { try { a = JSON.parse(args) } catch { a = {} } }
if (!a.repoRoot) throw new Error('args.repoRoot is required — every prompt below pins its commands to that path')
const REPO_ROOT = a.repoRoot
const BASE = a.base || 'main'
const BRANCH = a.branch || '(current branch)'
const FILES = Array.isArray(a.files) ? a.files.filter(Boolean) : []

// budget.spent() returns output tokens spent this turn across the main loop and all workflows; the delta
// across this whole script is the only token signal exposed in-script. input/cache totals are NOT available,
// so the OpenCodeReview summary block is filled best-effort by the driving skill (see SKILL.md).
const startSpent = budget.spent()

if (!FILES.length) {
  log('No files passed in args.files — agents will derive the changed-file set from the diff themselves.')
}

const SCHEMA = {
  type: 'object',
  required: ['skill', 'summary', 'findings'],
  properties: {
    skill: { type: 'string' },
    summary: { type: 'string', description: 'one-line headline verdict' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'severity', 'file', 'description', 'suggestedFix', 'confidence'],
        properties: {
          title: { type: 'string', description: 'short finding title' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'nit', 'info'] },
          category: { type: 'string', description: 'e.g. correctness, security, performance, comment, quality, hookify-rule, architecture' },
          file: { type: 'string' },
          lines: { type: 'string', description: 'line(s) or range, e.g. L40-45' },
          rule: { type: 'string', description: 'the rule id this maps to (R1, over-complex, never-return-secrets, block-findunique-multitenant, etc.) if applicable' },
          description: { type: 'string', description: 'what is wrong and why it matters' },
          suggestedFix: { type: 'string', description: 'concrete fix' },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
      },
    },
    skipped: { type: 'array', items: { type: 'string' } },
  },
}

const SCOPE = FILES.length
  ? `Scope — exactly these changed files:\n${FILES.map(f => '  - ' + f).join('\n')}`
  : `Scope — every file changed on branch ${BRANCH} vs ${BASE}, INCLUDING uncommitted/untracked work (a feature branch's changes are often not committed yet). Derive the file list yourself with:\n  { git diff --name-only ${BASE}; git ls-files --others --exclude-standard; } | sort -u`

const COMMON = `
You are reviewing the current git branch diff (branch ${BRANCH}) against ${BASE}.
Run all commands from the repo root ${REPO_ROOT}.

${SCOPE}

How to get the diff (use TWO-dot ${BASE}..working-tree, NOT triple-dot — triple-dot shows only committed work and is empty when the branch's changes are still uncommitted; do NOT use 'git merge-base' — a repo hook blocks any command containing the word "merge"):
  git diff ${BASE} -- <file>
New/untracked files won't appear in any diff — Read them in full. Read the FULL changed files too (not just hunks) for context with the Read tool.

Only flag issues in code this change ADDED or MODIFIED (the + lines / structure the change introduced or worsened). Pre-existing untouched issues may be noted separately as low/info "boy-scout" only. Do NOT invent findings to look thorough — if a dimension is clean, return an empty or near-empty findings array and say so in summary. Return STRICT structured output via the provided schema.

When you set 'lines' for a finding, give the ACTUAL line numbers in the current file (e.g. L824-825 or L262), not 0 — the formatter relies on them to capture the existing code. If you genuinely cannot pin a line, omit lines.
`

// AGENTS-NOTE: skill definitions are located by glob at runtime (project copy or plugin-cache copy) so this
// workflow does not rot when plugin versions bump — never hardcode versioned plugin-cache paths here.
const PROMPTS = {
  'code-review-excellence': `${COMMON}
Apply the "code-review-excellence" methodology. Locate and read its full definition first:
  find ${REPO_ROOT}/.claude/skills ~/.claude/skills ~/.claude/plugins/cache -path '*code-review-excellence/SKILL.md' 2>/dev/null | head -1
Review the diff for: logic correctness & edge cases, security vulnerabilities, performance implications (N+1, needless async serialization, unnecessary work), error handling, test coverage/quality, API design, and architectural fit. Pay special attention to behavior changes, empty/null/undefined handling, and data-correctness regressions. Use severity critical/high/medium/low/nit. Set category to one of correctness/security/performance/error-handling/testing/architecture/api-design.`,

  'comment-review': `${COMMON}
Apply the "comment-review" methodology EXACTLY. Locate and read its full rule set first:
  find ~/.claude/plugins/cache ${REPO_ROOT}/.claude/skills ~/.claude/skills -path '*comment-review/SKILL.md' 2>/dev/null | head -1
Review COMMENT QUALITY ONLY (in all changed files incl. *.spec.ts) — not logic/naming/structure. Apply the deletion test and the rules R1-R11. For every problematic comment emit a finding: rule = the R-number, category = "comment", title = verdict (mostly REMOVE / REWRITE; KEEP-issue is rare), description = the verbatim quoted comment + one-line reason, suggestedFix = exact replacement text or "delete these lines" or the proposed missing-WHY comment. Map verdict to severity: R9 (contradicts code) = high; REMOVE/REWRITE of misleading or coupling comments = medium; pure noise/banner/narration removal = nit. List R9 findings first. Only flag added/modified comment lines (and comments whose code changed).`,

  'quality-review': `${COMMON}
Apply the "quality-review" methodology EXACTLY. Locate and read its full definition first:
  find ~/.claude/plugins/cache ${REPO_ROOT}/.claude/skills ~/.claude/skills -path '*quality-review/SKILL.md' 2>/dev/null | head -1
First read the project CLAUDE.md/AGENTS.md conventions (Step 0). Review code quality/craft ONLY — readability, vertical structure, ordering, style-mix, barrels, needless casts, over-complexity/duplication. Do NOT review correctness/security/performance/naming. Use ONLY these rule names verbatim as the 'rule' field: openness, test-structure, ordering, style-mix, barrel, needless-cast, over-complex. category = "quality". Severity high/medium/nit per the skill's mapping (over-complex/style-mix/needless-cast = high; ordering/test-structure/barrel = medium; openness = nit). Spend the most effort on over-complex (collapsible duplication). For needless-cast, verify against current types; if unverifiable mark confidence=low.`,

  'self-code-review-checklist': `${COMMON}
Apply the "self-code-review-checklist" methodology EXACTLY. Locate and read its full definition first:
  find ${REPO_ROOT}/.claude/skills ~/.claude/skills ~/.claude/plugins/cache -path '*self-code-review-checklist/SKILL.md' 2>/dev/null | head -1
If ${REPO_ROOT}/.claude/code-review-rules/ exists, read the relevant rule docs there. Check the diff against the conceptual rules (extract-duplicate-calculations, record-string-any-return, prefer-sfui-components [frontend only], export-config-pattern, config-injection-pattern, register-configs-core-module, activity-log-userid-handling, parallel-promise-execution, updatemany-over-promise-all, context-building-optimization, dynamic-imports-env-code, never-return-secrets). Route by file type: *.service.ts → performance rules; *.module.ts → register-configs-core-module; all *.ts → code-quality rules. rule = the rule name. category = code-quality/architecture/performance/security/testing. Use the rule's own severity (never-return-secrets=critical; record-string-any-return/parallel-promise-execution/updatemany-over-promise-all/activity-log-userid-handling/dynamic-imports-env-code=high; rest=medium). Explain WHY each is a real violation in context, not just a pattern match.`,

  'hookify-review-changes': `${COMMON}
Apply the "hookify review-changes" (reviewing-hookify-compliance) methodology. The RULE SET IS THE ONLY AUTHORITY — do NOT add general code-quality/security comments; only evaluate ENABLED file-event hookify rules against ADDED (+) lines.

Discover the enabled rules yourself (do not assume a fixed list):
  ls ${REPO_ROOT}/.claude/hookify.*.md
Read each rule file's frontmatter/body to learn its event type, file-path glob, and regex. Apply only file-event (PreToolUse on Write/Edit) rules whose path glob matches a changed file, and test the rule's regex against the added lines. For each violation: rule = rule name, category = "hookify-rule", file/lines = the + line, description = which rule + why it fires, suggestedFix = concrete remedy. In summary, also state which loaded rules were checked and CLEAN. Severity: BLOCK rules = high, WARN rules = low/medium.`,
}

phase('Review')

const results = await parallel(
  Object.entries(PROMPTS).map(([skill, prompt]) => () =>
    agent(prompt, { label: `review:${skill}`, phase: 'Review', schema: SCHEMA })
      .then(r => r ? { ...r, skill } : { skill, summary: 'agent failed', findings: [], failed: true })
  )
)

const perSkill = results.filter(Boolean)

// Flatten every finding, tagging each with the dimension that raised it, so the formatter can both render
// provenance and collapse cross-skill duplicates (two skills hitting the same file+line = one OCR comment).
const flatFindings = perSkill.flatMap(r =>
  (r.findings || []).map(f => ({ ...f, skill: r.skill }))
)

phase('Format')

// OpenCodeReview comment shape (https://alibaba.github.io/open-code-review/). start_line/end_line are
// integers; 0/0 is OCR's own convention for "no precise line" (it appears verbatim in real OCR output).
const OCR_SCHEMA = {
  type: 'object',
  required: ['comments'],
  properties: {
    comments: {
      type: 'array',
      items: {
        type: 'object',
        required: ['path', 'content', 'existing_code', 'start_line', 'end_line'],
        properties: {
          path: { type: 'string', description: 'file path relative to repo root, exactly as in the finding' },
          content: { type: 'string', description: 'the review comment as markdown prose — issue + why it matters + recommended action. NO code here; code goes in the *_code fields.' },
          suggestion_code: { type: 'string', description: 'proposed replacement code, if the fix is code. Omit if the fix is prose-only.' },
          existing_code: { type: 'string', description: 'the current code at start_line..end_line, copied VERBATIM from the file. Empty string only if there is genuinely no code to anchor to.' },
          start_line: { type: 'integer' },
          end_line: { type: 'integer' },
        },
      },
    },
  },
}

let comments = []
if (flatFindings.length) {
  const formatPrompt = `You convert multi-skill code-review findings into OpenCodeReview's JSON comment format.

Repo root: ${REPO_ROOT}

Here are the raw findings from 5 parallel review dimensions (each tagged with its 'skill'):
${JSON.stringify(flatFindings, null, 2)}

Produce one OpenCodeReview comment per DISTINCT issue, following these rules EXACTLY:

1. DEDUP: collapse findings that target the same file and the same (or overlapping) lines into ONE comment. When multiple skills agreed, that is a strong signal — keep the clearest description and mention the agreement in the provenance suffix (below). Do NOT emit two comments for one underlying issue.

2. existing_code: for each comment, Read the actual file at ${REPO_ROOT}/<path> around the finding's lines and copy the relevant current code VERBATIM into existing_code. Read the full file if the finding gives no usable line (new/untracked files included). If you truly cannot anchor to code, set existing_code to "" and start_line/end_line to 0.

3. start_line / end_line: parse from the finding's 'lines' (e.g. "L824-825" -> 824/825, "L262" -> 262/262). If absent or unparseable, use 0/0 (this is a valid OCR convention).

4. suggestion_code: if the fix is code, put the replacement code here. If the fix is prose-only (e.g. "verify the path against staging"), omit suggestion_code.

5. content: write a clean review comment in markdown — lead with the problem, explain why it matters, end with the recommended action IN WORDS. Do NOT put code blocks in content (code lives in existing_code/suggestion_code). End every content with a one-line provenance suffix on its own line, in this exact shape:
   _(multi-skill-review · severity=<highest severity among merged findings> · dimensions=<comma-joined skill names that raised it>)_

6. path: copy the finding's file path verbatim (relative to repo root).

Order comments by severity (critical, high, medium, low, nit, info), highest first. Return strictly via the schema.`

  const formatted = await agent(formatPrompt, { label: 'format:opencodereview', phase: 'Format', schema: OCR_SCHEMA })
  comments = (formatted && Array.isArray(formatted.comments)) ? formatted.comments : []
}

// output_tokens is the only token figure measurable in-script; the driving skill stamps elapsed and notes
// that input/total/cache counts are not exposed for this multi-agent harness.
const outputTokens = budget.spent() - startSpent

return {
  status: 'success',
  summary: {
    files_reviewed: FILES.length,
    comments: comments.length,
    output_tokens: outputTokens,
    note: 'output_tokens = workflow budget delta (5 parallel reviewers + 1 formatter). input/total/cache token counts are not exposed to the multi-agent harness, so token totals are NOT 1:1 comparable to OpenCodeReview single-pass. elapsed is stamped by the driving skill as wall-clock.',
  },
  comments,
  perSkill: perSkill.map(r => ({ skill: r.skill, summary: r.summary, findingCount: (r.findings || []).length, failed: !!r.failed })),
}
