# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
      it "should include API" do
        Interface.new.methods.should include :cmd
      end
    end

    describe "initialize" do
      it "should initialize the instance variables" do
        i = Interface.new
        i.name.should eql "Cosmos::Interface"
        i.target_names.should eql []
        i.thread.should be_nil
        i.connect_on_startup.should be_truthy
        i.auto_reconnect.should be_truthy
        i.reconnect_delay.should eql 5.0
        i.disable_disconnect.should be_falsey
        i.packet_log_writer_pairs.should eql []
        i.routers.should eql []
        i.read_count.should eql 0
        i.write_count.should eql 0
        i.bytes_read.should eql 0
        i.bytes_written.should eql 0
        i.num_clients.should eql 0
        i.read_queue_size.should eql 0
        i.write_queue_size.should eql 0
        i.interfaces.should eql []
      end
    end

    describe "virtual methods" do
      it "should raise an error" do
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
      it "should be true" do
        Interface.new.read_allowed?.should be_truthy
      end
    end

    describe "write_allowed?" do
      it "should be true" do
        Interface.new.write_allowed?.should be_truthy
      end
    end

    describe "write_raw_allowed?" do
      it "should be true" do
        Interface.new.write_raw_allowed?.should be_truthy
      end
    end

    describe "copy_to" do
      it "should copy the interface" do
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
        i2.name.should eql 'TEST'
        i2.target_names.should eql ['TGT1','TGT2']
        i2.thread.should be_nil # Thread does not get copied
        i2.connect_on_startup.should be_falsey
        i2.auto_reconnect.should be_falsey
        i2.reconnect_delay.should eql 1.0
        i2.disable_disconnect.should be_truthy
        i2.packet_log_writer_pairs.should eql [1,2]
        i2.routers.should eql [3,4]
        i2.read_count.should eql 1
        i2.write_count.should eql 2
        i2.bytes_read.should eql 3
        i2.bytes_written.should eql 4
        i2.num_clients.should eql 0 # does not get copied
        i2.read_queue_size.should eql 0 # does not get copied
        i2.write_queue_size.should eql 0 # does not get copied
        i2.interfaces.should eql [5,6]
      end
    end

    describe "post_identify_packet" do
      it "should do nothing" do
        expect { Interface.new.post_identify_packet(nil) }.to_not raise_error
      end
    end

  end
end

