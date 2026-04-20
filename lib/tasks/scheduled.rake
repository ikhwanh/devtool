# frozen_string_literal: true

namespace :scheduled do
  desc 'For every project: fetch open PRs and run pr review if any are new'
  task pr_review_all: :environment do
    Config.all.group_by(&:project).each_key do |project_name|
      cfg          = Config.project_config(project_name)
      github_repo  = cfg['github_repo']
      github_token = cfg['github_token'] || ENV['GITHUB_TOKEN']

      unless github_repo
        puts "[#{project_name}] Skipping PR review — no github_repo configured"
        next
      end

      result = FetchPullRequests.new(github_repo: github_repo, github_token: github_token, config: project_name).call

      if result[:changed]
        system("bin/devtool pr review --config #{Shellwords.escape(project_name)}")
      else
        puts "[#{project_name}] No new PRs"
      end
    end
  end

  desc 'Fetch PRs + Rollbar for all projects and write tmp/devtool_pending for terminal display'
  task fetch_summary: :environment do
    pending_file = Rails.root.join('tmp/devtool_pending')
    pr_lines     = []
    rollbar_lines = []

    Config.all.group_by(&:project).each_key do |project_name|
      cfg           = Config.project_config(project_name)
      github_repo   = cfg['github_repo']
      github_token  = cfg['github_token'] || ENV['GITHUB_TOKEN']
      rollbar_token = cfg['rollbar_token']

      if github_repo && github_token.present?
        FetchPullRequests.new(github_repo: github_repo, github_token: github_token, config: project_name).call
        count = PrReview.for_config(project_name).pending_review.count
        pr_lines << "  #{project_name}: #{count} PR(s)" if count.positive?
      end

      if rollbar_token.present?
        FetchRollbar.new(token: rollbar_token, config: project_name).call
        count = RollbarItem.for_config(project_name).unselected.count
        rollbar_lines << "  #{project_name}: #{count} item(s)" if count.positive?
      end
    end

    if pr_lines.empty? && rollbar_lines.empty?
      File.delete(pending_file) if File.exist?(pending_file)
    else
      lines = ["[devtool #{Time.current.strftime('%b %d %H:%M')}]"]
      lines << "PRs pending review:" if pr_lines.any?
      lines.concat(pr_lines)
      lines << "Rollbar items:" if rollbar_lines.any?
      lines.concat(rollbar_lines)
      File.write(pending_file, "#{lines.join("\n")}\n")
    end
  end

  desc 'For every project: fetch Rollbar items and run issues create if any are new'
  task rollbar_issues_all: :environment do
    Config.all.group_by(&:project).each_key do |project_name|
      cfg           = Config.project_config(project_name)
      rollbar_token = cfg['rollbar_token']

      unless rollbar_token
        puts "[#{project_name}] Skipping Rollbar fetch — no rollbar_token configured"
        next
      end

      result = FetchRollbar.new(token: rollbar_token, config: project_name).call

      if result[:changed]
        system("bin/devtool issues create --config #{Shellwords.escape(project_name)} --autoselect")
      else
        puts "[#{project_name}] No new Rollbar items"
      end
    end
  end
end
