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
require 'openc3/packets/packet_item'
require 'openc3/conversions/generic_conversion'

module OpenC3
  describe PacketItem do
    before(:each) do
      @pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
    end

    describe "format_string=" do
      it "sets the format_string" do
        @pi.format_string = "%5.1f"
        expect(@pi.format_string).to eql "%5.1f"
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/FORMAT_STRING %5.1f/)
      end

      it "sets the format_string to nil" do
        @pi.format_string = nil
        expect(@pi.format_string).to be_nil
      end

      it "complains about non String format_strings" do
        expect { @pi.format_string = 5.1 }.to raise_error(ArgumentError, "#{@pi.name}: format_string must be a String but is a Float")
      end

      it "complains about badly formatted format_strings" do
        expect { @pi.format_string = "%" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '%'")
        expect { @pi.format_string = "5" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '5'")
        expect { @pi.format_string = "%Q" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '%Q'")
      end
    end

    describe "read_conversion=" do
      it "accepts Conversion instances" do
        c = GenericConversion.new("value / 2")
        @pi.read_conversion = c
        expect(@pi.read_conversion.to_s == c.to_s).to be true
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/GENERIC_READ_CONVERSION_START/)
        expect(config).to match(/value \/ 2/)
        expect(config).to match(/GENERIC_READ_CONVERSION_END/)
      end

      it "sets the read_conversion to nil" do
        @pi.read_conversion = nil
        expect(@pi.read_conversion).to be_nil
      end

      it "complains about non Conversion read_conversions" do
        expect { @pi.read_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: read_conversion must be a OpenC3::Conversion but is a String")
      end
    end

    describe "write_conversion=" do
      it "accepts Conversion instances" do
        c = GenericConversion.new("value / 2")
        @pi.write_conversion = c
        expect(@pi.write_conversion.to_s == c.to_s).to be true
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/GENERIC_WRITE_CONVERSION_START/)
        expect(config).to match(/value \/ 2/)
        expect(config).to match(/GENERIC_WRITE_CONVERSION_END/)
      end

      it "sets the write_conversion to nil" do
        @pi.write_conversion = nil
        expect(@pi.write_conversion).to be_nil
      end

      it "complains about non Conversion write_conversions" do
        expect { @pi.write_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: write_conversion must be a OpenC3::Conversion but is a String")
      end
    end

    describe "id_value=" do
      it "accepts id values according to data_type" do
        @pi.range = (0..10)
        @pi.id_value = 10
        expect(@pi.id_value).to eql 10
        @pi.data_type = :FLOAT
        @pi.id_value = 10.0
        expect(@pi.id_value).to eql 10.0
        expect(@pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/ID_PARAMETER TEST 0 32 FLOAT 0 10 10.0/)
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/ID_ITEM TEST 0 32 FLOAT 10.0/)
        @pi.data_type = :STRING
        @pi.id_value = "HI"
        expect(@pi.id_value).to eql "HI"
        expect(@pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/ID_PARAMETER TEST 0 32 STRING "HI"/)
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/ID_ITEM TEST 0 32 STRING "HI"/)
        @pi.id_value = "\xDE\xAD\xBE\xEF" # binary
        expect(@pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/ID_PARAMETER TEST 0 32 STRING 0xDEADBEEF/)
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/ID_ITEM TEST 0 32 STRING 0xDEADBEEF/)
      end

      it "sets the id_value to nil" do
        @pi.id_value = nil
        expect(@pi.id_value).to be_nil
      end

      it "complains about id_values that don't match the data_type" do
        expect { @pi.id_value = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: Invalid value: HI for data type: UINT")
        @pi.data_type = :FLOAT
        expect { @pi.id_value = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: Invalid value: HI for data type: FLOAT")
      end
    end

    describe "states=" do
      it "accepts states as a Hash" do
        states = { "TRUE" => 1, "FALSE" => 0 }
        @pi.states = states
        expect(@pi.states).to eql states
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/STATE TRUE 1/)
        expect(config).to match(/STATE FALSE 0/)
      end

      it "sets the states to nil" do
        @pi.states = nil
        expect(@pi.states).to be_nil
      end

      it "complains about states that aren't Hashes" do
        expect { @pi.states = "state" }.to raise_error(ArgumentError, "#{@pi.name}: states must be a Hash but is a String")
      end
    end

    describe "description=" do
      it "accepts description as a String" do
        description = "this is it"
        @pi.description = description
        expect(@pi.description).to eql description
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/ITEM TEST 0 32 UINT "this is it"/)
      end

      it "sets the description to nil" do
        @pi.description = nil
        expect(@pi.description).to be_nil
      end

      it "complains about description that aren't Strings" do
        expect { @pi.description = 5.1 }.to raise_error(ArgumentError, "#{@pi.name}: description must be a String but is a Float")
      end
    end

    describe "units_full=" do
      it "accepts units_full as a String" do
        units_full = "Volts"
        @pi.units_full = units_full
        expect(@pi.units_full).to eql units_full
      end

      it "sets the units_full to nil" do
        @pi.units_full = nil
        expect(@pi.units_full).to be_nil
      end

      it "complains about units_full that aren't Strings" do
        expect { @pi.units_full = 5.1 }.to raise_error(ArgumentError, "#{@pi.name}: units_full must be a String but is a Float")
      end
    end

    describe "units=" do
      it "accepts units as a String" do
        units = "V"
        @pi.units = units
        expect(@pi.units).to eql units
        @pi.units_full = "Volts"
        expect(@pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/UNITS Volts V/)
      end

      it "sets the units to nil" do
        @pi.units = nil
        expect(@pi.units).to be_nil
      end

      it "complains about units that aren't Strings" do
        expect { @pi.units = 5.1 }.to raise_error(ArgumentError, "#{@pi.name}: units must be a String but is a Float")
      end
    end

    describe "default=" do
      it "accepts default according to the data_type" do
        pi = PacketItem.new("test", 0, 8, :INT, :BIG_ENDIAN, 16)
        pi.default = [1, -1]
        expect(pi.default).to eql [1, -1]
        expect(pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/ARRAY_PARAMETER TEST 0 8 INT 16/)
        expect(pi.to_config(:TELEMETRY, :BIG_ENDIAN)).to match(/ARRAY_ITEM TEST 0 8 INT 16/)
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.range = (0..10)
        pi.default = 0x01020304
        expect(pi.default).to eql 0x01020304
        expect(pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/PARAMETER TEST 0 32 UINT 0 10 16909060/)
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.range = (-10..10)
        pi.default = 5.5
        expect(pi.default).to eql 5.5
        expect(pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/PARAMETER TEST 0 32 FLOAT -10 10 5.5/)
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = "HI"
        expect(pi.default).to eql "HI"
        expect(pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/PARAMETER TEST 0 32 STRING "HI"/)
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = "\xDE\xAD\xBE\xEF"
        expect(pi.to_config(:COMMAND, :BIG_ENDIAN)).to match(/PARAMETER TEST 0 32 STRING 0xDEADBEEF/)
      end

      it "sets the default to nil" do
        @pi.default = nil
        expect(@pi.default).to be_nil
      end
    end

    describe "check_default_and_range_data_types" do
      it "complains about default not matching data_type" do
        pi = PacketItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 16)
        pi.default = 1.1
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be an Array but is a Float")
        pi = PacketItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 16)
        pi.default = []
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be a Integer but is a Float")
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.default = 5
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = "test"
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be a Float but is a String")
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = 5.1
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be a String but is a Float")
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = ''
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :BLOCK, :BIG_ENDIAN, nil)
        pi.default = 5.5
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be a String but is a Float")
        pi = PacketItem.new("test", 0, 32, :BLOCK, :BIG_ENDIAN, nil)
        pi.default = ''
        expect { pi.check_default_and_range_data_types }.to_not raise_error
      end

      it "complains about range not matching data_type" do
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.default = 5
        pi.range = (5.5..10)
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: minimum must be a Integer but is a Float")
        pi.range = (5..10.5)
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: maximum must be a Integer but is a Float")
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        pi.range = (5..10)
        expect { pi.check_default_and_range_data_types }.to_not raise_error
        pi.range = ('a'..'z')
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: minimum must be a Float but is a String")
        pi.range = (1.0..Rational(2))
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: maximum must be a Float but is a Rational")
      end
    end

    describe "range=" do
      it "accepts range as a String" do
        range = (0..1)
        @pi.range = range
        expect(@pi.range).to eql range
      end

      it "sets the range to nil" do
        @pi.range = nil
        expect(@pi.range).to be_nil
      end

      it "complains about ranges that aren't Ranges" do
        expect { @pi.range = 5.1 }.to raise_error(ArgumentError, "#{@pi.name}: range must be a Range but is a Float")
      end
    end

    describe "hazardous=" do
      it "accepts hazardous as a Hash" do
        hazardous = { "TRUE" => nil, "FALSE" => "NO FALSE ALLOWED" }
        @pi.hazardous = hazardous
        expect(@pi.hazardous).to eql hazardous
        expect(@pi.hazardous["TRUE"]).to eql hazardous["TRUE"]
        expect(@pi.hazardous["FALSE"]).to eql hazardous["FALSE"]

        @pi.range = (0..1)
        @pi.states = { "TRUE" => 1, "FALSE" => 0 }
        config = @pi.to_config(:COMMAND, :BIG_ENDIAN)
        expect(config).to match(/STATE TRUE 1/)
        expect(config).to match(/STATE FALSE 0 HAZARDOUS "NO FALSE ALLOWED"/)
      end

      it "sets hazardous to nil" do
        @pi.hazardous = nil
        expect(@pi.hazardous).to be_nil
      end

      it "complains about hazardous that aren't Hashes" do
        expect { @pi.hazardous = "" }.to raise_error(ArgumentError, "#{@pi.name}: hazardous must be a Hash but is a String")
      end
    end

    describe "state_colors=" do
      it "accepts state_colors as a Hash" do
        state_colors = { "TRUE" => :GREEN, "FALSE" => :RED }
        @pi.state_colors = state_colors
        expect(@pi.state_colors).to eql state_colors

        @pi.range = (0..1)
        @pi.states = { "TRUE" => 1, "FALSE" => 0 }
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/STATE TRUE 1 GREEN/)
        expect(config).to match(/STATE FALSE 0 RED/)
      end

      it "sets the state_colors to nil" do
        @pi.state_colors = nil
        expect(@pi.state_colors).to be_nil
      end

      it "complains about state_colors that aren't Hashes" do
        expect { @pi.state_colors = "" }.to raise_error(ArgumentError, "#{@pi.name}: state_colors must be a Hash but is a String")
      end
    end

    describe "limits=" do
      it "accepts limits as a PacketItemLimits" do
        limits = PacketItemLimits.new
        limits.values = { DEFAULT: [10, 20, 80, 90, 40, 50], TVAC: [100, 200, 800, 900] }
        @pi.limits = limits
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/LIMITS DEFAULT 1 DISABLED 10 20 80 90 40 50/)
        expect(config).to match(/LIMITS TVAC 1 DISABLED 100 200 800 900/)
        @pi.limits.enabled = true
        @pi.limits.persistence_setting = 3
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/LIMITS DEFAULT 3 ENABLED 10 20 80 90 40 50/)
        expect(config).to match(/LIMITS TVAC 3 ENABLED 100 200 800 900/)
      end

      it "sets the limits to nil" do
        @pi.limits = nil
        expect(@pi.limits).to be_nil
      end

      it "complains about limits that aren't PacketItemLimits" do
        expect { @pi.limits = "" }.to raise_error(ArgumentError, "#{@pi.name}: limits must be a PacketItemLimits but is a String")
      end
    end

    describe "meta=" do
      it "only allows a hash" do
        expect { @pi.meta = 1 }.to raise_error(ArgumentError, /must be a Hash/)
      end

      it "sets the meta hash" do
        @pi.meta = { 'TYPE' => ['float32', 'uint8'], 'TEST' => ["test string"] }
        expect(@pi.meta['TYPE']).to eql ['float32', 'uint8']
        expect(@pi.meta['TEST']).to eql ["test string"]
        config = @pi.to_config(:TELEMETRY, :BIG_ENDIAN)
        expect(config).to match(/META TYPE float32 uint8/)
        expect(config).to match(/META TEST "test string"/)
        @pi.meta = nil # Clear the meta hash
        expect(@pi.meta.empty?).to be true # Clearing it results in empty hash
      end
    end

    describe "clone" do
      it "duplicates the entire PacketItem" do
        pi2 = @pi.clone
        expect(@pi < pi2).to be true
      end
    end

    describe "as_json" do
      it "converts to a Hash" do
        @pi.format_string = "%5.1f"
        @pi.id_value = 10
        @pi.array_size = 64
        @pi.states = { "TRUE" => 1, "FALSE" => 0 }
        @pi.read_conversion = GenericConversion.new("value / 2")
        @pi.write_conversion = GenericConversion.new("value * 2")
        @pi.description = "description"
        @pi.units_full = "Celsius"
        @pi.units = "C"
        @pi.default = 0
        @pi.range = (0..100)
        @pi.required = true
        @pi.hazardous = { "TRUE" => nil, "FALSE" => "NO!" }
        @pi.state_colors = { "TRUE" => :GREEN, "FALSE" => :RED }
        @pi.limits = PacketItemLimits.new

        hash = @pi.as_json(:allow_nan => true)
        expect(hash["name"]).to eql "TEST"
        expect(hash["bit_offset"]).to eql 0
        expect(hash["bit_size"]).to eql 32
        expect(hash["data_type"]).to eql 'UINT'
        expect(hash["endianness"]).to eql 'BIG_ENDIAN'
        expect(hash["array_size"]).to eql 64
        expect(hash["overflow"]).to eql 'ERROR'
        expect(hash["format_string"]).to eql "%5.1f"
        expect(hash["read_conversion"]).to_not be_nil
        expect(hash["write_conversion"]).to_not be_nil
        expect(hash["id_value"]).to eql 10
        true_hash = { "value" => 1, "color" => "GREEN" }
        false_hash = { "value" => 0, "hazardous" => "NO!", "color" => "RED"}
        expect(hash["states"]).to eql({ "TRUE" => true_hash, "FALSE" => false_hash })
        expect(hash["description"]).to eql "description"
        expect(hash["units_full"]).to eql "Celsius"
        expect(hash["units"]).to eql "C"
        expect(hash["default"]).to eql 0
        # range turns into minimum and maximum
        expect(hash["minimum"]).to eql 0
        expect(hash["maximum"]).to eql 100
        expect(hash["required"]).to be true
        expect(hash["limits"]).to be_nil
        expect(hash["meta"]).to be_nil
      end
    end

    describe "self.from_hash" do
      it "creates empty PacketItem from hash" do
        item = PacketItem.from_json(@pi.as_json(:allow_nan => true))
        expect(item.name).to eql @pi.name
        expect(item.bit_offset).to eql @pi.bit_offset
        expect(item.bit_size).to eql @pi.bit_size
        expect(item.data_type).to eql @pi.data_type
        expect(item.endianness).to eql @pi.endianness
        expect(item.array_size).to eql @pi.array_size
        expect(item.overflow).to eql @pi.overflow
        expect(item.format_string).to eql @pi.format_string
        # conversions don't round trip
        # expect(item.read_conversion).to eql @pi.read_conversion
        # expect(item.write_conversion).to eql @pi.write_conversion
        expect(item.id_value).to eql @pi.id_value
        expect(item.states).to eql @pi.states
        expect(item.description).to eql @pi.description
        expect(item.units_full).to eql @pi.units_full
        expect(item.units).to eql @pi.units
        expect(item.default).to eql @pi.default
        expect(item.range).to eql @pi.range
        expect(item.required).to eql @pi.required
        expect(item.state_colors).to eql @pi.state_colors
        expect(item.hazardous).to eql @pi.hazardous
        expect(item.limits.enabled).to eql @pi.limits.enabled
        expect(item.limits.persistence_setting).to eql @pi.limits.persistence_setting
        expect(item.limits.values).to eql @pi.limits.values
        expect(item.meta).to eql @pi.meta
      end

      it "converts a populated item to and from JSON" do
        @pi.format_string = "%5.1f"
        @pi.id_value = 10
        @pi.states = { "TRUE" => 1, "FALSE" => 0 }
        @pi.read_conversion = GenericConversion.new("value / 2")
        @pi.write_conversion = PolynomialConversion.new(1, 2, 3)
        @pi.description = "description"
        @pi.units_full = "Celsius"
        @pi.units = "C"
        @pi.default = 0
        @pi.range = (0..100)
        @pi.required = true
        @pi.hazardous = { "TRUE" => nil, "FALSE" => "NO!" }
        @pi.state_colors = { "TRUE" => :GREEN, "FALSE" => :RED }
        @pi.limits = PacketItemLimits.new
        @pi.limits.values = { DEFAULT: [10, 20, 80, 90, 40, 50], TVAC: [100, 200, 800, 900] }
        item = PacketItem.from_json(@pi.as_json(:allow_nan => true))
        expect(item.name).to eql @pi.name
        expect(item.bit_offset).to eql @pi.bit_offset
        expect(item.bit_size).to eql @pi.bit_size
        expect(item.data_type).to eql @pi.data_type
        expect(item.endianness).to eql @pi.endianness
        expect(item.array_size).to eql @pi.array_size
        expect(item.overflow).to eql @pi.overflow
        expect(item.format_string).to eql @pi.format_string
        expect(item.read_conversion).to be_a GenericConversion
        expect(item.write_conversion).to be_a PolynomialConversion
        expect(item.id_value).to eql @pi.id_value
        expect(item.states).to eql @pi.states
        expect(item.description).to eql @pi.description
        expect(item.units_full).to eql @pi.units_full
        expect(item.units).to eql @pi.units
        expect(item.default).to eql @pi.default
        expect(item.range).to eql @pi.range
        expect(item.required).to eql @pi.required
        expect(item.state_colors).to eql @pi.state_colors
        expect(item.hazardous).to eql @pi.hazardous
        expect(item.limits.enabled).to eql @pi.limits.enabled
        expect(item.limits.persistence_setting).to eql @pi.limits.persistence_setting
        expect(item.limits.values).to eql @pi.limits.values
        expect(item.meta).to eql @pi.meta
      end
    end
  end
end
