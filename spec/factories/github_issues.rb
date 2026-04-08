# frozen_string_literal: true

FactoryBot.define do
  factory :github_issue do
    rollbar_item
    title { '[HIGH] Error in payment flow' }
    body { "## Description\nSomething went wrong." }
    labels { ['bug', 'rollbar', 'severity:high'].to_json }
    github_issue_url { nil }
    github_issue_number { nil }
    submitted_at { nil }
  end
end
