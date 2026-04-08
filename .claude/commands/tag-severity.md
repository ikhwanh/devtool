Run this Ruby snippet inside the Rails app to get all untagged Rollbar items:

```
bin/rails runner "puts RollbarItem.where(severity: nil).to_json"
```

Tag each item with a severity level using these criteria:
- **high**: Unhandled exceptions, 5xx errors, payment/auth/session failures, data corruption, crashes in core user flows, high occurrence count with broad user impact
- **medium**: Handled exceptions with user-visible impact, 4xx errors in key flows, repeated warnings, moderate occurrence count
- **low**: Minor UI/edge-case errors, infrequent occurrences, low-impact warnings, debug-level items

For each item, update its severity in the database using:

```
bin/rails runner "RollbarItem.find(<id>).update!(severity: '<high|medium|low>')"
```

After updating all items, run this to display a summary table with columns: #, Severity, Title (truncated to 70 chars), Occurrences, Last Seen. Sort by severity (high → medium → low), then by total_occurrences descending within each group:

```
bin/rails runner "
  items = RollbarItem.where.not(severity: nil).order(Arel.sql(\"CASE severity WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END, total_occurrences DESC\"))
  puts ['#', 'Severity', 'Title', 'Occurrences', 'Last Seen'].join(' | ')
  items.each_with_index do |item, i|
    puts [i+1, item.severity, item.title.truncate(70), item.total_occurrences, item.last_occurrence_at&.strftime('%Y-%m-%d')].join(' | ')
  end
"
```
