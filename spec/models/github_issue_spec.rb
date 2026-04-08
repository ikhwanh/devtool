# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GithubIssue, type: :model do
  describe 'validations' do
    it 'is valid with required fields' do
      issue = build(:github_issue)
      expect(issue).to be_valid
    end

    it 'requires title' do
      issue = build(:github_issue, title: nil)
      expect(issue).not_to be_valid
    end

    it 'requires a rollbar_item' do
      issue = build(:github_issue, rollbar_item: nil)
      expect(issue).not_to be_valid
    end
  end

  describe '#labels' do
    it 'deserializes JSON array' do
      issue = create(:github_issue, labels: %w[bug rollbar].to_json)
      expect(issue.labels).to eq(%w[bug rollbar])
    end

    it 'returns empty array when nil' do
      issue = create(:github_issue, labels: nil)
      expect(issue.labels).to eq([])
    end

    it 'accepts an array and serializes to JSON' do
      issue = build(:github_issue)
      issue.labels = ['bug', 'severity:high']
      issue.save!
      expect(issue.reload.labels).to eq(['bug', 'severity:high'])
    end
  end

  describe '#submitted?' do
    it 'returns false when no url' do
      issue = build(:github_issue, github_issue_url: nil)
      expect(issue.submitted?).to be false
    end

    it 'returns true when url present' do
      issue = build(:github_issue, github_issue_url: 'https://github.com/owner/repo/issues/1')
      expect(issue.submitted?).to be true
    end
  end

  describe 'scopes' do
    let!(:pending_issue)   { create(:github_issue, github_issue_url: nil, submitted_at: nil) }
    let!(:submitted_issue) { create(:github_issue, github_issue_url: 'https://github.com/x/y/issues/1', submitted_at: 40.days.ago) }
    let!(:recent_issue)    { create(:github_issue, github_issue_url: 'https://github.com/x/y/issues/2', submitted_at: 1.day.ago) }

    it '.pending_submission returns unsubmitted issues' do
      expect(GithubIssue.pending_submission).to contain_exactly(pending_issue)
    end

    it '.submitted returns submitted issues' do
      expect(GithubIssue.submitted).to include(submitted_issue, recent_issue)
    end

    it '.older_than filters by age' do
      expect(GithubIssue.submitted.older_than(30.days)).to contain_exactly(submitted_issue)
    end
  end
end
