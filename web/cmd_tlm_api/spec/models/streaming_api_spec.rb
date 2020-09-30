require 'rails_helper'

RSpec.describe StreamingApi, type: :model do
  before(:each) do
    @messages = []
    @channel = double('channel')
    allow(@channel).to receive(:transmit) { |msg| @messages << msg }
    @api = StreamingApi.new(123, @channel)
  end

  it 'creates a collection and stores the channel' do
    expect(@api.instance_variable_get('@realtime_thread')).to be_nil
    expect(@api.instance_variable_get('@logged_threads')).to be_empty
    expect(@api.instance_variable_get('@collection')).to_not be_nil
    expect(@api.instance_variable_get('@channel')).to eq(@channel)
  end

  context 'streaming with Redis' do
    let(:data) { { 'scope' => 'DEFAULT', 'items' => ['TLM__TGT__PKT__ITEM1__CONVERTED'] } }
    let(:time) { Time.new(2020, 07, 01, 12, 30, 15) }

    # before do
    #   # Don't actually start the threads for this test
    #   allow_any_instance_of(StreamingThread).to receive(:start)
    # end

    context 'realtime only' do
      it 'has no start or end time' do
        configure_store()
        msg = {}
        msg['target_name'] = 'TGT'
        msg['packet_name'] = 'PKT'
        msg['time'] = time.to_i * 1_000_000_000
        packet_data = {}
        packet_data['PACKET_TIMESECONDS'] = time.to_f
        packet_data['PACKET_TIMEFORMATTED'] = time.formatted
        packet_data['ITEM1__R'] = 1
        msg['json_data'] = JSON.generate(packet_data.to_json)
        @cur_time = time
        allow(Cosmos::Store.instance).to receive(:read_topics) do |_, &block|
          sleep 0.1 # Simulate a little blocking time
          msg['time'] = @cur_time.to_i * 1_000_000_000 # Convert to nsec
          block.call('DEFAULT__DECOM__TGT__PKT', "#{@cur_time.to_i * 1000}-0", msg, nil)
          @cur_time += 1
        end

        # Actual test starts here:
        expect(@messages.length).to eq(0)
        @api.add(data)
        sleep 0.35
        expect(@messages.length).to eq(3)
        # Remove the items and we should get one more packet due to the processing loop
        @api.remove(data)
        sleep 0.15
        expect(@messages.length).to eq(4) # One more
        sleep 0.15
        expect(@messages.length).to eq(4) # No more

        # Ensure we can add items again and resume processing
        @api.add(data)
        while true
          sleep 0.05
          break if @messages.length > 4
        end
        @api.kill
        expect(@api.instance_variable_get('@realtime_thread')).to be_nil
      end
    end

    # context 'logging plus realtime' do
    #   it 'has start time less than now, no end time' do
    #     # Don't actually start the threads for this test
    #     allow_any_instance_of(StreamingThread).to receive(:start)

    #     expect(@api.instance_variable_get('@logged_threads')).to be_empty
    #     expect(@api.instance_variable_get('@realtime_thread')).to be_nil
    #     data = {}
    #     data["scope"] = 'DEFAULT'
    #     data["start_time"] = Time.now.to_nsec_from_epoch - 10000000000
    #     data["items"] = ["TLM__TGT__PKT__ITEM1__CONVERTED", "TLM__TGT__PKT__ITEM2__CONVERTED"]
    #     @api.add(data)
    #     expect(@api.instance_variable_get('@realtime_thread')).to_not be_nil
    #     expect(@api.instance_variable_get('@logged_threads')).to_not be_empty
    #   end

    #   it 'has start time less than now with end time' do
    #   end

    #   it 'has start time less than now with end time' do
    #   end
    # end

    # context 'add with end and no start' do
    #   it 'creates realtime and no logging' do
    #     # Don't actually start the threads for this test
    #     allow_any_instance_of(StreamingThread).to receive(:start)

    #     expect(@api.instance_variable_get('@logged_threads')).to be_empty
    #     expect(@api.instance_variable_get('@realtime_thread')).to be_nil
    #     data = {}
    #     data["scope"] = 'DEFAULT'
    #     data["end_time"] = Time.now.to_nsec_from_epoch + 10000000000
    #     data["items"] = ["TLM__TGT__PKT__ITEM1__CONVERTED", "TLM__TGT__PKT__ITEM2__CONVERTED"]
    #     @api.add(data)
    #     expect(@api.instance_variable_get('@realtime_thread')).to_not be_nil
    #     expect(@api.instance_variable_get('@logged_threads')).to be_empty
    #   end
    # end

    # context 'add with start and end time' do
    #   it 'creates realtime and no logging' do
    #     # Don't actually start the threads for this test
    #     allow_any_instance_of(StreamingThread).to receive(:start)

    #     expect(@api.instance_variable_get('@logged_threads')).to be_empty
    #     expect(@api.instance_variable_get('@realtime_thread')).to be_nil
    #     data = {}
    #     data["scope"] = 'DEFAULT'
    #     data["end_time"] = Time.now.to_nsec_from_epoch + 10000000000
    #     data["items"] = ["TLM__TGT__PKT__ITEM1__CONVERTED", "TLM__TGT__PKT__ITEM2__CONVERTED"]
    #     @api.add(data)
    #     expect(@api.instance_variable_get('@realtime_thread')).to_not be_nil
    #     expect(@api.instance_variable_get('@logged_threads')).to be_empty
    #   end
    # end
  end

  # StreamingItem and StreamingItemCollection are implementation details
  # describe StreamingApi::StreamingItem do
  #   context 'command' do
  #     it 'populates topic' do
  #       item = StreamingApi::StreamingItem.new('CMD__TGT__PKT__ITEM__CONVERTED', 0, 0, scope: 'DEFAULT')
  #       expect(item.topic).to eq('DEFAULT__DECOMCMD__TGT__PKT')
  #     end
  #   end

  #   context 'telemetry' do
  #     it 'populates topic' do
  #       item = StreamingApi::StreamingItem.new('TLM__TGT__PKT__ITEM__CONVERTED', 0, 0, scope: 'DEFAULT')
  #       expect(item.topic).to eq('DEFAULT__DECOM__TGT__PKT')
  #     end
  #   end
  # end
end
