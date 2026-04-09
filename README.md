# devtool

A CLI tool that fetches Rollbar errors, tags severity via Claude, and creates GitHub issues automatically.

## Prerequisites

- Ruby (see `.ruby-version`)
- `bundle install`

## Commands

### `config` — Manage project configuration

```sh
# Add or update a project
bin/devtool config --project myapp \
  --rollbar-token TOKEN \
  --rollbar-account my-org \
  --github-token TOKEN \
  --github-repo owner/repo \
  --local-repository /path/to/repo \
  --default

# List all configured projects
bin/devtool config

# Show a specific project
bin/devtool config --project myapp

# Remove a single key
bin/devtool config --project myapp --unset rollbar_token

# Delete a project
bin/devtool config --project myapp --delete
```

### `rollbar analyze` — Fetch, tag, and select Rollbar items

Fetches recent Rollbar items, uses Claude to tag severity, then prompts you to select items for issue creation.

```sh
bin/devtool rollbar analyze
```

Options:

| Flag | Default | Description |
|------|---------|-------------|
| `--days-ago N` | `7` | Fetch items from the last N days |
| `--severity high\|medium\|low` | — | Auto-select only items of this severity |
| `--autoselect` | `false` | Select all items without an interactive prompt |
| `--rollbar-token TOKEN` | config | Override the Rollbar API token |
| `-c, --config PROJECT` | default | Use a specific project config |

### `rollbar list` — List stored Rollbar items

```sh
bin/devtool rollbar list
bin/devtool rollbar list --severity high --limit 20
```

Options: `--severity`, `--selected`, `--env`, `--limit` (default 50).

### `issues create` — Generate and create GitHub issues

Generates issue content via Claude for all selected Rollbar items, then creates the issues on GitHub.

```sh
bin/devtool issues create
bin/devtool issues create --skip-generate   # skip Claude step, create immediately
```

Options:

| Flag | Description |
|------|-------------|
| `--github-repo owner/repo` | Override GitHub repo |
| `--github-token TOKEN` | Override GitHub token |
| `--local-repository PATH` | Local repo path for source-context enrichment |
| `--skip-generate` | Skip Claude generation, create issues from existing data |
| `-c, --config PROJECT` | Use a specific project config |

## Typical workflow

```sh
# 1. Configure a project (one-time)
bin/devtool config --project myapp \
  --rollbar-token ... --rollbar-account my-org \
  --github-token ... --github-repo owner/repo \
  --default

# 2. Fetch and triage Rollbar errors
bin/devtool rollbar analyze --severity high --days-ago 1 --autoselect

# 3. Create GitHub issues for selected items
bin/devtool issues create
```

## Scheduling with whenever

`config/schedule.rb` defines a cron job that runs steps 2 and 3 automatically every 2 hours.

**Install the crontab:**

```sh
bundle exec whenever --update-crontab
```

**Remove the crontab:**

```sh
bundle exec whenever --clear-crontab
```

**View the generated cron entries:**

```sh
bundle exec whenever
```

Logs are written to `log/cron.log`.

To change the schedule, edit [config/schedule.rb](config/schedule.rb).
