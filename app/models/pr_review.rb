# frozen_string_literal: true

class PrReview < ApplicationRecord
  RETENTION_PERIOD = 30.days

  validates :github_repo, presence: true
  validates :pr_number,   presence: true
  validates :head_sha,    presence: true,
                          uniqueness: { scope: %i[github_repo pr_number] }

  scope :pending_review,     -> { where(review_body: nil) }
  scope :pending_submission, -> { where.not(review_body: nil).where(review_url: nil) }
  scope :submitted,          -> { where.not(review_url: nil) }
  scope :older_than,         ->(duration) { where(submitted_at: ...(Time.current - duration)) }
  scope :for_repo,           ->(repo) { where(github_repo: repo) }

  def self.already_reviewed?(repo:, pr_number:, head_sha:)
    exists?(github_repo: repo, pr_number: pr_number, head_sha: head_sha)
  end

  def diff_files
    return [] if diff_json.blank?

    JSON.parse(diff_json)
  rescue JSON::ParserError
    []
  end
end
