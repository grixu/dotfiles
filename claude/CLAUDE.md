# Rules

## Package manager for JS/TS

- Always use `pnpm`, not `npm`
- Always use `pnpm dlx` instead of `npx`

## WebSearch and WebFetch

- DO NOT use WebFetch tool
- DO NOT use WebSearch tool
- Use firecrawl MCP to searching informations online and fetching the web pages

## Building plans, specs, ADRs

- ALWAYS confirm knowledge about frameworks, libraries, APIs and other tools in their official documentation using firecrawl or context7 MCP

## Doubts during implementation

- WHEN you are not 100% sure that creating solution/code/script is correct with language, framework or library that code you are using - check it via firecrawl or context7
- ALWAYS validate created code by checking the AC / ADR / Specification / Task description

## Code exploration (Codebase Memory MCP)

- For ANY code exploration in reach for `codebase-memory-mcp` FIRST:
  `search_graph`/`search_code` before native Grep/Glob or shell `grep`/`rg`/`find`;
  `trace_path` for call chains; `get_code_snippet` for exact source; `get_architecture`
  for structure.
- Relational questions go to the graph, not to a text pattern — a flat search
  reconstructs by hand what the graph already knows. Before you `search_code`/grep for a
  *relationship*: "who calls / where is X used" (about to search `X(` or `->X(`) →
  `trace_path(X, mode=callers)`; "what X calls / depends on" → `trace_path(X, mode=calls)`;
  "the class/interface/enum/def or its subtypes" (searching `class X`/`extends`/`implements`)
  → `search_graph(name_pattern/label)`; "who imports X" (searching `from '…'`/`import X`) →
  `trace_path`/`query_graph`. `search_code` stays right for literal text, log/config
  strings, and wide multi-term sweeps.
- `Read` stays the right tool for a known file (always before editing) and for
  configs/non-code. Do not route those through the graph.
- Indexing is automatic (`auto_index` on) — a fresh repo is indexed on first connection.
  If `search_graph` returns nothing, check `index_status`; if results look stale after
  big changes, run `detect_changes`.

## Comments

Default: code is read, not narrated. Write a comment only when it carries a *why* the
code cannot — a constraint, trade-off, gotcha, or ordering rule. When unsure, leave it
out; no comment beats one that restates the code.

A good comment:
- **Explains a decision, not mechanics.** Say *why* the code is this way — the
  constraint, the trade-off, the reason behind an odd value or a workaround. Skip it on
  obvious code and textbook patterns (a plain getter, a standard map/filter); a why
  there is just noise.
  `// sequential — the upstream rate-limits per source IP`  ✅
  `// loop over users and add up their counts`  ❌ (the code already says this)
- **Stays short.** One load-bearing sentence. If it runs longer than the code it
  annotates, cut it to the single fact that matters.
- **Stands alone.** Inline the fact; never send the reader to another file, an internal
  doc, or a spec/ticket slot (`see handler.ts`, `per DD_PLAN §4.1`, `F1:`). Stable
  external pins are fine — an RFC/CVE number, a URL pinned to a version.
- **Lives where the behavior lives.** Put the rationale on the code that performs the
  behavior, not on a distant declaration. A note about a value's own meaning
  (`// 0 means unbounded, not disabled`) stays on the value.

Do not write:
- **Narration of what the code does** — at any level of abstraction; a domain-flavored
  restatement is still a restatement.
- **Process narration dressed as rationale** — re-describing how a value is built
  (`// take the first 10, sorted by date` above code that slices 10 and sorts by date).
  If it has value, express it where the value is produced, in the code.
- **Change history** — what changed, the prior behavior, PR/ticket breadcrumbs
  (`previously…`, `was X, now Y`, `fixed in PROJ-123`). That lives in git. A still-live
  constraint that happens to cite a ticket is fine.
- **Banner / section dividers** (`// ===== PERFORMANCE =====`). Functions and file
  layout already provide structure.
- **Commented-out code.** Delete it; git remembers.
- **Relations to other docs** like 'spec §7' or 'ADR §2.1'

Keep the comment despite the above when: a genuinely complex algorithm (non-trivial
math, a tricky state machine, bit-twiddling) needs a brief *what* to be graspable; or a
process-narration comment is critical to correctness, security-relevant, or genuinely
intricate — then keep it, tightened to the load-bearing point.

## Language

- Conversation: mirror the user's language (usually Polish)
- ALL artifacts in English: code, comments, commit messages, PR descriptions,
  CLAUDE.md files, tasks/tickets, release notes, docs

## Plan first

- For non-trivial work (new feature, refactor, multi-file change), present a plan
  before implementing — prefer plan mode
- Trivial fixes (typo, one-liner, obvious bug): just do it

## Scope discipline

- Implement exactly what was asked — nothing more
- DO NOT add scripts, guards, locks, or subagents that weren't requested
- DO NOT bump versions (packages, charts, API versions) unless explicitly asked
- Before writing a utility/primitive, check for an existing library or in-repo
  helper and use it (e.g. uuid v5 over a hand-rolled deterministic id)

## Commits & working files

- Commits are surgical: one logical change per commit; use `git commit --fixup`
  when amending earlier commits on the branch
- NEVER commit working files (PLAN.md, scratch notes, eval residue); delete them
  before finishing

## After compaction

- After a context compaction or session continuation, ALWAYS re-Read a file before
  editing it — your memory of its contents is stale
