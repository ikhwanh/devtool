# frozen_string_literal: true

FactoryBot.define do
  factory :rollbar_item do
    sequence(:rollbar_id) { |n| n }
    title { 'Error in payment flow' }
    environment { 'production' }
    severity { 'high' }
    total_occurrences { 42 }
    last_occurrence_at { 2.days.ago }
    selected { false }
    occurrence_data { nil }
  end
end
