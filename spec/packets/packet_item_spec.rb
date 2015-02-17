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
      it "should set the format_string" do
        @pi.format_string = "%5.1f"
        @pi.format_string.should eql "%5.1f"
      end

      it "should set the format_string to nil" do
        @pi.format_string = nil
        @pi.format_string.should be_nil
      end

      it "should complain about non String format_strings" do
        expect { @pi.format_string = 5 }.to raise_error(ArgumentError, "#{@pi.name}: format_string must be a String but is a Fixnum")
      end

      it "should complain about badly formatted format_strings" do
        expect { @pi.format_string = "%" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '%'")
        expect { @pi.format_string = "5" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '5'")
        expect { @pi.format_string = "%Q" }.to raise_error(ArgumentError, "#{@pi.name}: format_string invalid '%Q'")
      end
    end

    describe "read_conversion=" do
      it "should accept Conversion instances" do
        c = GenericConversion.new("value / 2")
        @pi.read_conversion = c
        (@pi.read_conversion.to_s == c.to_s).should be_truthy
      end

      it "should set the read_conversion to nil" do
        @pi.read_conversion = nil
        @pi.read_conversion.should be_nil
      end

      it "should complain about non Conversion read_conversions" do
        expect { @pi.read_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: read_conversion must be a Cosmos::Conversion but is a String")
      end
    end

    describe "write_conversion=" do
      it "should accept Conversion instances" do
        c = GenericConversion.new("value / 2")
        @pi.write_conversion = c
        (@pi.write_conversion.to_s == c.to_s).should be_truthy
      end

      it "should set the write_conversion to nil" do
        @pi.write_conversion = nil
        @pi.write_conversion.should be_nil
      end

      it "should complain about non Conversion write_conversions" do
        expect { @pi.write_conversion = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: write_conversion must be a Cosmos::Conversion but is a String")
      end
    end

    describe "id_value=" do
      it "should accept id values according to data_type" do
        @pi.id_value = 10
        @pi.id_value.should eql 10
        @pi.data_type = :FLOAT
        @pi.id_value = 10.0
        @pi.id_value.should eql 10.0
        @pi.data_type = :STRING
        @pi.id_value = "HI"
        @pi.id_value.should eql "HI"
      end

      it "should set the id_value to nil" do
        @pi.id_value = nil
        @pi.id_value.should be_nil
      end

      it "should complain about id_values that don't match the data_type" do
        expect { @pi.id_value = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: Invalid value: HI for data type: UINT")
        @pi.data_type = :FLOAT
        expect { @pi.id_value = "HI" }.to raise_error(ArgumentError, "#{@pi.name}: Invalid value: HI for data type: FLOAT")
      end
    end

    describe "states=" do
      it "should accept states as a Hash" do
        states = {"TRUE"=>1, "FALSE"=>0}
        @pi.states = states
        @pi.states.should eql states
      end

      it "should set the states to nil" do
        @pi.states = nil
        @pi.states.should be_nil
      end

      it "should complain about states that aren't Hashes" do
        expect { @pi.states = "state" }.to raise_error(ArgumentError, "#{@pi.name}: states must be a Hash but is a String")
      end
    end

    describe "description=" do
      it "should accept description as a String" do
        description = "this is it"
        @pi.description = description
        @pi.description.should eql description
      end

      it "should set the description to nil" do
        @pi.description = nil
        @pi.description.should be_nil
      end

      it "should complain about description that aren't Strings" do
        expect { @pi.description = 5}.to raise_error(ArgumentError, "#{@pi.name}: description must be a String but is a Fixnum")
      end
    end

    describe "units_full=" do
      it "should accept units_full as a String" do
        units_full = "Volts"
        @pi.units_full = units_full
        @pi.units_full.should eql units_full
      end

      it "should set the units_full to nil" do
        @pi.units_full = nil
        @pi.units_full.should be_nil
      end

      it "should complain about units_full that aren't Strings" do
        expect { @pi.units_full = 5}.to raise_error(ArgumentError, "#{@pi.name}: units_full must be a String but is a Fixnum")
      end
    end

    describe "units=" do
      it "should accept units as a String" do
        units = "V"
        @pi.units = units
        @pi.units.should eql units
      end

      it "should set the units to nil" do
        @pi.units = nil
        @pi.units.should be_nil
      end

      it "should complain about units that aren't Strings" do
        expect { @pi.units = 5}.to raise_error(ArgumentError, "#{@pi.name}: units must be a String but is a Fixnum")
      end
    end

    describe "default=" do
      it "should accept default according to the data_type" do
        pi = PacketItem.new("test", 0, 8, :INT, :BIG_ENDIAN, 16)
        pi.default = [1, -1]
        pi.default.should eql [1, -1]
        pi = PacketItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
        pi.default = 0x01020304
        pi.default.should eql 0x01020304
        pi = PacketItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil)
        pi.default = 5.5
        pi.default.should eql 5.5
        pi = PacketItem.new("test", 0, 32, :STRING, :BIG_ENDIAN, nil)
        pi.default = "HI"
        pi.default.should eql "HI"
      end

      it "should set the default to nil" do
        @pi.default = nil
        @pi.default.should be_nil
      end
    end

    describe "check_default_and_range_data_types" do
      it "should complain about default not matching data_type" do
        pi = PacketItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 16)
        pi.default = 1
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be an Array but is a Fixnum")
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
        pi.default = 5
        expect { pi.check_default_and_range_data_types }.to raise_error(ArgumentError, "TEST: default must be a String but is a Fixnum")
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

      it "should complain about range not matching data_type" do
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
      it "should accept range as a String" do
        range = (0..1)
        @pi.range = range
        @pi.range.should eql range
      end

      it "should set the range to nil" do
        @pi.range = nil
        @pi.range.should be_nil
      end

      it "should complain about ranges that aren't Ranges" do
        expect { @pi.range = 5}.to raise_error(ArgumentError, "#{@pi.name}: range must be a Range but is a Fixnum")
      end
    end

    describe "hazardous=" do
      it "should accept hazardous as a Hash" do
        hazardous = {"TRUE"=>nil,"FALSE"=>"NO FALSE ALLOWED"}
        @pi.hazardous = hazardous
        @pi.hazardous.should eql hazardous
        @pi.hazardous["TRUE"].should eql hazardous["TRUE"]
        @pi.hazardous["FALSE"].should eql hazardous["FALSE"]
      end

      it "should set hazardous to nil" do
        @pi.hazardous = nil
        @pi.hazardous.should be_nil
      end

      it "should complain about hazardous that aren't Hashes" do
        expect { @pi.hazardous = ""}.to raise_error(ArgumentError, "#{@pi.name}: hazardous must be a Hash but is a String")
      end
    end

    describe "state_colors=" do
      it "should accept state_colors as a Hash" do
        state_colors = {"TRUE"=>:GREEN, "FALSE"=>:RED}
        @pi.state_colors = state_colors
        @pi.state_colors.should eql state_colors
      end

      it "should set the state_colors to nil" do
        @pi.state_colors = nil
        @pi.state_colors.should be_nil
      end

      it "should complain about state_colors that aren't Hashes" do
        expect { @pi.state_colors = ""}.to raise_error(ArgumentError, "#{@pi.name}: state_colors must be a Hash but is a String")
      end
    end

    describe "limits=" do
      it "should accept limits as a PacketItemLimits" do
        limits = PacketItemLimits.new
        @pi.limits = limits
      end

      it "should set the limits to nil" do
        @pi.limits = nil
        @pi.limits.should be_nil
      end

      it "should complain about limits that aren't PacketItemLimits" do
        expect { @pi.limits = ""}.to raise_error(ArgumentError, "#{@pi.name}: limits must be a PacketItemLimits but is a String")
      end
    end

    describe "meta" do
      it "should allow adding items to the meta hash" do
        @pi.meta['TYPE'] = 'float32'
        @pi.meta['TYPE'].should eql 'float32'
      end
    end

    describe "clone" do
      it "should duplicate the entire PacketItem" do
        pi2 = @pi.clone
        (@pi == pi2).should be_truthy
      end
    end

    describe "to_hash" do
      it "should convert to a Hash" do
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
        hash.keys.length.should eql 22
        # Check the values from StructureItem
        hash.keys.should include('name','bit_offset','bit_size','data_type','endianness','array_size','overflow')
        hash["name"].should eql "TEST"
        hash["bit_offset"].should eql 0
        hash["bit_size"].should eql 32
        hash["data_type"].should eql :UINT
        hash["endianness"].should eql :BIG_ENDIAN
        hash["array_size"].should be_nil
        hash["overflow"].should eql :ERROR
        # Check the unique PacketItem values
        hash.keys.should include('format_string','read_conversion','write_conversion','id_value','states','description','units_full','units','default','range','required','hazardous','state_colors','limits')
        hash["format_string"].should eql "%5.1f"
        hash["read_conversion"].should match "value / 2"
        hash["write_conversion"].should match /value \* 2/
        hash["id_value"].should eql 10
        hash["states"].should include("TRUE"=>1,"FALSE"=>0)
        hash["description"].should eql "description"
        hash["units_full"].should eql "Celcius"
        hash["units"].should eql "C"
        hash["default"].should eql 0
        hash["range"].should eql (0..100)
        hash["required"].should be_truthy
        hash["hazardous"].should include("TRUE"=>nil,"FALSE"=>"NO!")
        hash["state_colors"].should include("TRUE"=>:GREEN,"FALSE"=>:RED)
        hash["limits"].should eql PacketItemLimits.new.to_hash
        hash["meta"].should be_nil
      end

      it "should convert to a Hash with no conversions" do
        hash = @pi.to_hash
        hash["read_conversion"].should be_nil
        hash["write_conversion"].should be_nil
      end
    end

  end
end
