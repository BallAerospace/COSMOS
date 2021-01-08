require 'rails_helper'

RSpec.describe StreamingApi, type: :model do
  before(:each) do
    @messages = []
    @channel = double('channel')
    allow(@channel).to receive(:transmit) { |msg| @messages << msg }
    @api = StreamingApi.new(123, @channel, scope: 'DEFAULT')
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
      @max_time = @start_time + 1_000_000
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
        @time += 1
        msg['time'] = @time.to_i * 1_000_000_000 # Convert to nsec
        if @time < @max_time
          block.call('DEFAULT__DECOM__TGT__PKT', "#{@time.to_i * 1000}-0", msg, nil)
        else
          {} # Return an empty result like the real store code
        end
      end
    end

    it 'has no data in time range' do
      msg1 = {'time' => (@start_time.to_i - 10) * 1_000_000_000 } # newest is 10s ago
      allow(Cosmos::Store.instance).to receive(:get_newest_message).and_return([nil, msg1])
      msg2 = {'time' => (@start_time.to_i - 100) * 1_000_000_000 } # oldest is 100s ago
      allow(Cosmos::Store.instance).to receive(:get_oldest_message).and_return(["#{@start_time.to_i - 100}000-0", msg2])

      @time = Time.at(@start_time.to_i - 5.5)
      data['start_time'] = @time.to_i * 1_000_000_000 # 5.5s in the past
      data['end_time'] = (@start_time.to_i - 1.5) * 1_000_000_000 # 1.5 in the past
      @api.add(data)
      sleep 0.25 # Allow the threads to run
      # We should get the empty message to say we're done
      expect(@messages.length).to eq(1)
      expect(@messages[-1]).to eq("[]") # JSON encoded empty message to say we're done
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
        # We should have 2 messages: one at 1s and then the time will disqualify them
        # so the final message is the empty set to say we're done
        expect(@messages.length).to eq(2)
        expect(@messages[-1]).to eq("[]") # JSON encoded empty message to say we're done

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
        sleep 0.65 # Allow the threads to run
        # We expect 5 messages because total time is 2.25s and we get a packet at 1, 2, then one more plus empty
        expect(@messages.length).to eq(3)
        expect(@messages[-1]).to eq("[]") # JSON encoded empty message to say we're done
        logged = @api.instance_variable_get('@logged_threads')
        # TODO: Should the thread be cleaned up and removed?
        expect(logged.length).to eq(1)
        expect(logged[0].alive?).to be false
      end
    end

    context 'logging only' do
      it 'has past start time and past end time' do
        msg1 = {'time' => @start_time.to_i * 1_000_000_000 } # newest is now
        allow(Cosmos::Store.instance).to receive(:get_newest_message).and_return([nil, msg1])
        msg2 = {'time' => (@start_time.to_i - 100) * 1_000_000_000 } # oldest is 100s ago
        allow(Cosmos::Store.instance).to receive(:get_oldest_message).and_return(["#{@start_time.to_i - 100}000-0", msg2])

        @time = Time.at(@start_time.to_i - 2.5)
        data['start_time'] = @time.to_i * 1_000_000_000 # 2.5s in the past
        data['end_time'] = (@start_time.to_i - 0.25) * 1_000_000_000 # 0.25s in the past
        @api.add(data)
        sleep 0.65 # Allow the threads to run
        # We expect 5 messages because total time is 2.25s and we get a packet at 1, 2, then one more plus empty
        expect(@messages.length).to eq(3)
        expect(@messages[-1]).to eq("[]") # JSON encoded empty message to say we're done
        logged = @api.instance_variable_get('@logged_threads')
        # TODO: Should the thread be cleaned up and removed?
        expect(logged.length).to eq(1)
        expect(logged[0].alive?).to be false
      end

      it 'has past start time and past end time with limit' do
        msg1 = {'time' => @start_time.to_i * 1_000_000_000 } # newest is now
        allow(Cosmos::Store.instance).to receive(:get_newest_message).and_return([nil, msg1])
        msg2 = {'time' => (@start_time.to_i - 100) * 1_000_000_000 } # oldest is 100s ago
        allow(Cosmos::Store.instance).to receive(:get_oldest_message).and_return(["#{@start_time.to_i - 100}000-0", msg2])

        # Set a max time so we stop sending out packets past this time
        # This simulates a command log which isn't going to constantly spit out packets to force the final processing
        # The streaming api logic must determine we've waited long enough and stop the stream
        @max_time = @start_time - 1.25 # We won't reach the end time
        @time = Time.at(@start_time.to_i - 2.5)
        data['start_time'] = @time.to_i * 1_000_000_000 # 2.5s in the past
        data['end_time'] = (@start_time.to_i - 0.25) * 1_000_000_000 # 0.25s in the past
        @api.add(data)
        sleep 0.65 # Allow the threads to run
        # We expect 2 messages because we get a packet at 1 plus empty
        expect(@messages.length).to eq(2)
        expect(@messages[-1]).to eq("[]") # JSON encoded empty message to say we're done
        logged = @api.instance_variable_get('@logged_threads')
        # TODO: Should the thread be cleaned up and removed?
        expect(logged.length).to eq(1)
        expect(logged[0].alive?).to be false
      end
    end
  end
end
