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
require 'cosmos/packets/packet_item'
require 'cosmos/conversions/generic_conversion'

module Cosmos

  describe PacketItem do
    before(:each) do
      @pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
    end

    describe "format_string=" do
      it "sets the format_string" do
        @pi.format_string = "%5.1f"
        expect(@pi.format_string).to eql "%5.1f"
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
      end

      it "sets the read_conversion to nil" do
        @pi.read_conversion = nil
        expect(@pi.read_conversion).to be_nil
      end

      it "complains about non Conversion read_conversions" do
        expect { @pi.read_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: read_conversion must be a Cosmos::Conversion but is a String")
      end
    end

    describe "write_conversion=" do
      it "accepts Conversion instances" do
        c = GenericConversion.new("value / 2")
        @pi.write_conversion = c
        expect(@pi.write_conversion.to_s == c.to_s).to be true
      end

      it "sets the write_conversion to nil" do
        @pi.write_conversion = nil
        expect(@pi.write_conversion).to be_nil
      end

      it "complains about non Conversion write_conversions" do
        expect { @pi.write_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: write_conversion must be a Cosmos::Conversion but is a String")
      end
    end

    describe "id_value=" do
      it "accepts id values according to data_type" do
        @pi.id_value = 10
        expect(@pi.id_value).to eql 10
        @pi.data_type = :FLOAT
        @pi.id_value = 10.0
        expect(@pi.id_value).to eql 10.0
        @pi.data_type = :STRING
        @pi.id_value = "HI"
        expect(@pi.id_value).to eql "HI"
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
        states = {"TRUE"=>1, "FALSE"=>0}
        @pi.states = states
        expect(@pi.states).to eql states
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
      end

      it "sets the description to nil" do
        @pi.description = nil
        expect(@pi.description).to be_nil
      end

      it "complains about description that aren't Strings" do
        expect { @pi.description = 5.1}.to raise_error(ArgumentError, "#{@pi.name}: description must be a String but is a Float")
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
        expect { @pi.units_full = 5.1}.to raise_error(ArgumentError, "#{@pi.name}: units_full must be a String but is a Float")
      end
    end

    describe "units=" do
      it "accepts units as a String" do
        units = "V"
        @pi.units = units
        expect(@pi.units).to eql units
      end

      it "sets the units to nil" do
        @pi.units = nil
        expect(@pi.units).to be_nil
      end

      it "complains about units that aren't Strings" do
        expect { @pi.units = 5.1}.to raise_error(ArgumentError, "#{@pi.name}: units must be a String but is a Float")
      end
    end

    describe "default=" do
      it "accepts default according to the data_type" do
        pi = PacketItem.new("test", 0, 8, :INT, :BIG_ENDIAN, 16)
        pi.default = [1, -1]
        expect(pi.default).to eql [1, -1]
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.default = 0x01020304
        expect(pi.default).to eql 0x01020304
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        expect(pi.default).to eql 5.5
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = "HI"
        expect(pi.default).to eql "HI"
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
        expect { pi.check_default_and_range_data_types  }.to_not raise_error
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        expect { pi.check_default_and_range_data_types  }.to_not raise_error
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
        expect { pi.check_default_and_range_data_types  }.to_not raise_error
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
        expect { @pi.range = 5.1}.to raise_error(ArgumentError, "#{@pi.name}: range must be a Range but is a Float")
      end
    end

    describe "hazardous=" do
      it "accepts hazardous as a Hash" do
        hazardous = {"TRUE"=>nil,"FALSE"=>"NO FALSE ALLOWED"}
        @pi.hazardous = hazardous
        expect(@pi.hazardous).to eql hazardous
        expect(@pi.hazardous["TRUE"]).to eql hazardous["TRUE"]
        expect(@pi.hazardous["FALSE"]).to eql hazardous["FALSE"]
      end

      it "sets hazardous to nil" do
        @pi.hazardous = nil
        expect(@pi.hazardous).to be_nil
      end

      it "complains about hazardous that aren't Hashes" do
        expect { @pi.hazardous = ""}.to raise_error(ArgumentError, "#{@pi.name}: hazardous must be a Hash but is a String")
      end
    end

    describe "state_colors=" do
      it "accepts state_colors as a Hash" do
        state_colors = {"TRUE"=>:GREEN, "FALSE"=>:RED}
        @pi.state_colors = state_colors
        expect(@pi.state_colors).to eql state_colors
      end

      it "sets the state_colors to nil" do
        @pi.state_colors = nil
        expect(@pi.state_colors).to be_nil
      end

      it "complains about state_colors that aren't Hashes" do
        expect { @pi.state_colors = ""}.to raise_error(ArgumentError, "#{@pi.name}: state_colors must be a Hash but is a String")
      end
    end

    describe "limits=" do
      it "accepts limits as a PacketItemLimits" do
        limits = PacketItemLimits.new
        @pi.limits = limits
      end

      it "sets the limits to nil" do
        @pi.limits = nil
        expect(@pi.limits).to be_nil
      end

      it "complains about limits that aren't PacketItemLimits" do
        expect { @pi.limits = ""}.to raise_error(ArgumentError, "#{@pi.name}: limits must be a PacketItemLimits but is a String")
      end
    end

    describe "meta" do
      it "allows adding items to the meta hash" do
        @pi.meta['TYPE'] = 'float32'
        expect(@pi.meta['TYPE']).to eql 'float32'
      end
    end

    describe "clone" do
      it "duplicates the entire PacketItem" do
        pi2 = @pi.clone
        expect(@pi == pi2).to be true
      end
    end

    describe "to_hash" do
      it "converts to a Hash" do
        @pi.format_string = "%5.1f"
        @pi.id_value = 10
        @pi.states = {"TRUE"=>1, "FALSE"=>0}
        @pi.read_conversion = GenericConversion.new("value / 2")
        @pi.write_conversion = GenericConversion.new("value * 2")
        @pi.description = "description"
        @pi.units_full = "Celcius"
        @pi.units = "C"
        @pi.default = 0
        @pi.range = (0..100)
        @pi.required = true
        @pi.hazardous = {"TRUE"=>nil,"FALSE"=>"NO!"}
        @pi.state_colors = {"TRUE"=>:GREEN, "FALSE"=>:RED}
        @pi.limits = PacketItemLimits.new

        hash = @pi.to_hash
        expect(hash.keys.length).to eql 22
        # Check the values from StructureItem
        expect(hash.keys).to include('name','bit_offset','bit_size','data_type','endianness','array_size','overflow')
        expect(hash["name"]).to eql "TEST"
        expect(hash["bit_offset"]).to eql 0
        expect(hash["bit_size"]).to eql 32
        expect(hash["data_type"]).to eql :UINT
        expect(hash["endianness"]).to eql :BIG_ENDIAN
        expect(hash["array_size"]).to be_nil
        expect(hash["overflow"]).to eql :ERROR
        # Check the unique PacketItem values
        expect(hash.keys).to include('format_string','read_conversion','write_conversion','id_value','states','description','units_full','units','default','range','required','hazardous','state_colors','limits')
        expect(hash["format_string"]).to eql "%5.1f"
        expect(hash["read_conversion"]).to match "value / 2"
        expect(hash["write_conversion"]).to match /value \* 2/
        expect(hash["id_value"]).to eql 10
        expect(hash["states"]).to include("TRUE"=>1,"FALSE"=>0)
        expect(hash["description"]).to eql "description"
        expect(hash["units_full"]).to eql "Celcius"
        expect(hash["units"]).to eql "C"
        expect(hash["default"]).to eql 0
        expect(hash["range"]).to eql (0..100)
        expect(hash["required"]).to be true
        expect(hash["hazardous"]).to include("TRUE"=>nil,"FALSE"=>"NO!")
        expect(hash["state_colors"]).to include("TRUE"=>:GREEN,"FALSE"=>:RED)
        expect(hash["limits"]).to eql PacketItemLimits.new.to_hash
        expect(hash["meta"]).to be_nil
      end

      it "converts to a Hash with no conversions" do
        hash = @pi.to_hash
        expect(hash["read_conversion"]).to be_nil
        expect(hash["write_conversion"]).to be_nil
      end
    end

  end
end
