# devtool

A CLI tool that automates developer workflows by integrating GitHub and Rollbar. It fetches pull requests and error items, uses Claude AI for code review and issue generation, and runs on a schedule via the `whenever` gem.

## Setup

```sh
bundle install
bin/rails db:setup
cp .env.example .env  # fill in required environment variables
```

## Configuration

Manage project configurations with the `config` command. Each project stores GitHub and Rollbar credentials.

```sh
# Add or update a project
bin/devtool config --project myapp \
  --github-repo owner/repo \
  --github-token ghp_... \
  --rollbar-token ... \
  --rollbar-account myorg \
  --local-repository /path/to/local/repo \
  --default

# List all configured projects
bin/devtool config

# Remove a project
bin/devtool config --project myapp --delete

# Unset a single key
bin/devtool config --project myapp --unset github-token
```

All commands accept `--config PROJECT` to target a specific project. The `--default` flag marks a project as the default so `--config` can be omitted.

## Common Workflow

```sh
bin/devtool sync   # fetch latest PRs and Rollbar items across all projects
bin/devtool work   # review PRs with Claude and create GitHub issues from Rollbar
```

Run `sync` first to pull in fresh data, then `work` to process it. `work` calls `sync` again at the end to update the pending summary. This pair is also what the hourly cron job runs automatically.

## Commands

### sync

Fetch the latest PRs and Rollbar items for all projects and write a pending summary to `tmp/devtool_pending`.

```sh
bin/devtool sync
```

### work

Review pending PRs via Claude and create GitHub issues from Rollbar items for all projects.

```sh
bin/devtool work
```

### pr

```sh
# Fetch open PRs (default: last 7 days)
bin/devtool pr fetch
bin/devtool pr fetch --days-ago 14
bin/devtool pr fetch --id 123 --force

# Review PRs with Claude and post comments to GitHub
bin/devtool pr review
bin/devtool pr review --id 123
bin/devtool pr review --skip-post   # generate review without posting
bin/devtool pr review --force       # re-review already-reviewed PRs
```

### rollbar

```sh
# Fetch Rollbar items (default: last 7 days)
bin/devtool rollbar fetch
bin/devtool rollbar fetch --days-ago 14

# List stored items
bin/devtool rollbar list
bin/devtool rollbar list -s high -e production -n 20
```

Severity levels: `high`, `medium`, `low`.

### issues

```sh
# Generate GitHub issues from Rollbar items
bin/devtool issues create
bin/devtool issues create --autoselect          # skip interactive selection
bin/devtool issues create --skip-generate       # create without AI generation
bin/devtool issues create -s high               # filter by severity
bin/devtool issues create --local-repository /path/to/repo

# Resolve Rollbar items whose linked GitHub issues are closed
bin/devtool issues resolve
bin/devtool issues resolve --dry-run
```

## Claude Skills

Project-level Claude slash commands live in [.claude/commands/](.claude/commands/). Some skills are generic enough to be useful globally across all projects.

### Installing skills globally

Copy selected skills to `~/.claude/commands/` so they are available in every Claude Code session:

```sh
bin/devtool install-skills          # installs the default set (qa)
bin/devtool install-skills qa       # install a specific skill
bin/devtool install-skills qa foo   # install multiple skills
```

### Available skills

| Skill | Description |
|-------|-------------|
| `qa` | End-to-end QA: login, crawl all pages, inspect for bugs, or walk a named flow |

## Scheduling with whenever

The `whenever` gem manages cron jobs. The default schedule (`config/schedule.rb`) runs `sync` and `work` every hour.

```sh
# Install crontab entries
bundle exec whenever --update-crontab

# Remove crontab entries
bundle exec whenever --clear-crontab

# Preview what would be written to crontab
bundle exec whenever
```

Cron output is logged to `log/cron.log`.

### schedule.rb

```ruby
every 1.hour do
  command 'bin/devtool sync'
  command 'bin/devtool work'
end
```

### MOTD (terminal summary on shell start)

`config/motd.rb` schedules only `sync` to run hourly, writing a pending summary to `tmp/devtool_pending`. To display it on every new terminal session, run:

```sh
bin/install-motd
```

Then install the cron job:

```sh
bundle exec whenever --load-file config/motd.rb --update-crontab

# To remove
bundle exec whenever --load-file config/motd.rb --clear-crontab
```
