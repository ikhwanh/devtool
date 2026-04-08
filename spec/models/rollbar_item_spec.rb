# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RollbarItem, type: :model do
  describe 'validations' do
    it 'is valid with required fields' do
      item = build(:rollbar_item)
      expect(item).to be_valid
    end

    it 'requires rollbar_id' do
      item = build(:rollbar_item, rollbar_id: nil)
      expect(item).not_to be_valid
    end

    it 'requires title' do
      item = build(:rollbar_item, title: nil)
      expect(item).not_to be_valid
    end

    it 'enforces unique rollbar_id' do
      create(:rollbar_item, rollbar_id: 1)
      duplicate = build(:rollbar_item, rollbar_id: 1)
      expect(duplicate).not_to be_valid
    end

    it 'rejects invalid severity' do
      item = build(:rollbar_item, severity: 'critical')
      expect(item).not_to be_valid
    end

    it 'allows nil severity' do
      item = build(:rollbar_item, severity: nil)
      expect(item).to be_valid
    end
  end

  describe '#occurrence_data' do
    it 'serializes and deserializes JSON' do
      data = { 'trace' => { 'frames' => [] } }
      item = create(:rollbar_item, occurrence_data: data)
      expect(item.reload.occurrence_data).to eq(data)
    end

    it 'returns nil when not set' do
      item = create(:rollbar_item, occurrence_data: nil)
      expect(item.occurrence_data).to be_nil
    end
  end

  describe '#submitted_to_github?' do
    it 'returns false when no github issues exist' do
      item = create(:rollbar_item)
      expect(item.submitted_to_github?).to be false
    end

    it 'returns false when github issue has no url' do
      item = create(:rollbar_item)
      create(:github_issue, rollbar_item: item, github_issue_url: nil)
      expect(item.submitted_to_github?).to be false
    end

    it 'returns true when a github issue has a url' do
      item = create(:rollbar_item)
      create(:github_issue, rollbar_item: item, github_issue_url: 'https://github.com/owner/repo/issues/1')
      expect(item.submitted_to_github?).to be true
    end
  end

  describe 'scopes' do
    let!(:high_selected) { create(:rollbar_item, severity: 'high', selected: true) }
    let!(:medium_unselected) { create(:rollbar_item, severity: 'medium', selected: false) }
    let!(:old_item) { create(:rollbar_item, last_occurrence_at: 10.days.ago) }

    it '.selected returns only selected items' do
      expect(RollbarItem.selected).to contain_exactly(high_selected)
    end

    it '.with_severity filters by severity' do
      expect(RollbarItem.with_severity('high')).to include(high_selected)
      expect(RollbarItem.with_severity('high')).not_to include(medium_unselected)
    end

    it '.within_window excludes items before cutoff' do
      cutoff = 5.days.ago
      expect(RollbarItem.within_window(cutoff)).not_to include(old_item)
    end
  end
end
