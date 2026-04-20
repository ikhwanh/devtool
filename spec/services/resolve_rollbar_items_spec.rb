# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolveRollbarItems do
  let(:github_repo)    { 'owner/repo' }
  let(:github_token)   { 'gh-test-token' }
  let(:rollbar_token)  { 'rb-write-token' }
  let(:null_spinner)   { instance_double(TTY::Spinner, auto_spin: nil, success: nil, error: nil) }
  let(:spinner_factory) { ->(_msg) { null_spinner } }
  let(:pastel)         { Pastel.new(enabled: false) }
  let(:octokit_client) { instance_double(Octokit::Client) }

  subject(:service) do
    described_class.new(
      github_repo: github_repo,
      github_token: github_token,
      rollbar_token: rollbar_token,
      pastel: pastel,
      spinner_factory: spinner_factory
    )
  end

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: github_token).and_return(octokit_client)
    require 'webmock/rspec'
  end

  def stub_rollbar_resolve(rollbar_id)
    stub_request(:patch, "https://api.rollbar.com/api/1/item/#{rollbar_id}")
      .to_return(
        status: 200,
        body: { 'err' => 0, 'result' => {} }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def closed_issue = double(state: 'closed')
  def open_issue   = double(state: 'open')

  describe '#call' do
    context 'when a linked GitHub issue is closed' do
      let!(:rollbar_item)  { create(:rollbar_item, rollbar_id: 101) }
      let!(:github_issue)  { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 10, github_issue_url: 'https://github.com/owner/repo/issues/10') }

      before do
        allow(octokit_client).to receive(:issue).with('owner/repo', 10).and_return(closed_issue)
        stub_rollbar_resolve(101)
      end

      it 'calls the Rollbar PATCH endpoint' do
        service.call
        expect(WebMock).to have_requested(:patch, 'https://api.rollbar.com/api/1/item/101')
          .with(body: hash_including('item' => { 'status' => 'resolved' }))
      end

      it 'returns resolved: 1, skipped: 0' do
        expect(service.call).to eq(resolved: 1, skipped: 0)
      end
    end

    context 'when any one of multiple issues is closed' do
      let!(:rollbar_item) { create(:rollbar_item, rollbar_id: 102) }
      let!(:open_gh)   { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 20, github_issue_url: 'https://github.com/owner/repo/issues/20') }
      let!(:closed_gh) { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 21, github_issue_url: 'https://github.com/owner/repo/issues/21') }

      before do
        allow(octokit_client).to receive(:issue).with('owner/repo', 20).and_return(open_issue)
        allow(octokit_client).to receive(:issue).with('owner/repo', 21).and_return(closed_issue)
        stub_rollbar_resolve(102)
      end

      it 'resolves the Rollbar item' do
        expect(service.call).to eq(resolved: 1, skipped: 0)
      end
    end

    context 'when all linked issues are open' do
      let!(:rollbar_item) { create(:rollbar_item, rollbar_id: 103) }
      let!(:github_issue) { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 30, github_issue_url: 'https://github.com/owner/repo/issues/30') }

      before do
        allow(octokit_client).to receive(:issue).with('owner/repo', 30).and_return(open_issue)
      end

      it 'skips the Rollbar item' do
        expect(service.call).to eq(resolved: 0, skipped: 1)
      end

      it 'does not call the Rollbar API' do
        service.call
        expect(WebMock).not_to have_requested(:patch, /api.rollbar.com/)
      end
    end

    context 'with no submitted GitHub issues' do
      it 'returns resolved: 0, skipped: 0' do
        expect(service.call).to eq(resolved: 0, skipped: 0)
      end
    end

    context 'in dry-run mode' do
      subject(:service) do
        described_class.new(
          github_repo: github_repo,
          github_token: github_token,
          rollbar_token: rollbar_token,
          dry_run: true,
          pastel: pastel,
          spinner_factory: spinner_factory
        )
      end

      let!(:rollbar_item) { create(:rollbar_item, rollbar_id: 104) }
      let!(:github_issue) { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 40, github_issue_url: 'https://github.com/owner/repo/issues/40') }

      before do
        allow(octokit_client).to receive(:issue).with('owner/repo', 40).and_return(closed_issue)
      end

      it 'does not call the Rollbar API' do
        service.call
        expect(WebMock).not_to have_requested(:patch, /api.rollbar.com/)
      end

      it 'still counts the item as resolved in the result' do
        expect(service.call).to eq(resolved: 1, skipped: 0)
      end
    end

    context 'when the Rollbar API returns an error' do
      let!(:rollbar_item) { create(:rollbar_item, rollbar_id: 105) }
      let!(:github_issue) { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 50, github_issue_url: 'https://github.com/owner/repo/issues/50') }

      before do
        allow(octokit_client).to receive(:issue).with('owner/repo', 50).and_return(closed_issue)
        stub_request(:patch, 'https://api.rollbar.com/api/1/item/105')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'does not raise' do
        expect { service.call }.not_to raise_error
      end
    end

    context 'when GitHub API raises for one issue' do
      let!(:rollbar_item) { create(:rollbar_item, rollbar_id: 106) }
      let!(:github_issue) { create(:github_issue, rollbar_item: rollbar_item, github_issue_number: 60, github_issue_url: 'https://github.com/owner/repo/issues/60') }

      before do
        allow(octokit_client).to receive(:issue).and_raise(Octokit::NotFound)
      end

      it 'skips the item rather than raising' do
        expect { service.call }.not_to raise_error
        expect(service.call).to eq(resolved: 0, skipped: 1)
      end
    end

    context 'without rollbar_token' do
      subject(:service) { described_class.new(github_repo: github_repo, github_token: github_token, rollbar_token: nil) }

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, /rollbar-token/)
      end
    end

    context 'without github_token' do
      subject(:service) { described_class.new(github_repo: github_repo, github_token: nil, rollbar_token: rollbar_token) }

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, /github-token/)
      end
    end

    context 'with invalid repo format' do
      subject(:service) { described_class.new(github_repo: 'invalid', github_token: github_token, rollbar_token: rollbar_token) }

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, %r{owner/repo})
      end
    end
  end
end
