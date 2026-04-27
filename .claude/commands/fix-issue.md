The first argument ($ARGUMENTS) is either a GitHub issue number (e.g. `42`) or `all` to fix every open issue.

## Step 1: Load the issue(s)

If `$ARGUMENTS` is `all`:

```
gh issue list --state open --json number,title,body,labels,comments
```

Process each issue in the list sequentially using Steps 2–6 below, then print a combined report at the end.

Otherwise, load the single issue:

```
gh issue view $ARGUMENTS --json number,title,body,labels,comments
```

---

For each issue, run Steps 2–6:

## Step 2: Understand the issue

From the issue title, body, and comments extract:
- **Error message** and exception class
- **Stack trace** — parse file paths and line numbers
- **Steps to reproduce** if described

## Step 3: Read relevant source files

Using the stack trace file paths or the issue description, locate and read the relevant source files in the current repository. Focus on:
- The file and line where the exception was raised
- Any callers one level up in the stack

If no stack trace is available, grep for the method name, class name, or error message string to locate the likely source.

## Step 4: Implement the fix

Make targeted, minimal changes — do not refactor unrelated code.

After editing Ruby files, run `bundle exec rubocop -A <changed_files>`.

## Step 5: Commit

Stage all changed files and commit:

```
git add <changed files>
git commit -m "Resolve #<issue number>"
```

## Step 6: Report

Print a short summary of what was changed for this issue and any caveats (e.g. migration to run, deploy step required).
