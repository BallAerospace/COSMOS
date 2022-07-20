# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3'
require 'openc3/packets/packet_item_limits'

module OpenC3
  describe PacketItemLimits do
    before(:each) do
      @l = PacketItemLimits.new
    end

    describe "values=" do
      it "sets the values Hash" do
        @l.values = { :DEFAULT => [0, 1, 2, 3, 4, 5] }
        expect(@l.values[:DEFAULT]).to eql [0, 1, 2, 3, 4, 5]
      end

      it "allows nil values" do
        @l.values = nil
        expect(@l.values).to be_nil
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
          expect(@l.state).to eql state
        end
      end

      it "sets the state to nil" do
        @l.state = nil
        expect(@l.state).to be_nil
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
        expect(LimitsResponse === @l.response).to be true
      end

      it "sets the response to nil" do
        @l.response = nil
        expect(@l.response).to be_nil
      end

      it "complains about non LimitsResponse responses" do
        expect { @l.response = "HI" }.to raise_error(ArgumentError, "response must be a OpenC3::LimitsResponse but is a String")
      end
    end

    describe "persistence_setting=" do
      it "accepts persistence_setting as a Fixnum" do
        persistence_setting = 1
        @l.persistence_setting = persistence_setting
        expect(@l.persistence_setting).to eql persistence_setting
      end

      it "complains about persistence_setting = nil" do
        if 0.class == Integer
          # Ruby version >= 2.4.0
          expect { @l.persistence_setting = nil }.to raise_error(ArgumentError, "persistence_setting must be an Integer but is a NilClass")
        else
          # Ruby version < 2.4.0
          expect { @l.persistence_setting = nil }.to raise_error(ArgumentError, "persistence_setting must be a Fixnum but is a NilClass")
        end
      end

      if 0.class == Integer
        # Ruby version >= 2.4.0
        it "complains about persistence_setting that aren't Integer" do
          expect { @l.persistence_setting = 5.5 }.to raise_error(ArgumentError, "persistence_setting must be an Integer but is a Float")
        end
      else
        # Ruby version < 2.4.0
        it "complains about persistence_setting that aren't Fixnum" do
          expect { @l.persistence_setting = 5.5 }.to raise_error(ArgumentError, "persistence_setting must be a Fixnum but is a Float")
        end
      end
    end

    describe "persistence_count=" do
      it "accepts persistence_count as a String" do
        persistence_count = 1
        @l.persistence_count = persistence_count
        expect(@l.persistence_count).to eql persistence_count
      end

      it "complains about persistence_count = nil" do
        if 0.class == Integer
          # Ruby version >= 2.4.0
          expect { @l.persistence_count = nil }.to raise_error(ArgumentError, "persistence_count must be an Integer but is a NilClass")
        else
          # Ruby version < 2.4.0
          expect { @l.persistence_count = nil }.to raise_error(ArgumentError, "persistence_count must be a Fixnum but is a NilClass")
        end
      end

      if 0.class == Integer
        it "complains about persistence_count that aren't Integer" do
          expect { @l.persistence_count = 5.5 }.to raise_error(ArgumentError, "persistence_count must be an Integer but is a Float")
        end
      else
        # Ruby version < 2.4.0
        it "complains about persistence_count that aren't Fixnum" do
          expect { @l.persistence_count = 5.5 }.to raise_error(ArgumentError, "persistence_count must be a Fixnum but is a Float")
        end
      end
    end

    describe "clone" do
      it "duplicates the entire Limits" do
        l2 = @l.clone
        expect(@l.values).to eql l2.values
        expect(@l.response).to eql l2.response
        expect(@l.state).to eql l2.state
        expect(@l.persistence_count).to eql l2.persistence_count
        expect(@l.persistence_setting).to eql l2.persistence_setting
      end
    end

    describe "as_json" do
      it "creates a Hash" do
        @l.enabled = true
        @l.values = { :DEFAULT => [0, 1, 2, 3, 4, 5] }
        @l.state = :RED_LOW
        r = LimitsResponse.new()
        @l.response = r
        @l.persistence_setting = 1
        @l.persistence_count = 2

        hash = @l.as_json(:allow_nan => true)
        expect(hash.keys.length).to eql 6
        expect(hash.keys).to include('values', 'enabled', 'state', 'response', 'persistence_setting', 'persistence_count')
        expect(hash["enabled"]).to be true
        expect(hash["values"]).to include(:DEFAULT => [0, 1, 2, 3, 4, 5])
        expect(hash["state"]).to eql :RED_LOW
        expect(hash["response"]).to match("LimitsResponse")
        expect(hash["persistence_setting"]).to eql 1
        expect(hash["persistence_count"]).to eql 2
      end

      it "creates a Hash without a response" do
        @l.enabled = true
        @l.values = { :DEFAULT => [0, 1, 2, 3, 4, 5] }
        @l.state = :RED_LOW
        @l.persistence_setting = 1
        @l.persistence_count = 2

        hash = @l.as_json(:allow_nan => true)
        expect(hash["enabled"]).to be true
        expect(hash["values"]).to include(:DEFAULT => [0, 1, 2, 3, 4, 5])
        expect(hash["state"]).to eql :RED_LOW
        expect(hash["response"]).to be_nil
        expect(hash["persistence_setting"]).to eql 1
        expect(hash["persistence_count"]).to eql 2
      end
    end

    describe "self.from_json" do
      it "converts empty object from JSON" do
        pil = PacketItemLimits.from_json(@l.as_json(:allow_nan => true))
        expect(pil.enabled).to eql @l.enabled
        expect(pil.values).to eql @l.values
        expect(pil.state).to eql @l.state
        # We don't reconsitute the LimitsResponse
        expect(pil.persistence_setting).to eql @l.persistence_setting
        expect(pil.persistence_count).to eql @l.persistence_count
      end

      it "converts populated object from JSON" do
        @l.enabled = true
        @l.values = { :DEFAULT => [0, 1, 4, 5, 2, 3], :TVAC => [0, 1, 4, 5, 2, 3] }
        @l.state = :RED_LOW
        r = LimitsResponse.new()
        @l.response = r
        @l.persistence_setting = 10
        @l.persistence_count = 20
        pil = PacketItemLimits.from_json(@l.as_json(:allow_nan => true))
        expect(pil.enabled).to eql @l.enabled
        expect(pil.values).to eql @l.values
        expect(pil.state).to eql @l.state
        # We don't reconsitute the LimitsResponse
        expect(pil.persistence_setting).to eql @l.persistence_setting
        expect(pil.persistence_count).to eql @l.persistence_count
      end
    end
  end
end
