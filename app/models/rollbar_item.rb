# frozen_string_literal: true

class RollbarItem < ApplicationRecord
  has_many :github_issues, dependent: :destroy

  SEVERITIES = %w[high medium low].freeze

  validates :rollbar_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true

  scope :for_config,    ->(c) { c ? where(config: c) : all }
  scope :selected,      -> { where(selected: true) }
  scope :unselected,    -> { where(selected: false) }
  scope :with_severity, ->(sev) { where(severity: sev) }
  scope :recent_first,  -> { order(last_occurrence_at: :desc) }
  scope :within_window, ->(cutoff) { where(last_occurrence_at: cutoff..) }

  def occurrence_data
    raw = self[:occurrence_data]
    return nil if raw.nil?

    JSON.parse(raw)
  rescue JSON::ParserError
    nil
  end

  def occurrence_data=(value)
    self[:occurrence_data] = value.is_a?(String) ? value : value.to_json
  end

  def submitted_to_github?
    github_issues.where.not(github_issue_url: nil).exists?
  end
end
