Read the digest data file at: $ARGUMENTS

The file is a JSON object where each key is a project name, and the value contains:
- `rollbar_items` — active Rollbar errors from the past day: id, title, environment, total_occurrences, last_occurrence_at
- `github_issues` — recently updated open GitHub issues: number, title, body, labels, url, created_at, updated_at
- `assigned_prs` — open pull requests where you are a requested reviewer: number, title, author, url, created_at

If a project has an `error` key, it means data fetching failed for that project — note it briefly.

Generate a concise daily digest in this structure:

---

# Daily Digest — <today's date>

## Summary
One or two sentences summarising the overall state across all projects (busy/quiet, any fires, PRs awaiting attention).

## <Project Name> (repeat per project)

### Rollbar
- If no items: "No new errors in the past day."
- Otherwise: bullet list grouped by environment (production first). Each bullet: error title, occurrence count, last seen time. Flag items with high occurrence counts (>100) with ⚠.

### GitHub Issues
- If no items: "No issues updated in the past day."
- Otherwise: bullet list. Each bullet: #number title (label tags if any). Keep it short — title only, no body.

### Assigned PRs
- If no items: "No PRs awaiting your review."
- Otherwise: bullet list. Each bullet: #number title by @author (opened date). Sort oldest first — those are most overdue.

---

Keep the digest scannable. No padding, no filler sentences. Use markdown formatting suitable for terminal output.
