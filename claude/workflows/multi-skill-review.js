export const meta = {
  name: 'multi-skill-review',
  description: 'Run 5 specialized code-review skills in parallel over a set of changed files and return structured findings',
  phases: [{ title: 'Review', detail: 'one agent per review skill, in parallel' }],
}

// args (supplied by the /multi-skill-review skill):
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

return { base: BASE, branch: BRANCH, reviewedFiles: FILES, results: results.filter(Boolean) }
