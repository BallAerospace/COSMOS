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

    before do
      configure_store()
      @start_time = Time.now
      @time = @start_time
      msg = {}
      msg['target_name'] = 'TGT'
      msg['packet_name'] = 'PKT'
      msg['time'] = @time.to_i * 1_000_000_000
      packet_data = {}
      packet_data['PACKET_TIMESECONDS'] = @time.to_f
      packet_data['PACKET_TIMEFORMATTED'] = @time.formatted
      packet_data['ITEM1__R'] = 1
      msg['json_data'] = JSON.generate(packet_data.to_json)
      allow(Cosmos::Store.instance).to receive(:read_topics) do |_, &block|
        sleep 0.1 # Simulate a little blocking time
        msg['time'] = @time.to_i * 1_000_000_000 # Convert to nsec
        block.call('DEFAULT__DECOM__TGT__PKT', "#{@time.to_i * 1000}-0", msg, nil)
        @time += 1
      end
    end

    context 'realtime only' do
      # NOTE: We're not testing start time > Time.now as this is disallowed by the StreamingChannel

      it 'has no start and no end time' do
        @api.add(data)
        sleep 0.35 # Allow the thread to run
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

      it 'has no start time and future end time' do
        data['end_time'] = (@start_time.to_i + 1.5) * 1_000_000_000 # 1.5s in the future we stop
        @api.add(data)
        sleep 0.35 # Allow the thread to run
        # We should have 2 messages: one at now, one at plus 1s, and then the time will disqualify them
        expect(@messages.length).to eq(2)
        # The realtime thread should still be alive waiting for another add
        expect(@api.instance_variable_get('@realtime_thread').alive?).to be true
        @api.kill
        expect(@api.instance_variable_get('@realtime_thread')).to be_nil
      end
    end

    context 'logging plus realtime' do
      it 'has past start time and no end time' do
        msg1 = {'time' => @start_time.to_i * 1_000_000_000 } # newest is now
        allow(Cosmos::Store.instance).to receive(:get_newest_message).and_return([nil, msg1])
        msg2 = {'time' => (@start_time.to_i - 100) * 1_000_000_000 } # oldest is 100s ago
        allow(Cosmos::Store.instance).to receive(:get_oldest_message).and_return(["#{@start_time.to_i - 100}000-0", msg2])

        @time = Time.at(@start_time.to_i - 1.5)
        data['start_time'] = @time.to_i * 1_000_000_000 # 1.5s in the past
        @api.add(data)
        sleep 0.55 # Allow the threads to run
        expect(@messages.length).to eq(5)
        expect(@api.instance_variable_get('@logged_threads').length).to eq(1)
        expect(@api.instance_variable_get('@realtime_thread')).to be_nil
        @api.kill
        expect(@api.instance_variable_get('@logged_threads')).to be_empty
      end

      it 'has past start time and future end time' do
        msg1 = {'time' => @start_time.to_i * 1_000_000_000 } # newest is now
        allow(Cosmos::Store.instance).to receive(:get_newest_message).and_return([nil, msg1])
        msg2 = {'time' => (@start_time.to_i - 100) * 1_000_000_000 } # oldest is 100s ago
        allow(Cosmos::Store.instance).to receive(:get_oldest_message).and_return(["#{@start_time.to_i - 100}000-0", msg2])

        @time = Time.at(@start_time.to_i - 1.5)
        data['start_time'] = @time.to_i * 1_000_000_000 # 1.5s in the past
        data['end_time'] = (@start_time.to_i + 0.75) * 1_000_000_000 # 0.75s in the future
        @api.add(data)
        sleep 0.55 # Allow the threads to run
        # We expect 4 messages because total time is 2.25s and we get a packet at 0, 1, 2, then one more
        expect(@messages.length).to eq(4)
        logged = @api.instance_variable_get('@logged_threads')
        # TODO: Should the thread be cleaned up and removed?
        expect(logged.length).to eq(1)
        expect(logged[0].alive?).to be false
      end
    end

    context 'logging only' do
    end

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
