# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/packet_item_limits'

module Cosmos

  describe PacketItemLimits do
    before(:each) do
      @l = PacketItemLimits.new
    end

    describe "values=" do
      it "sets the values Hash" do
        @l.values = {:DEFAULT => [0,1,2,3,4,5]}
        @l.values[:DEFAULT].should eql [0,1,2,3,4,5]
      end

      it "allows nil values" do
        @l.values = nil
        @l.values.should be_nil
      end

      it "complains about non Hash values" do
        expect { @l.values = [] }.to raise_error(ArgumentError, "values must be a Hash but is a Array")
      end

      it "complains about Hash values without a :DEFAULT key" do
        expect { @l.values = {} }.to raise_error(ArgumentError, "values must be a Hash with a :DEFAULT key")
      end
    end

    describe "state=" do
      it "sets the state to a Symbol" do
        PacketItemLimits::LIMITS_STATES.each do |state|
          @l.state = state
          @l.state.should eql state
        end
      end

      it "sets the state to nil" do
        @l.state = nil
        @l.state.should be_nil
      end

      it "complains about bad Symbol states" do
        expect { @l.state = :ORANGE }.to raise_error(ArgumentError, "state must be one of #{PacketItemLimits::LIMITS_STATES} but is ORANGE")
        expect { @l.state = "RED" }.to raise_error(ArgumentError, "state must be one of #{PacketItemLimits::LIMITS_STATES} but is RED")
        expect { @l.state = 5 }.to raise_error(ArgumentError, "state must be one of #{PacketItemLimits::LIMITS_STATES} but is 5")
      end
    end

    describe "response=" do
      it "accepts LimitsResponse instances" do
        r = LimitsResponse.new()
        @l.response = r
        (LimitsResponse === @l.response).should be_truthy
      end

      it "sets the response to nil" do
        @l.response = nil
        @l.response.should be_nil
      end

      it "complains about non LimitsResponse responses" do
        expect { @l.response = "HI" }.to raise_error(ArgumentError, "response must be a Cosmos::LimitsResponse but is a String")
      end
    end

    describe "persistence_setting=" do
      it "accepts persistence_setting as a Fixnum" do
        persistence_setting = 1
        @l.persistence_setting = persistence_setting
        @l.persistence_setting.should eql persistence_setting
      end

      it "complains about persistence_setting = nil" do
        expect { @l.persistence_setting = nil}.to raise_error(ArgumentError, "persistence_setting must be a Fixnum but is a NilClass")
      end

      it "complains about persistence_setting that aren't Fixnum" do
        expect { @l.persistence_setting = 5.5}.to raise_error(ArgumentError, "persistence_setting must be a Fixnum but is a Float")
      end
    end

    describe "persistence_count=" do
      it "accepts persistence_count as a String" do
        persistence_count = 1
        @l.persistence_count = persistence_count
        @l.persistence_count.should eql persistence_count
      end

      it "complains about persistence_count = nil" do
        expect { @l.persistence_count = nil}.to raise_error(ArgumentError, "persistence_count must be a Fixnum but is a NilClass")
      end

      it "complains about persistence_count that aren't Fixnum" do
        expect { @l.persistence_count = 5.5}.to raise_error(ArgumentError, "persistence_count must be a Fixnum but is a Float")
      end
    end

    describe "clone" do
      it "duplicates the entire Limits" do
        l2 = @l.clone
        @l.values.should eql l2.values
        @l.response.should eql l2.response
        @l.state.should eql l2.state
        @l.persistence_count.should eql l2.persistence_count
        @l.persistence_setting.should eql l2.persistence_setting
      end
    end

    describe "to_hash" do
      it "creates a Hash" do
        @l.enabled = true
        @l.values = {:DEFAULT => [0,1,2,3,4,5]}
        @l.state = :RED_LOW
        r = LimitsResponse.new()
        @l.response = r
        @l.persistence_setting = 1
        @l.persistence_count = 2

        hash = @l.to_hash
        hash.keys.length.should eql 6
        hash.keys.should include('values','enabled','state','response','persistence_setting','persistence_count')
        hash["enabled"].should be_truthy
        hash["values"].should include(:DEFAULT => [0,1,2,3,4,5])
        hash["state"].should eql :RED_LOW
        hash["response"].should match "LimitsResponse"
        hash["persistence_setting"].should eql 1
        hash["persistence_count"].should eql 2
      end

      it "creates a Hash without a response" do
        @l.enabled = true
        @l.values = {:DEFAULT => [0,1,2,3,4,5]}
        @l.state = :RED_LOW
        @l.persistence_setting = 1
        @l.persistence_count = 2

        hash = @l.to_hash
        hash["enabled"].should be_truthy
        hash["values"].should include(:DEFAULT => [0,1,2,3,4,5])
        hash["state"].should eql :RED_LOW
        hash["response"].should be_nil
        hash["persistence_setting"].should eql 1
        hash["persistence_count"].should eql 2
      end
    end

  end
end
