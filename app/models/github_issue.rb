# frozen_string_literal: true

class GithubIssue < ApplicationRecord
  belongs_to :rollbar_item

  validates :title, presence: true

  scope :for_config,         ->(c) { c ? where(config: c) : all }
  scope :pending_submission, -> { where(github_issue_url: nil) }
  scope :submitted,          -> { where.not(github_issue_url: nil) }
  scope :older_than,         ->(duration) { where(submitted_at: ...(Time.current - duration)) }

  def labels
    raw = self[:labels]
    return [] if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    []
  end

  def labels=(value)
    self[:labels] = if value.nil?
                      nil
                    else
                      (value.is_a?(String) ? value : value.to_json)
                    end
  end

  def submitted?
    github_issue_url.present?
  end
end
