# frozen_string_literal: true

class Config < ApplicationRecord
  validates :project, presence: true
  validates :key, presence: true, uniqueness: { scope: :project }

  KEYS = %w[rollbar_token rollbar_account github_token github_repo local_repository].freeze

  scope :for_project, ->(project) { where(project: project) }
  scope :defaults, -> { where(is_default: true) }

  # Returns the name of the default project, or nil.
  def self.default_project
    defaults.first&.project
  end

  # Returns a hash of { key => value } for the given project.
  def self.project_config(project_name)
    for_project(project_name).each_with_object({}) do |row, hash|
      hash[row.key] = row.value
    end
  end

  # Insert or update config rows for a project.
  # Pass set_default: true to mark this project as the default.
  def self.upsert_project(project:, set_default: false, **keys)
    transaction do
      where(is_default: true).update_all(is_default: false) if set_default

      keys.each do |key, value|
        next if value.nil?

        record = find_or_initialize_by(project: project, key: key.to_s)
        record.value = value
        record.save!
      end

      where(project: project).update_all(is_default: true) if set_default
    end
  end

  # Delete all config rows for a project.
  def self.delete_project(project)
    where(project: project).destroy_all
  end

  # Remove a single key from a project's config.
  # Returns true if the key existed, false otherwise.
  def self.delete_key(project, key)
    record = find_by(project: project, key: key.to_s)
    return false unless record

    record.destroy!
    true
  end
end
