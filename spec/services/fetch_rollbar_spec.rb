# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FetchRollbar do
  let(:token) { 'test-token' }
  let(:null_spinner) { instance_double(TTY::Spinner, auto_spin: nil, success: nil, error: nil) }
  let(:spinner_factory) { ->(_msg) { null_spinner } }

  subject(:service) { described_class.new(token: token, days_ago: 7, spinner_factory: spinner_factory) }

  def stub_rollbar_project
    stub_request(:get, %r{api.rollbar.com/api/1/project})
      .to_return(
        status: 200,
        body: { 'err' => 0, 'result' => { 'name' => 'test-project' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_rollbar_items(items)
    response = {
      'err' => 0,
      'result' => {
        'items' => items,
        'total_count' => items.size
      }
    }.to_json

    stub_request(:get, %r{api.rollbar.com/api/1/items})
      .to_return(status: 200, body: response, headers: { 'Content-Type' => 'application/json' })
  end

  before { require 'webmock/rspec' }

  describe '#call' do
    context 'with new items' do
      let(:item_data) do
        {
          'id' => 1,
          'title' => 'Payment flow failed',
          'environment' => 'production',
          'total_occurrences' => 10,
          'last_occurrence_timestamp' => 1.day.ago.to_i
        }
      end

      before do
        stub_rollbar_project
        stub_rollbar_items([item_data])
      end

      it 'persists items to the database' do
        expect { service.call }.to change(RollbarItem, :count).by(1)
      end

      it 'returns changed: true' do
        expect(service.call[:changed]).to be true
      end

      it 'stores the correct attributes' do
        service.call
        item = RollbarItem.last
        expect(item.rollbar_id).to eq(1)
        expect(item.title).to eq('Payment flow failed')
        expect(item.environment).to eq('production')
      end
    end

    context 'with no new items (empty page)' do
      before do
        stub_rollbar_project
        stub_rollbar_items([])
      end

      it 'returns changed: false when db is already up to date' do
        create(:rollbar_item, rollbar_id: 99, last_occurrence_at: 1.day.ago)
        result = service.call
        expect(result[:changed]).to be false
      end
    end

    context 'without a token' do
      subject(:service) { described_class.new(token: nil, spinner_factory: spinner_factory) }

      it 'raises ArgumentError' do
        expect { service.call }.to raise_error(ArgumentError, /rollbar-token/)
      end
    end

    context 'when rollbar API returns an error' do
      before do
        stub_rollbar_project
        stub_request(:get, %r{api.rollbar.com/api/1/items})
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises a RuntimeError' do
        expect { service.call }.to raise_error(RuntimeError, /Rollbar API error/)
      end
    end
  end
end
