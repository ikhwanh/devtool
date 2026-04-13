# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrReview do
  describe 'validations' do
    it 'is valid with required attributes' do
      expect(build(:pr_review)).to be_valid
    end

    it 'is invalid without github_repo' do
      expect(build(:pr_review, github_repo: nil)).not_to be_valid
    end

    it 'is invalid without pr_number' do
      expect(build(:pr_review, pr_number: nil)).not_to be_valid
    end

    it 'is invalid without head_sha' do
      expect(build(:pr_review, head_sha: nil)).not_to be_valid
    end

    it 'enforces uniqueness on [github_repo, pr_number, head_sha]' do
      create(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'abc')
      duplicate = build(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'abc')
      expect(duplicate).not_to be_valid
    end

    it 'allows same pr_number with a different head_sha' do
      create(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'abc')
      expect(build(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'def')).to be_valid
    end
  end

  describe '.already_reviewed?' do
    it 'returns true when a record exists for the given repo/pr_number/head_sha' do
      create(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'abc')
      expect(described_class.already_reviewed?(repo: 'owner/repo', pr_number: 1, head_sha: 'abc')).to be true
    end

    it 'returns false when no matching record exists' do
      expect(described_class.already_reviewed?(repo: 'owner/repo', pr_number: 1, head_sha: 'abc')).to be false
    end

    it 'returns false when the sha differs' do
      create(:pr_review, github_repo: 'owner/repo', pr_number: 1, head_sha: 'abc')
      expect(described_class.already_reviewed?(repo: 'owner/repo', pr_number: 1, head_sha: 'new-sha')).to be false
    end
  end

  describe '#inline_comments' do
    it 'parses comments_json into an array of hashes' do
      comments = [{ path: 'app/foo.rb', line: 5, side: 'RIGHT', body: '[minor] Rename this.' }]
      review = build(:pr_review, comments_json: comments.to_json)
      expect(review.inline_comments).to eq([{ 'path' => 'app/foo.rb', 'line' => 5, 'side' => 'RIGHT',
                                              'body' => '[minor] Rename this.' }])
    end

    it 'returns an empty array when comments_json is blank' do
      expect(build(:pr_review, comments_json: nil).inline_comments).to eq([])
    end

    it 'returns an empty array when comments_json is invalid JSON' do
      expect(build(:pr_review, comments_json: 'bad').inline_comments).to eq([])
    end
  end

  describe '#diff_files' do
    it 'parses diff_json into an array of hashes' do
      review = build(:pr_review, diff_json: [{ filename: 'app/foo.rb', status: 'modified', patch: '@@ -1 +1 @@' }].to_json)
      expect(review.diff_files).to eq([{ 'filename' => 'app/foo.rb', 'status' => 'modified', 'patch' => '@@ -1 +1 @@' }])
    end

    it 'returns an empty array when diff_json is blank' do
      expect(build(:pr_review, diff_json: nil).diff_files).to eq([])
    end

    it 'returns an empty array when diff_json is invalid JSON' do
      expect(build(:pr_review, diff_json: 'not-json').diff_files).to eq([])
    end
  end

  describe 'scopes' do
    let!(:pending_review)     { create(:pr_review) }
    let!(:pending_submission) { create(:pr_review, :reviewed) }
    let!(:submitted)          { create(:pr_review, :submitted) }

    describe '.pending_review' do
      it 'returns only records without a review_body' do
        expect(described_class.pending_review).to contain_exactly(pending_review)
      end
    end

    describe '.pending_submission' do
      it 'returns only records with a review_body but no review_url' do
        expect(described_class.pending_submission).to contain_exactly(pending_submission)
      end
    end

    describe '.submitted' do
      it 'returns only records with a review_url' do
        expect(described_class.submitted).to contain_exactly(submitted)
      end
    end

    describe '.for_repo' do
      let!(:other_repo) { create(:pr_review, github_repo: 'other/repo') }

      it 'filters by github_repo' do
        expect(described_class.for_repo('owner/repo')).not_to include(other_repo)
      end
    end

    describe '.older_than' do
      it 'returns records submitted before the cutoff' do
        old = create(:pr_review, :submitted, submitted_at: 31.days.ago)
        expect(described_class.older_than(30.days)).to include(old)
        expect(described_class.older_than(30.days)).not_to include(submitted)
      end
    end
  end
end
