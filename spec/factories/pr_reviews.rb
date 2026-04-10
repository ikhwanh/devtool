# frozen_string_literal: true

FactoryBot.define do
  factory :pr_review do
    github_repo { 'owner/repo' }
    sequence(:pr_number) { |n| n }
    pr_title { 'Fix payment flow' }
    pr_body  { 'This PR fixes the payment flow.' }
    sequence(:head_sha) { |n| "sha#{n}" }
    diff_json { [{ filename: 'app/models/payment.rb', status: 'modified', patch: '@@ -1 +1 @@' }].to_json }
    review_body  { nil }
    review_url   { nil }
    submitted_at { nil }

    trait :reviewed do
      review_body   { "## Summary\nLooks good." }
      comments_json { [{ path: 'app/models/payment.rb', line: 10, side: 'RIGHT', body: '[minor] Rename for clarity.' }].to_json }
    end

    trait :submitted do
      review_body  { "## Summary\nLooks good." }
      review_url   { 'https://github.com/owner/repo/pull/1#pullrequestreview-1' }
      submitted_at { Time.current }
    end
  end
end
