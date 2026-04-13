# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostPrReviews do
  let(:github_repo)    { 'owner/repo' }
  let(:github_token)   { 'gh-test-token' }
  let(:null_spinner)   { instance_double(TTY::Spinner, auto_spin: nil, success: nil, error: nil) }
  let(:spinner_factory) { ->(_msg) { null_spinner } }
  let(:pastel)         { Pastel.new(enabled: false) }
  let(:octokit_client) { instance_double(Octokit::Client) }
  let(:review_result)  { double(html_url: 'https://github.com/owner/repo/pull/1#pullrequestreview-99') }

  subject(:service) do
    described_class.new(
      github_repo: github_repo,
      github_token: github_token,
      pastel: pastel,
      spinner_factory: spinner_factory
    )
  end

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: github_token).and_return(octokit_client)
    allow(octokit_client).to receive(:label).with(github_repo, PostPrReviews::AI_REVIEWED_LABEL)
  end

  describe '#call' do
    context 'with pending reviews' do
      let!(:review) { create(:pr_review, :reviewed, github_repo: github_repo) }

      before do
        allow(octokit_client).to receive(:create_pull_request_review).and_return(review_result)
        allow(octokit_client).to receive(:add_labels_to_an_issue)
      end

      it 'posts the review with body and inline comments to GitHub' do
        expect(octokit_client).to receive(:create_pull_request_review).with(
          github_repo,
          review.pr_number,
          body: review.review_body,
          event: 'COMMENT',
          comments: review.inline_comments
        )
        service.call
      end

      it 'adds the ai-reviewed label to the PR' do
        expect(octokit_client).to receive(:add_labels_to_an_issue).with(
          github_repo,
          review.pr_number,
          [PostPrReviews::AI_REVIEWED_LABEL]
        )
        service.call
      end

      it 'updates review_url and submitted_at on the record' do
        service.call
        expect(review.reload.review_url).to eq('https://github.com/owner/repo/pull/1#pullrequestreview-99')
        expect(review.reload.submitted_at).not_to be_nil
      end
    end

    context 'with no pending reviews' do
      it 'does not call the GitHub API' do
        expect(octokit_client).not_to receive(:create_pull_request_review)
        service.call
      end
    end

    context 'when the ai-reviewed label does not exist' do
      let!(:review) { create(:pr_review, :reviewed, github_repo: github_repo) }

      before do
        allow(octokit_client).to receive(:label).and_raise(Octokit::NotFound)
        allow(octokit_client).to receive(:add_label)
        allow(octokit_client).to receive(:create_pull_request_review).and_return(review_result)
        allow(octokit_client).to receive(:add_labels_to_an_issue)
      end

      it 'creates the label before proceeding' do
        expect(octokit_client).to receive(:add_label).with(github_repo, PostPrReviews::AI_REVIEWED_LABEL, '0075ca')
        service.call
      end
    end

    context 'when posting a review fails' do
      let!(:review) { create(:pr_review, :reviewed, github_repo: github_repo) }

      before do
        allow(octokit_client).to receive(:create_pull_request_review).and_raise(Octokit::Error, 'API error')
      end

      it 'does not raise' do
        expect { service.call }.not_to raise_error
      end

      it 'leaves the review unsubmitted' do
        service.call
        expect(review.reload.review_url).to be_nil
      end

      it 'does not apply the label when the review post failed' do
        expect(octokit_client).not_to receive(:add_labels_to_an_issue)
        service.call
      end
    end

    context 'without a token' do
      subject(:service) do
        described_class.new(github_repo: github_repo, github_token: nil, spinner_factory: spinner_factory)
      end

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, /--github-token/)
      end
    end

    context 'with reviews from a different repo' do
      let!(:other_review) { create(:pr_review, :reviewed, github_repo: 'other/repo') }

      it 'only processes reviews for the configured repo' do
        expect(octokit_client).not_to receive(:create_pull_request_review)
        service.call
      end
    end
  end
end
