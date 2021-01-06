require "rails_helper"

# TODO: Seems like Rails 6.1 doesn't have this support built in yet
module ActionCable
  module Channel
    class ConnectionStub
      def pubsub
        ActionCable.server.pubsub
      end
    end
  end
end

RSpec.describe StreamingChannel, :type => :channel do
  before do
    stub_connection uuid: '12345'
  end

  it "subscribes" do
    subscribe(scope: :DEFAULT)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from('12345')
  end

  context "adds" do
    it "rejects without scope" do
      subscribe(scope: :DEFAULT)
      subscription.add({items: ['TLM__TGT__PKT__ITEM__CONVERTED']})
      expect(subscription).to be_rejected
    end

    it "rejects without items" do
      subscribe(scope: :DEFAULT)
      subscription.add({scope: 'DEFAULT'})
      expect(subscription).to be_rejected
    end

    it "rejects with empty items" do
      subscribe(scope: :DEFAULT)
      subscription.add({scope: 'DEFAULT', items: []})
      expect(subscription).to be_rejected
    end

    it "rejects with start_time greater than now" do
      time = Time.now.to_nsec_from_epoch + 1_000_000_000
      subscribe(scope: :DEFAULT)
      subscription.add({scope: 'DEFAULT', items: ['TLM__TGT__PKT__ITEM__CONVERTED'], start_time: time})
      expect(subscription).to be_rejected
    end

    it "adds specified items" do
      subscribe(scope: :DEFAULT)
      subscription.add({scope: 'DEFAULT', items: ['TLM__TGT__PKT__ITEM__CONVERTED']})
      expect(subscription).to be_confirmed
    end
  end
end
