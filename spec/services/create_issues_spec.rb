# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateIssues do
  let(:github_repo) { 'owner/repo' }
  let(:github_token) { 'gh-test-token' }
  let(:null_spinner) { instance_double(TTY::Spinner, auto_spin: nil, success: nil, error: nil) }
  let(:spinner_factory) { ->(_msg) { null_spinner } }
  let(:pastel) { Pastel.new(enabled: false) }

  subject(:service) do
    described_class.new(
      github_repo: github_repo,
      github_token: github_token,
      pastel: pastel,
      spinner_factory: spinner_factory
    )
  end

  describe '#call' do
    context 'with pending issues' do
      let!(:rollbar_item) { create(:rollbar_item) }
      let!(:pending_issue) { create(:github_issue, rollbar_item: rollbar_item) }

      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:issue_result) do
        double(html_url: 'https://github.com/owner/repo/issues/42', number: 42)
      end

      before do
        allow(Octokit::Client).to receive(:new).with(access_token: github_token).and_return(octokit_client)
        allow(octokit_client).to receive(:create_issue).and_return(issue_result)
      end

      it 'creates issues via Octokit' do
        expect(octokit_client).to receive(:create_issue).once
        service.call
      end

      it 'updates the GithubIssue record with the URL' do
        service.call
        expect(pending_issue.reload.github_issue_url).to eq('https://github.com/owner/repo/issues/42')
        expect(pending_issue.reload.github_issue_number).to eq(42)
        expect(pending_issue.reload.submitted_at).not_to be_nil
      end
    end

    context 'with no pending issues' do
      it 'prints a message and returns early without creating issues' do
        expect { service.call }.not_to change(GithubIssue, :count)
      end
    end

    context 'when API call fails' do
      let!(:rollbar_item) { create(:rollbar_item) }
      let!(:pending_issue) { create(:github_issue, rollbar_item: rollbar_item) }
      let(:octokit_client) { instance_double(Octokit::Client) }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:create_issue).and_raise(Octokit::Error, 'API error')
      end

      it 'does not raise and leaves issue unsubmitted' do
        expect { service.call }.not_to raise_error
        expect(pending_issue.reload.github_issue_url).to be_nil
      end
    end

    context 'without a token' do
      subject(:service) do
        described_class.new(github_repo: github_repo, github_token: nil)
      end

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, /--github-token/)
      end
    end

    context 'with invalid repo format' do
      subject(:service) do
        described_class.new(github_repo: 'invalid', github_token: github_token)
      end

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, %r{owner/repo})
      end
    end

    context 'retention cleanup' do
      let!(:rollbar_item) { create(:rollbar_item) }
      let!(:old_submitted) do
        create(:github_issue, rollbar_item: rollbar_item,
                              github_issue_url: 'https://github.com/x/y/issues/1',
                              submitted_at: 31.days.ago)
      end

      before do
        octokit_client = instance_double(Octokit::Client)
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
      end

      it 'removes issues submitted more than 30 days ago' do
        expect { service.call }.to change(GithubIssue, :count).by(-1)
      end
    end
  end
end
