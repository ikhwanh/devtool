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

4. **Write a thorough code review** in markdown covering:
   - `## Summary` — one paragraph on what the PR does and why
   - `## Staging Required` — yes/no and reason; omit section if not required
   - `## Issues` — bugs, security concerns, logic errors; prefix each with `[critical]`, `[major]`, or `[minor]`; omit section if none
   - `## Suggestions` — code quality, readability, performance, testing gaps; omit section if none
   - `## Positives` — what is done well
   - `## Verdict` — one of: **Approve**, **Approve with minor suggestions**, **Request changes**

5. **Save the review** using:

```
bin/rails runner "PrReview.find(<id>).update!(review_body: '<escaped markdown review>')"
```

   Escape single quotes in the review body as `'\''` before inserting into the shell string.

After all reviews are written, print a summary:

```
bin/rails runner "PrReview.pending_submission.each { |r| puts \"PR ##{r.pr_number} — #{r.pr_title}\" }"
```
