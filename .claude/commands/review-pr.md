Run this Ruby snippet to get all PRs queued for review:

```
bin/rails runner "puts PrReview.pending_review.to_json"
```

The first argument ($ARGUMENTS) is an optional path to a local repository. If provided, use it to read relevant source files for additional context about conventions and patterns.

For each PR in the result:

1. **Understand the change**
   - Read `pr_title` and `pr_body` for intent
   - Parse `diff_json` (JSON array of `{ filename, status, patch }`) to see every changed file

2. **Read local source context** (only if a local repository path was provided)
   - For each changed file, try to read the full file from the local repository path
   - Also look for related files (tests, parent classes, config) that provide pattern/convention context
   - Limit to 10 files, truncate each to ~200 lines if large

3. **Analyse the change thoroughly** using these criteria before writing the review:

   **Correctness & safety**
   - Business logic correctness and edge cases
   - Null-safety: flag any unsafe nil handling or null/undefined risks
   - Security implications (auth, permissions, injection, exposure)
   - Data integrity risks and transaction safety
   - Idempotency: flag logic that is not idempotent, can cause duplicate side effects, is not safe for retry, or depends on non-deterministic ordering

   **Performance**
   - N+1 queries
   - Performance-sensitive paths

   **Numeric & formula logic** — for any numeric calculation, re-evaluate it step-by-step:
   - Arithmetic correctness
   - Percentage vs decimal mistakes (e.g. `5` vs `0.05`)
   - Rounding consistency
   - Division-by-zero risks
   - Aggregation correctness (sum, avg, weighted avg)
   - Duplicated multipliers
   - Currency and unit consistency

   **Rails best practices**
   - Fat models, thin controllers — no business logic inside controllers
   - Use service objects for complex workflows
   - Prefer scopes over manual query building

   **Testing**
   - Suggest missing unit tests and edge case tests
   - Highlight untested branches
   - Flag logic that is hard to test

   **Staging requirement** — flag the PR as requiring staging validation if the change affects any of: user-facing flows, payments/reservations, background jobs, data migrations, external integrations, permissions/auth, performance-sensitive paths, or feature flags/rollouts. Explain why.

   **Typos** — check for typos in code, comments, and documentation.

4. **Produce the review in two parts:**

   **Part A — Inline comments** for every specific issue or suggestion that can be tied to a line of code.

   To determine the correct line number, parse the diff patch for each file:
   - Each hunk header looks like `@@ -old_start,old_count +new_start,new_count @@`
   - `new_start` is the line number in the new file where that hunk begins
   - Count downward through the hunk lines (skip lines starting with `-`, count context lines and `+` lines) to find the exact line number for each changed or context line you want to comment on
   - Only comment on lines present in the new version of the file (i.e. context lines or `+` lines, never `-` lines)

   Each inline comment must include:
   - `path` — the file path (from `filename` in diff_json)
   - `line` — the line number in the new version of the file
   - `side` — always `"RIGHT"`
   - `body` — concise markdown comment; prefix with `[critical]`, `[major]`, or `[minor]` for issues; no prefix for suggestions or positives

   **Part B — Overall summary** in markdown covering:
   - `## Summary` — one paragraph on what the PR does and why
   - `## Staging Required` — yes/no and reason; omit section if not required
   - `## Positives` — what is done well
   - `## Verdict` — one of: **Approve**, **Approve with minor suggestions**, **Request changes**

   Issues and suggestions that are tied to specific lines should appear as inline comments only, not repeated in the summary.

5. **Save the review** using:

```
bin/rails runner "PrReview.find(<id>).update!(review_body: '<escaped summary>', comments_json: '<escaped comments JSON>')"
```

   - `<escaped summary>` — the Part B markdown, with single quotes escaped as `'\''`
   - `<escaped comments JSON>` — a JSON array of `{ path, line, side, body }` objects, with single quotes escaped as `'\''`
   - If there are no inline comments, pass `comments_json: '[]'`

After all reviews are written, print a summary:

```
bin/rails runner "PrReview.pending_submission.each { |r| puts \"PR ##{r.pr_number} — #{r.pr_title}\" }"
```
