The first argument ($ARGUMENTS) is the project config name (e.g. `hotelzero-web`).

## Step 1: Tag untagged items with severity

Run this to get all untagged Rollbar items for this config:

```
bin/rails runner "puts RollbarItem.where(severity: nil).for_config('$ARGUMENTS').to_json"
```

Tag each item with a severity level using these criteria:
- **high**: Unhandled exceptions, 5xx errors, payment/auth/session failures, data corruption, crashes in core user flows, high occurrence count with broad user impact
- **medium**: Handled exceptions with user-visible impact, 4xx errors in key flows, repeated warnings, moderate occurrence count
- **low**: Minor UI/edge-case errors, infrequent occurrences, low-impact warnings, debug-level items

For each item, update its severity:

```
bin/rails runner "RollbarItem.find(<id>).update!(severity: '<high|medium|low>')"
```

## Step 2: Generate issues

Run this Ruby snippet to get the selected Rollbar items that don't already have a GitHub issue:

```
bin/rails runner "
  items = RollbarItem.for_config('$ARGUMENTS').selected.reject(&:submitted_to_github?).map do |item|
    item.as_json.merge(
      rollbar_url: \"https://app.rollbar.com/a/#{item.project}/fix/item/#{item.project}/#{item.rollbar_counter}\"
    )
  end
  puts items.to_json
"
```

Run `bin/rails runner "puts Config.project_config('$ARGUMENTS')['local_repository']"` — if it returns a path, use it to find source files mentioned in stack traces for deeper fix suggestions.

For each item:

1. **Find relevant source files** (only if `cfg['local_repository']` is set):
   - Parse file paths from the stack trace in `occurrence_data` (look for patterns like `(src/foo/bar.rb:42)`)
   - Try to find those files relative to the local repository path
   - Read up to 5 files, truncate each to ~150 lines if large

2. **Generate a GitHub issue** for each item containing:
   - **Title**: `[HIGH/MEDIUM/LOW] concise description`
   - **Body** (markdown):
     - `## Description` — what the error is and why it matters
     - `## Error Details` — level, environment, occurrence count, last seen, and a link to the Rollbar item (use the `rollbar_url` field from the data)
     - `## Stack Trace` — formatted, inside a code block
     - `## Root Cause Analysis` — likely cause based on error message, stack trace, and any source code context
     - `## Suggested Fix` — concrete steps or code changes to resolve it
     - `## Impact` — who and what is affected

3. **Create a GithubIssue record** for each item using:

```
bin/rails runner "
  GithubIssue.create!(
    rollbar_item: RollbarItem.find_by(rollbar_id: <rollbar_id>),
    config: '$ARGUMENTS',
    title: '<title>',
    body: '<markdown body>',
    labels: ['bug', 'rollbar', 'severity:<severity>'].to_json
  )
"
```

Do not create a new GithubIssue for any RollbarItem that already has one with a `github_issue_url` set.

After writing all issues, run this to list each generated issue title:

```
bin/rails runner "GithubIssue.for_config('$ARGUMENTS').pending_submission.each { |i| puts i.title }"
```
