# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FetchPullRequests do
  let(:github_repo)    { 'owner/repo' }
  let(:github_token)   { 'gh-test-token' }
  let(:null_spinner)   { instance_double(TTY::Spinner, auto_spin: nil, success: nil, error: nil) }
  let(:spinner_factory) { ->(_msg) { null_spinner } }
  let(:octokit_client) { instance_double(Octokit::Client) }

  subject(:service) do
    described_class.new(
      github_repo: github_repo,
      github_token: github_token,
      spinner_factory: spinner_factory
    )
  end

  def pr_double(number:, title:, sha:, draft: false, created_at: 1.day.ago, body: nil)
    head = double(sha: sha)
    double(number: number, title: title, body: body, draft: draft, created_at: created_at, head: head)
  end

  def file_double(filename: 'app/models/user.rb', status: 'modified', patch: '@@ -1 +1 @@')
    double(filename: filename, status: status, patch: patch)
  end

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: github_token).and_return(octokit_client)
    allow(octokit_client).to receive(:pull_request_files).and_return([file_double])
  end

  describe '#call' do
    context 'with new open PRs' do
      let(:pr) { pr_double(number: 1, title: 'Add feature', sha: 'abc123') }

      before { allow(octokit_client).to receive(:pull_requests).and_return([pr]) }

      it 'creates a PrReview record' do
        expect { service.call }.to change(PrReview, :count).by(1)
      end

      it 'returns changed: true' do
        expect(service.call[:changed]).to be true
      end

      it 'stores the correct attributes' do
        service.call
        review = PrReview.last
        expect(review.pr_number).to eq(1)
        expect(review.pr_title).to eq('Add feature')
        expect(review.head_sha).to eq('abc123')
        expect(review.github_repo).to eq(github_repo)
      end

      it 'stores diff_json from pull_request_files' do
        service.call
        files = PrReview.last.diff_files
        expect(files.first['filename']).to eq('app/models/user.rb')
        expect(files.first['status']).to eq('modified')
      end
    end

    context 'when the PR was already reviewed with the same SHA' do
      let(:pr) { pr_double(number: 1, title: 'Add feature', sha: 'abc123') }

      before do
        create(:pr_review, github_repo: github_repo, pr_number: 1, head_sha: 'abc123')
        allow(octokit_client).to receive(:pull_requests).and_return([pr])
      end

      it 'does not create a duplicate record' do
        expect { service.call }.not_to change(PrReview, :count)
      end

      it 'returns changed: false' do
        expect(service.call[:changed]).to be false
      end
    end

    context 'when a PR has new commits (different SHA)' do
      let(:pr) { pr_double(number: 1, title: 'Add feature', sha: 'new-sha') }

      before do
        create(:pr_review, github_repo: github_repo, pr_number: 1, head_sha: 'old-sha')
        allow(octokit_client).to receive(:pull_requests).and_return([pr])
      end

      it 'queues a new review for the updated SHA' do
        expect { service.call }.to change(PrReview, :count).by(1)
      end

      it 'returns changed: true' do
        expect(service.call[:changed]).to be true
      end
    end

    context 'with a draft PR' do
      let(:pr) { pr_double(number: 1, title: 'Add feature', sha: 'abc123', draft: true) }

      before { allow(octokit_client).to receive(:pull_requests).and_return([pr]) }

      it 'does not queue the PR' do
        expect { service.call }.not_to change(PrReview, :count)
      end

      it 'returns changed: false' do
        expect(service.call[:changed]).to be false
      end
    end

    context 'with WIP titles' do
      before { allow(octokit_client).to receive(:pull_requests).and_return([pr]) }

      ['WIP:', '[WIP]', '[wip]', 'wip:', 'Draft:', 'draft:', 'Bump '].each do |prefix|
        it "skips a PR titled '#{prefix} some work'" do
          allow(octokit_client).to receive(:pull_requests).and_return(
            [pr_double(number: 1, title: "#{prefix} some work", sha: 'abc')]
          )
          expect { service.call }.not_to change(PrReview, :count)
        end
      end

      let(:pr) { pr_double(number: 1, title: 'WIP: refactor', sha: 'abc') }
    end

    context 'with a PR older than days_ago' do
      let(:old_pr) { pr_double(number: 1, title: 'Old PR', sha: 'abc123', created_at: 10.days.ago) }

      subject(:service) do
        described_class.new(
          github_repo: github_repo,
          github_token: github_token,
          days_ago: 7,
          spinner_factory: spinner_factory
        )
      end

      before { allow(octokit_client).to receive(:pull_requests).and_return([old_pr]) }

      it 'does not queue the PR' do
        expect { service.call }.not_to change(PrReview, :count)
      end
    end

    context 'retention cleanup' do
      let(:pr) { pr_double(number: 2, title: 'New PR', sha: 'new-sha') }

      before do
        create(:pr_review, :submitted, github_repo: github_repo, submitted_at: 31.days.ago)
        allow(octokit_client).to receive(:pull_requests).and_return([pr])
      end

      it 'removes submitted reviews older than 30 days' do
        old_count = PrReview.submitted.count
        service.call
        expect(PrReview.submitted.count).to be < old_count
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

    context 'when the GitHub API fails' do
      before do
        allow(octokit_client).to receive(:pull_requests).and_raise(RuntimeError, 'API error')
      end

      it 'raises the error' do
        expect { service.call }.to raise_error(RuntimeError, 'API error')
      end
    end
  end
end
