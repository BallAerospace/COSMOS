# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/interface'

module Cosmos

  describe Interface do

    describe "include API" do
      it "includes API" do
        expect(Interface.new.methods).to include :cmd
      end
    end

    describe "initialize" do
      it "initializes the instance variables" do
        i = Interface.new
        expect(i.name).to eql "Cosmos::Interface"
        expect(i.target_names).to eql []
        expect(i.thread).to be_nil
        expect(i.connect_on_startup).to be_truthy
        expect(i.auto_reconnect).to be_truthy
        expect(i.reconnect_delay).to eql 5.0
        expect(i.disable_disconnect).to be_falsey
        expect(i.packet_log_writer_pairs).to eql []
        expect(i.routers).to eql []
        expect(i.read_count).to eql 0
        expect(i.write_count).to eql 0
        expect(i.bytes_read).to eql 0
        expect(i.bytes_written).to eql 0
        expect(i.num_clients).to eql 0
        expect(i.read_queue_size).to eql 0
        expect(i.write_queue_size).to eql 0
        expect(i.interfaces).to eql []
      end
    end

    describe "virtual methods" do
      it "raises an error" do
        i = Interface.new
        expect { i.connect }.to raise_error(/connect method not implemented/)
        expect { i.connected? }.to raise_error(/connected\? method not implemented/)
        expect { i.disconnect}.to raise_error(/disconnect method not implemented/)
        expect { i.read}.to raise_error(/read method not implemented/)
        expect { i.write(nil) }.to raise_error(/write method not implemented/)
        expect { i.write_raw(nil) }.to raise_error(/write_raw method not implemented/)
      end
    end

    describe "read_allowed?" do
      it "is true" do
        expect(Interface.new.read_allowed?).to be_truthy
      end
    end

    describe "write_allowed?" do
      it "is true" do
        expect(Interface.new.write_allowed?).to be_truthy
      end
    end

    describe "write_raw_allowed?" do
      it "is true" do
        expect(Interface.new.write_raw_allowed?).to be_truthy
      end
    end

    describe "copy_to" do
      it "copies the interface" do
        i = Interface.new
        i.name = 'TEST'
        i.target_names = ['TGT1','TGT2']
        i.thread = Thread.new {}
        i.connect_on_startup = false
        i.auto_reconnect = false
        i.reconnect_delay = 1.0
        i.disable_disconnect = true
        i.packet_log_writer_pairs = [1,2]
        i.routers = [3,4]
        i.read_count = 1
        i.write_count = 2
        i.bytes_read = 3
        i.bytes_written = 4
        i.num_clients = 5
        i.read_queue_size = 6
        i.write_queue_size = 7
        i.interfaces = [5,6]

        i2 = Interface.new
        i.copy_to(i2)
        expect(i2.name).to eql 'TEST'
        expect(i2.target_names).to eql ['TGT1','TGT2']
        expect(i2.thread).to be_nil # Thread does not get copied
        expect(i2.connect_on_startup).to be_falsey
        expect(i2.auto_reconnect).to be_falsey
        expect(i2.reconnect_delay).to eql 1.0
        expect(i2.disable_disconnect).to be_truthy
        expect(i2.packet_log_writer_pairs).to eql [1,2]
        expect(i2.routers).to eql [3,4]
        expect(i2.read_count).to eql 1
        expect(i2.write_count).to eql 2
        expect(i2.bytes_read).to eql 3
        expect(i2.bytes_written).to eql 4
        expect(i2.num_clients).to eql 0 # does not get copied
        expect(i2.read_queue_size).to eql 0 # does not get copied
        expect(i2.write_queue_size).to eql 0 # does not get copied
        expect(i2.interfaces).to eql [5,6]

        Cosmos.kill_thread(nil, i.thread)
      end
    end

    describe "post_identify_packet" do
      it "does nothing" do
        expect { Interface.new.post_identify_packet(nil) }.to_not raise_error
      end
    end

  end
end

